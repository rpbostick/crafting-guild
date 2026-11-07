#!/usr/bin/env python3
"""OpenCode builder runs, for scripts/opencode-builder.sh and scripts/dispatch.sh.

config   [--temperature T] [--top-p P] <tool>... [--deny <tool>]...
                                       the OpenCode config a builder runs under, from dispatch's Claude-style grants;
                                       T and P set the sampling of OpenCode's build agent (the one `opencode run` uses)
config   --read-only                   the OpenCode config a review runs under: reads allowed, everything else denied
variants <provider/model>              the model's variant names from `opencode models <provider> --verbose`, one
                                       per line; exit 1 when the model is absent, 2 when the listing cannot be read
watch    <log> <budget> <pid>          stop <pid> once the step costs in <log> pass <budget> dollars
check    <log> <schema>                exit 0 when the last text part is a valid result; else print the errors
over     <log> <budget>                exit 0 when the step costs in <log> are past <budget>
session  <log>                         the session ID the log's events carry
result   <log> <schema> <budget> <duration_ms> [--refused <reason>]
                                       the Claude-shaped result line scripts/lib.sh result_json finds
events-denials <events>                JSON array of denied permissions the run-events plugin recorded
limit    <events>                      print "<message>\t<reset epoch>" for a run that stopped on a provider
                                       limit, exit 0; exit 1 when the last retry or error is not a limit
schema-probe --url <url> --password <pw> --model <provider/model> --schema <file> --prompt <text>
                                       ask a running `opencode serve` for one JSON-schema reply and report:
                                       `enforced <json>`, `failed: <error> ...` or `unsupported: ...`
web-probe --url <url> --password <pw> --model <provider/model> --kind fetch|search
                                       ask a running `opencode serve` for one web fetch or search and report:
                                       `worked: ...`, `not available: ...` or `failed: <error> ...`
browser-probe --url <url> --password <pw> --model <provider/model> --page <url> --marker <text>
                                       ask a running `opencode serve` to load a local page through the browser MCP:
                                       `worked: ...`, `not available: ...` or `failed: <error> ...`
skill-probe --url <url> --password <pw> --directory <project> --name <skill> --marker <text> --user-skills <dir>
                                       read a running `opencode serve`'s skill list for a project, no model call:
                                       `loaded: ...`, `not loaded: ...`, `not available: ...` or `failed: <error> ...`
skill-call --url <url> --password <pw> --model <provider/model> --directory <project> --name <skill> --marker <text>
                                       ask a running `opencode serve` to call the skill tool for a project skill:
                                       `worked: ...`, `not available: ...` or `failed: <error> ...`

Python stdlib only: jsonschema is not installed, so `validate` covers the keywords schema/result.json uses
(type, enum, properties, required, items, additionalProperties) and fails loud on any other keyword.
"""
import base64
import email.utils
import json
import os
import re
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# Deliberate: every permission is set, ending in allow or deny. A builder runs headless, so a rule left at OpenCode's
# default "ask" (doom_loop, a read of .env) would wait on a prompt nobody answers.
FIXED = {"read": "allow", "glob": "allow", "grep": "allow", "list": "allow", "lsp": "allow",
         "todoread": "allow", "todowrite": "allow", "task": "deny", "skill": "deny", "question": "deny",
         "doom_loop": "deny", "external_directory": "deny", "codesearch": "deny"}
# A review reads the branch and its diff; it must not change the worktree, fetch anything or write a file, so every
# tool but the four read tools is denied. The shell grants are the read-only git and file commands a reviewer uses
# to see history and a full file, and nothing that can write.
READONLY_FIXED = {"read": "allow", "grep": "allow", "glob": "allow", "list": "allow",
                  "edit": "deny", "write": "deny", "webfetch": "deny", "websearch": "deny",
                  "lsp": "deny", "todoread": "deny", "todowrite": "deny", "task": "deny", "skill": "deny",
                  "question": "deny", "doom_loop": "deny", "external_directory": "deny", "codesearch": "deny"}
# Each allowed git command is matched exactly or with its arguments, never by a bare prefix: `git diff*` would also
# allow `git difftool`, which launches another program. The denies come after the allows because OpenCode applies the
# last matching rule, so a command that writes a file through --output or a redirect stays denied even when an allow
# matches its prefix.
READONLY_BASH = ("git diff", "git diff *", "git log", "git log *", "git show", "git show *",
                 "git status", "git status *", "cat *", "ls *")
READONLY_BASH_DENY = ("*--output*", "*>*", "git difftool*")
KNOWN = {"type", "enum", "properties", "required", "items", "description", "additionalProperties", "anyOf"}
DENIAL = re.compile(r"permission|prevents you from using|rejected", re.I)
# The wrapper beside this file; the generated config names it as OpenCode's shell when WS_SANDBOX is bwrap.
SANDBOX_SHELL = os.path.join(os.path.dirname(os.path.realpath(__file__)), "ws-sandbox-shell.sh")


def bash_pattern(grant):
    match = re.fullmatch(r"Bash\((.*)\)", grant)
    return match.group(1) if match else None


def sampling_value(flag, value, low, high, low_open=False):
    """A plain decimal in the setting's range; the flag's name is in every error, since a caller typed that flag."""
    if not re.fullmatch(r"[0-9]+(\.[0-9]+)?", value):
        sys.exit(f"opencode_run: {flag} takes a plain decimal, not {value!r}")
    number = float(value)
    if number > high or (number <= low if low_open else number < low):
        if low_open:
            sys.exit(f"opencode_run: {flag} takes a value over {low:g} and at most {high:g}, not {value}")
        sys.exit(f"opencode_run: {flag} takes a value from {low:g} to {high:g}, not {value}")
    return number


def build_config(tools, deny, temperature=None, top_p=None):
    """Bash is deny unless a grant allows it; the deny list comes last because OpenCode applies the last matching rule."""
    bash = {"*": "deny"}
    for tool in tools:
        pattern = bash_pattern(tool)
        if pattern is not None:
            bash[pattern] = "allow"
    for denied in deny:
        pattern = bash_pattern(denied)
        if pattern is None:
            sys.exit(f"opencode_run: deny entry {denied!r} is not Bash(<pattern>)")
        bash.pop(pattern, None)
        bash[pattern] = "deny"
    perm = {"*": "deny", **FIXED, "bash": bash,
            # Edits stay in the worktree: OpenCode's project directory is the worktree and external_directory is deny.
            "edit": "allow" if any(tool.startswith("Edit(") for tool in tools) else "deny",
            "webfetch": "allow" if "WebFetch" in tools else "deny",
            "websearch": "allow" if "WebSearch" in tools else "deny"}
    cfg = {"$schema": "https://opencode.ai/config.json", "share": "disabled", "autoupdate": False, "permission": perm}
    bad = [key for key, value in perm.items() if value not in ("allow", "deny") and not isinstance(value, dict)]
    bad += [f"bash {key}" for key, value in bash.items() if value not in ("allow", "deny")]
    if bad:
        sys.exit(f"opencode_run: permissions not allow or deny: {bad}")
    # Only a builder's shell is wrapped: a review's read-only grants run on the host and dispatch does not set
    # the evidence runner's grant file there. With WS_SANDBOX empty the config keeps exactly the keys above.
    if os.environ.get("WS_SANDBOX") == "bwrap":
        cfg["shell"] = SANDBOX_SHELL
    # Temperature and top_p are agent options, and `opencode run` uses the build agent. Unset adds no key, so the
    # config stays byte for byte what it was.
    if temperature is not None or top_p is not None:
        build = {}
        if temperature is not None:
            build["temperature"] = temperature
        if top_p is not None:
            build["top_p"] = top_p
        cfg["agent"] = {"build": build}
    return cfg


def build_readonly_config():
    """A review's config: reads only, no edit, no write, no network tool and no shell command that writes."""
    bash = {"*": "deny"}
    for pattern in READONLY_BASH:
        bash[pattern] = "allow"
    for pattern in READONLY_BASH_DENY:
        bash[pattern] = "deny"
    perm = {"*": "deny", **READONLY_FIXED, "bash": bash}
    bad = [key for key, value in perm.items() if value not in ("allow", "deny") and not isinstance(value, dict)]
    bad += [f"bash {key}" for key, value in bash.items() if value not in ("allow", "deny")]
    if bad:
        sys.exit(f"opencode_run: permissions not allow or deny: {bad}")
    return {"$schema": "https://opencode.ai/config.json", "share": "disabled", "autoupdate": False, "permission": perm}


def events(log):
    """The JSON events of an OpenCode log; other lines (stderr, notes) are skipped."""
    with open(log, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line.startswith("{"):
                continue
            try:
                ev = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(ev, dict) and ev.get("type") != "result":
                yield ev


def totals(log):
    cost = out = cache = 0
    for ev in events(log):
        if ev.get("type") == "step_finish":
            part = ev["part"]
            # A forced turn that timed out has no number to add; its line says so with cost_unknown. Any other
            # step_finish without a numeric cost is broken data and stops the total rather than being skipped.
            if part.get("cost_unknown"):
                pass
            elif isinstance(part.get("cost"), (int, float)):
                cost += part["cost"]
            else:
                raise ValueError(f"step_finish has no numeric cost: {json.dumps(part)[:300]}")
            tok = part.get("tokens", {})
            out += tok.get("output", 0)
            cache += tok.get("cache", {}).get("read", 0)
    return cost, out, cache


def cost_unknown(log):
    """True when a step_finish could not name its cost, so a total of the numbers would understate the spend."""
    return any(ev.get("type") == "step_finish" and (ev.get("part") or {}).get("cost_unknown") for ev in events(log))


def last_text(log):
    text = None
    for ev in events(log):
        if ev.get("type") == "text":
            text = ev["part"]["text"]
    return text


def last_unparsed(log, count=5):
    """The last non-JSON lines of a log: launcher notes and provider errors, the reason a run produced no text."""
    lines = []
    with open(log, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line.strip():
                continue
            try:
                json.loads(line)
            except json.JSONDecodeError:
                lines.append(line)
    return "\n".join(lines[-count:]) or None


def denials(log):
    """Tool calls OpenCode refused, shaped as Claude's permission_denials so check-result reads them unchanged."""
    found = []
    for ev in events(log):
        part = ev.get("part", {})
        state = part.get("state", {}) if ev.get("type") == "tool_use" else {}
        if state.get("status") == "error" and DENIAL.search(str(state.get("error", ""))):
            found.append({"tool_name": part.get("tool"), "tool_input": state.get("input", {})})
    return found


LIMIT = re.compile(r"usage limit|rate limit|too many requests|quota|limit reached|free limit", re.I)
LIMIT_REASONS = {"account_rate_limit", "free_tier_limit"}


def events_path(log):
    """The builder's event file: WS_RUN_EVENTS names it, else it sits beside the run's .jsonl."""
    named = os.environ.get("WS_RUN_EVENTS")
    if named:
        return named
    return log[:-6] + ".events.jsonl" if log.endswith(".jsonl") else log + ".events.jsonl"


def event_lines(path):
    """The plugin writes one JSON object per line; a partial last line is not an event."""
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(event, dict):
                    yield event
    except FileNotFoundError:
        return


def denial_input(metadata, title):
    """The permission event's metadata reduced to the tool input Claude's denials carry (a command or a path)."""
    if isinstance(metadata, dict):
        for key in ("command", "filePath", "path", "pattern"):
            if key in metadata:
                return {key: metadata[key]}
        if metadata:
            return metadata
    return {"title": title} if title else {}


def event_denials(path):
    """Denied permission events, shaped like Claude's permission_denials."""
    asks = {}
    found = []
    seen = set()

    def add(ask):
        tool = ask.get("tool") or ask.get("title") or "permission"
        tool_input = denial_input(ask.get("metadata"), ask.get("title"))
        key = (str(tool), json.dumps(tool_input, sort_keys=True))
        if key not in seen:
            seen.add(key)
            found.append({"tool_name": tool, "tool_input": tool_input})

    for event in event_lines(path):
        kind = event.get("event")
        if kind in ("permission.asked", "permission.ask"):
            asks[event.get("request_id") or ""] = event
            if kind == "permission.ask" and str(event.get("status", "")).lower() in ("deny", "reject"):
                add(event)
        elif kind == "permission.replied" and str(event.get("reply", "")).lower() in ("deny", "reject"):
            add(asks.get(event.get("request_id") or "", event))
    return found


def epoch_seconds(value):
    """OpenCode's SessionStatus.next is epoch milliseconds; a number below that range is already seconds."""
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return int(number / 1000) if number > 100000000000 else int(number)


def retry_after_epoch(headers, now):
    """retry-after is seconds or an HTTP date; retry-after-ms is milliseconds."""
    if not isinstance(headers, dict):
        return None
    lower = {str(key).lower(): value for key, value in headers.items()}
    milliseconds = lower.get("retry-after-ms")
    if milliseconds is not None:
        try:
            return int(now + float(milliseconds) / 1000)
        except (TypeError, ValueError):
            return None
    after = lower.get("retry-after")
    if after is None:
        return None
    try:
        return int(now + float(after))
    except (TypeError, ValueError):
        try:
            parsed = email.utils.parsedate_to_datetime(str(after))
        except (TypeError, ValueError):
            return None
        return int(parsed.timestamp())


def limit_event(event, now):
    """(message, reset epoch) when one event is a provider limit stop, else None."""
    kind = event.get("event")
    message = str(event.get("message") or "")
    headers = event.get("response_headers") or {}
    status = event.get("status")
    body = str(event.get("response_body") or "")
    if kind == "session.retry":
        action = event.get("action") if isinstance(event.get("action"), dict) else {}
        reason = str(action.get("reason") or "")
        if not (status == 429 or LIMIT.search(message) or reason in LIMIT_REASONS):
            return None
        reset = epoch_seconds(event.get("next")) or retry_after_epoch(headers, now)
        return (message or reason or "usage limit", reset)
    if kind in ("retry.part", "session.error"):
        if not (status == 429 or LIMIT.search(message) or "GoUsageLimitError" in body):
            return None
        reset = retry_after_epoch(headers, now) or epoch_seconds(event.get("next"))
        return (message or "usage limit", reset)
    return None


def limit(path):
    """The last retry or error decides: a recovered retry is not a limit, a stop on one is."""
    now = time.time()
    found = None
    reset = None
    for event in event_lines(path):
        if event.get("event") not in ("session.retry", "retry.part", "session.error"):
            continue
        hit = limit_event(event, now)
        if hit is None:
            if event.get("status") is not None or event.get("message"):
                found = None
            continue
        found = hit[0]
        reset = hit[1] or reset
    if found is None:
        return None
    return found, reset


def extract(text):
    """The JSON object in a reply: the whole text, a fenced block, or the span from the first { to the last }.

    A reply cut off after its opening brace has no closing one, so there is no span to extract; it counts as no JSON
    rather than raising on rindex.
    """
    if text is None:
        return None, "no text part in the log"
    candidates = [text.strip()]
    candidates += re.findall(r"```(?:json)?\s*(.*?)```", text, re.S)
    start, end = text.find("{"), text.rfind("}")
    if start != -1 and end > start:
        candidates.append(text[start:end + 1])
    for candidate in candidates:
        try:
            obj = json.loads(candidate)
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict):
            return obj, None
    return None, "no JSON object in the last text part"


TYPES = {"object": dict, "array": list, "string": str, "null": type(None), "boolean": bool}


def type_ok(value, type_name):
    if type_name == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if type_name == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if type_name not in TYPES:
        raise ValueError(f"schema type {type_name!r} is not handled")
    return isinstance(value, TYPES[type_name])


def validate(value, schema, path="$"):
    unknown = set(schema) - KNOWN
    if unknown:
        raise ValueError(f"schema keyword(s) {sorted(unknown)} at {path} are not handled")
    errs = []
    if "type" in schema:
        names = schema["type"] if isinstance(schema["type"], list) else [schema["type"]]
        if not any(type_ok(value, type_name) for type_name in names):
            return [f"{path}: expected {'|'.join(names)}, got {type(value).__name__}"]
    if "enum" in schema and value not in schema["enum"]:
        errs.append(f"{path}: {value!r} is not one of {schema['enum']}")
    if "anyOf" in schema and not any(not validate(value, sub, path) for sub in schema["anyOf"]):
        errs.append(f"{path}: matches none of anyOf")
    if isinstance(value, dict):
        for key in schema.get("required", []):
            if key not in value:
                errs.append(f"{path}: missing required {key!r}")
        for key, sub in schema.get("properties", {}).items():
            if key in value:
                errs += validate(value[key], sub, f"{path}.{key}")
        extra = schema.get("additionalProperties")
        if extra not in (None, True, False):
            raise ValueError(f"schema additionalProperties at {path} is not a boolean")
        if extra is False:
            unexpected = sorted(set(value) - set(schema.get("properties", {})))
            if unexpected:
                errs.append(f"{path}: unexpected properties {unexpected}")
    if isinstance(value, list) and "items" in schema:
        for i, item in enumerate(value):
            errs += validate(item, schema["items"], f"{path}[{i}]")
    return errs


def denied_text(item):
    """A denied call as the schema's string: its command, call, path or tool, with a reason appended when it has one."""
    if not isinstance(item, dict):
        return item
    for key in ("command", "call", "path", "tool"):
        if isinstance(item.get(key), str):
            text = item[key]
            reason = item.get("reason")
            return f"{text}: {reason}" if isinstance(reason, str) and reason else text
    return item


def question_text(item):
    """An open question as the schema's string, keeping a recommendation when the entry has one."""
    if not isinstance(item, dict):
        return item
    if "question" in item and "recommendation" in item:
        return f"{item['question']} (recommendation: {item['recommendation']})"
    if "question" in item:
        return str(item["question"])
    return "; ".join(str(value) for value in item.values())


def normalize(obj):
    """Repair the result shapes models write instead of the schema's, without guessing a value.

    A review's `blocking`/`suggestions` must be arrays. Some models write `"blocking": false` (or true plus a
    `blocking_findings` list) instead of `[]`; accept that rather than throwing away an otherwise valid review.
    A builder result's `denied`, `open_questions`, `unknowns`, `tests` and `done_when` are coerced from the
    object, string and list shapes models write; a shape not handled here still fails and goes to the repair turn.
    """
    if not isinstance(obj, dict):
        return obj
    for key in ("blocking", "suggestions"):
        value = obj.get(key)
        if isinstance(value, bool):
            other = obj.get(f"{key}_findings")
            obj[key] = other if value and isinstance(other, list) else []
    if isinstance(obj.get("denied"), list):
        obj["denied"] = [denied_text(item) for item in obj["denied"]]
    if isinstance(obj.get("open_questions"), list):
        obj["open_questions"] = [question_text(item) for item in obj["open_questions"]]
    if isinstance(obj.get("unknowns"), str):
        obj["unknowns"] = [obj["unknowns"]]
    tests = obj.get("tests")
    if isinstance(tests, list) and len(tests) == 1 and isinstance(tests[0], dict) \
            and all(key in tests[0] for key in ("command", "passed", "failed", "log_path")):
        obj["tests"] = tests[0]
    if isinstance(obj.get("done_when"), list):
        for item in obj["done_when"]:
            if not isinstance(item, dict):
                continue
            basis = item.get("basis")
            for word in ("observed", "inferred"):
                prefix = f"{word}:"
                if isinstance(basis, str) and basis.startswith(prefix):
                    item["basis"] = word
                    if not item.get("evidence"):
                        item["evidence"] = basis[len(prefix):].strip()
                    break
    return obj


def checked(log, schema_path):
    with open(schema_path, encoding="utf-8") as fh:
        schema = json.load(fh)
    obj, err = extract(last_text(log))
    if err:
        return None, [err]
    obj = normalize(obj)
    errs = validate(obj, schema)
    return (obj, []) if not errs else (None, errs)


def alive(pid):
    try:
        with open(f"/proc/{pid}/stat", encoding="ascii") as fh:
            return fh.read().rsplit(")", 1)[1].split()[0] != "Z"
    except (FileNotFoundError, IndexError):
        return False


def kill_group(pgid, sig):
    """A group that already exited is not an error: the leader can go before its children do."""
    try:
        os.killpg(pgid, sig)
    except ProcessLookupError:
        pass


def watch(log, budget, pid):
    """Stop the run's process group, not just its leader: a wrapper's child would otherwise keep running."""
    budget, pid = float(budget), int(pid)
    while alive(pid):
        if os.path.exists(log) and totals(log)[0] > budget:
            print(f"opencode_run: step costs passed the ${budget} budget; stopping pid {pid}", file=sys.stderr)
            kill_group(pid, signal.SIGTERM)
            for _ in range(50):
                if not alive(pid):
                    kill_group(pid, signal.SIGKILL)
                    return
                time.sleep(0.1)
            kill_group(pid, signal.SIGKILL)
            return
        time.sleep(0.2)


def end_log_line(log):
    """The result line is appended to the log's own stream, so separate it from an unterminated last line."""
    with open(log, "rb") as fh:
        fh.seek(0, os.SEEK_END)
        if fh.tell() == 0:
            return
        fh.seek(-1, os.SEEK_END)
        if fh.read(1) != b"\n":
            print()


def result(log, schema_path, budget, duration_ms, refused=None):
    cost, out, cache = totals(log)
    text = last_text(log)
    so = None
    if refused is None:
        # No text part means OpenCode itself failed (missing auth, a provider error): its stderr lines are the reason.
        if text is None:
            text = last_unparsed(log)
        so, _ = checked(log, schema_path)
        if cost > float(budget):
            reason = f"stopped: OpenCode steps cost ${cost:.4f}, over the ${budget} budget"
            if so is None:
                so = {"status": "partial", "summary": reason, "files_changed": [], "commits": [], "tests": None,
                      "denied": [], "done_when": [], "unknowns": [reason], "open_questions": []}
            else:
                so["status"] = "partial"
                so["unknowns"] = so["unknowns"] + [reason]
    else:
        text = f"refused: {refused}"
    denied_calls = denials(log)
    seen = {(str(item.get("tool_name")), json.dumps(item.get("tool_input"), sort_keys=True)) for item in denied_calls}
    for item in event_denials(events_path(log)):
        key = (str(item.get("tool_name")), json.dumps(item.get("tool_input"), sort_keys=True))
        if key not in seen:
            seen.add(key)
            denied_calls.append(item)
    line = {"type": "result", "agent": "opencode", "total_cost_usd": round(cost, 6), "duration_ms": int(duration_ms),
            "model": os.environ.get("WS_RUN_MODEL", ""),
            "variant": os.environ.get("WS_RUN_VARIANT", ""),
            "opencode_version": os.environ.get("WS_RUN_OPENCODE_VERSION", ""),
            "usage": {"output_tokens": out, "cache_read_input_tokens": cache},
            "permission_denials": denied_calls, "structured_output": so, "result": text}
    if cost_unknown(log):
        line["cost_unknown"] = True
    end_log_line(log)
    # Compact separators: result_json (scripts/lib.sh) greps for "type":"result" with no space.
    print(json.dumps(line, separators=(",", ":")))


def probe_request(base, password, method, path, body=None, timeout=180, directory=None):
    """One JSON call to an `opencode serve`; a non-2xx reply is returned, not raised, so the caller reports it."""
    if directory:
        path = f"{path}{'&' if '?' in path else '?'}directory={urllib.parse.quote(directory, safe='')}"
    data = None if body is None else json.dumps(body).encode()
    headers = {"Content-Type": "application/json"}
    if password:
        token = base64.b64encode(f"opencode:{password}".encode()).decode()
        headers["Authorization"] = f"Basic {token}"
    req = urllib.request.Request(base.rstrip("/") + path, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", "replace")
        try:
            return exc.code, json.loads(raw)
        except json.JSONDecodeError:
            return exc.code, raw


def error_text(error):
    """One line for an AssistantMessage.error, keeping the provider's own words (the reason the reply failed)."""
    if not isinstance(error, dict):
        return str(error)
    name = error.get("name", "error")
    data = error.get("data") if isinstance(error.get("data"), dict) else {}
    message = data.get("message") or data.get("responseBody") or ""
    status = f" HTTP {data['statusCode']}" if "statusCode" in data else ""
    retries = f" (retries {data['retries']})" if "retries" in data else ""
    return f"{name}{status}: {message}{retries}" if message else f"{name}{status}{retries}"


def parse_probe_args(args, command="schema-probe", required=("--url", "--password", "--model", "--schema", "--prompt"),
                     optional=("--retry",)):
    values = {"--retry": "2"}
    allowed = set(required) | set(optional)
    i = 0
    while i < len(args):
        if args[i] not in allowed or i + 1 >= len(args):
            sys.exit(f"opencode_run: {command} takes {sorted(allowed)} with a value, not {args[i]!r}")
        values[args[i]] = args[i + 1]
        i += 2
    for key in required:
        if not values.get(key):
            sys.exit(f"opencode_run: {command} needs {key}")
    return values


def schema_probe(argv):
    """Ask a running OpenCode server for one forced JSON-schema reply and report what came back.

    The server enforces the schema through a StructuredOutput tool, not the provider's JSON mode, so a provider that
    refuses a forced tool choice fails here even though a plain `opencode run` reply could still be valid JSON.
    """
    opts = parse_probe_args(argv)
    provider, sep, model_id = opts["--model"].partition("/")
    if not sep or not provider or not model_id:
        return f"failed: model {opts['--model']!r} is not provider/model"
    with open(opts["--schema"], encoding="utf-8") as fh:
        schema = json.load(fh)
    base, password = opts["--url"], opts["--password"]
    try:
        status, session = probe_request(base, password, "POST", "/session", {"title": "schema probe"})
    except (urllib.error.URLError, TimeoutError) as exc:
        return f"failed: cannot reach the OpenCode server: {exc}"
    if status != 200 or not isinstance(session, dict) or not session.get("id"):
        return f"unsupported: POST /session returned HTTP {status}: {json.dumps(session)[:300]}"
    sid = session["id"]
    try:
        body = {"model": {"providerID": provider, "modelID": model_id},
                "format": {"type": "json_schema", "schema": schema, "retryCount": int(opts["--retry"])},
                "parts": [{"type": "text", "text": opts["--prompt"]}]}
        status, reply = probe_request(base, password, "POST", f"/session/{sid}/message", body)
        if status in (400, 404, 405):
            return f"unsupported: POST /session/{sid}/message returned HTTP {status}: {json.dumps(reply)[:300]}"
        if status != 200 or not isinstance(reply, dict) or not isinstance(reply.get("info"), dict):
            return f"failed: POST /session/{sid}/message returned HTTP {status}: {json.dumps(reply)[:300]}"
        info = reply["info"]
        if info.get("error") is not None:
            return f"failed: {error_text(info['error'])}"
        if "structured" not in info or info["structured"] is None:
            return f"unsupported: the reply carried no structured output and no error: {json.dumps(info)[:300]}"
        errs = validate(info["structured"], schema)
        if errs:
            return "failed: the structured output does not match the schema: " + "; ".join(errs)
        return "enforced " + json.dumps(info["structured"], sort_keys=True)
    finally:
        # The server is about to be stopped, but a session left behind would still hold its cost and transcript.
        try:
            probe_request(base, password, "DELETE", f"/session/{sid}", timeout=10)
        except (urllib.error.URLError, TimeoutError):
            pass


# `expect` is text the tool's output must hold, so a completed call that returned "no results" is not a success. The
# search expects a URL, because a no-results message can echo the query's words.
WEB_PROBES = {
    "fetch": {"tool": "webfetch", "expect": "Example Domain",
              "prompt": "Use the webfetch tool once to fetch https://example.com, then reply with the single word done."},
    "search": {"tool": "websearch", "expect": "http",
               "prompt": "Use the websearch tool once to search for: example domain. "
                         "Then reply with the single word done."},
}
# Below the 150 seconds doctor allows a probe, so a hung prompt reports its own failure instead of being killed.
WEB_PROMPT_TIMEOUT = 120
# A session create does no model work, so it answers quickly or not at all.
SESSION_TIMEOUT = 30
# Below the 90 seconds doctor allows the probe; a first request in a directory starts OpenCode's instance there.
SKILL_LIST_TIMEOUT = 60
# Below the 150 seconds doctor allows the skill-call probe; the model reads the skill and answers in one turn.
SKILL_CALL_TIMEOUT = 120
# What a probe call can raise: no connection, no answer in time, or a 200 that is not JSON.
PROBE_ERRORS = (urllib.error.URLError, TimeoutError, json.JSONDecodeError)


def listed_tools(base, password, provider, model_id):
    """The tool IDs the server offers this model, or None when it has no such list.

    OpenCode can leave a built-in tool out for a provider, and the list says so without a paid prompt. The route is
    under /experimental and a server without it can answer with its web app's HTML, so anything but a JSON list means
    "unknown" and the prompt decides.
    """
    path = f"/experimental/tool?provider={urllib.parse.quote(provider)}&model={urllib.parse.quote(model_id)}"
    try:
        status, tools = probe_request(base, password, "GET", path, timeout=30)
    except json.JSONDecodeError:
        return None
    if status != 200 or not isinstance(tools, list):
        return None
    return {tool.get("id") for tool in tools if isinstance(tool, dict)}


def session_parts(base, password, sid, directory=None):
    """Every part of a session, oldest first.

    A prompt's reply holds only the last step's message; the tool call was the step before it, so a verdict read from
    the reply alone sees a model that never called anything.
    """
    status, messages = probe_request(base, password, "GET", f"/session/{sid}/message", timeout=30,
                                     directory=directory)
    if status != 200 or not isinstance(messages, list):
        raise ValueError(f"GET /session/{sid}/message returned HTTP {status}: {json.dumps(messages)[:300]}")
    return [part for message in messages for part in message.get("parts") or []]


def web_verdict(spec, parts):
    """What a session's parts show about the probed tool. A model that never calls it counts as it being unavailable."""
    tool = spec["tool"]
    calls = [part for part in parts if isinstance(part, dict) and part.get("type") == "tool" and part.get("tool") == tool]
    states = [call.get("state") if isinstance(call.get("state"), dict) else {} for call in calls]
    outputs = [str(state.get("output") or "") for state in states if state.get("status") == "completed"]
    if any(spec["expect"] in output for output in outputs):
        size = max(len(output) for output in outputs)
        return f"worked: {tool} returned {size} characters"
    if any(outputs):
        return f"failed: {tool} returned no {spec['expect']!r} text: {max(outputs, key=len)[:200]!r}"
    if outputs:
        return f"failed: {tool} returned nothing"
    if calls:
        return f"failed: {tool}: {' '.join(str(state.get('error') or state.get('status')) for state in states)[:300]}"
    said = " ".join(str(part.get("text")) for part in parts if isinstance(part, dict) and part.get("type") == "text")
    return f"not available: the model made no {tool} call (it said: {said[:200]!r})"


def web_probe(argv):
    """Ask a running OpenCode server for one web tool call and report what the call returned.

    Deliberate: the session allows only the probed tool. A headless session has nobody to answer an "ask", and text
    from the web must not reach any other tool. OpenCode applies the last matching rule, so the deny comes first.
    """
    opts = parse_probe_args(argv, "web-probe", ("--url", "--password", "--model", "--kind"), ())
    spec = WEB_PROBES.get(opts["--kind"])
    if spec is None:
        sys.exit(f"opencode_run: web-probe --kind takes {sorted(WEB_PROBES)}, not {opts['--kind']!r}")
    tool = spec["tool"]
    provider, sep, model_id = opts["--model"].partition("/")
    if not sep or not provider or not model_id:
        return f"failed: model {opts['--model']!r} is not provider/model"
    base, password = opts["--url"], opts["--password"]
    permission = [{"permission": "*", "pattern": "*", "action": "deny"},
                  {"permission": tool, "pattern": "*", "action": "allow"}]
    try:
        tools = listed_tools(base, password, provider, model_id)
        if tools is not None and tool not in tools:
            return f"not available: the server does not list {tool} for {opts['--model']}"
        status, session = probe_request(base, password, "POST", "/session",
                                        {"title": f"web probe {opts['--kind']}", "permission": permission},
                                        timeout=SESSION_TIMEOUT)
    except PROBE_ERRORS as exc:
        return f"failed: cannot reach the OpenCode server: {exc}"
    if status != 200 or not isinstance(session, dict) or not session.get("id"):
        return f"failed: POST /session returned HTTP {status}: {json.dumps(session)[:300]}"
    sid = session["id"]
    try:
        body = {"model": {"providerID": provider, "modelID": model_id},
                "parts": [{"type": "text", "text": spec["prompt"]}]}
        try:
            status, reply = probe_request(base, password, "POST", f"/session/{sid}/message", body,
                                          timeout=WEB_PROMPT_TIMEOUT)
        except PROBE_ERRORS as exc:
            return f"failed: no reply from the prompt: {exc}"
        if status != 200 or not isinstance(reply, dict) or not isinstance(reply.get("info"), dict):
            return f"failed: POST /session/{sid}/message returned HTTP {status}: {json.dumps(reply)[:300]}"
        if reply["info"].get("error") is not None:
            return f"failed: {error_text(reply['info']['error'])}"
        try:
            return web_verdict(spec, session_parts(base, password, sid))
        except (urllib.error.URLError, TimeoutError, ValueError) as exc:
            return f"failed: cannot read the session: {exc}"
    finally:
        try:
            probe_request(base, password, "DELETE", f"/session/{sid}", timeout=10)
        except PROBE_ERRORS:
            pass


BROWSER_SERVER = "playwright"
BROWSER_NAVIGATE = f"{BROWSER_SERVER}_browser_navigate"
BROWSER_SNAPSHOT = f"{BROWSER_SERVER}_browser_snapshot"
# Any public page: the probe wants it refused, so its content never matters.
BROWSER_OUTSIDE = "https://example.com/"
# A first prompt can wait on npx and a browser start. Below the 240 seconds doctor allows the probe.
BROWSER_PROMPT_TIMEOUT = 200


def browser_status(base, password):
    """The MCP server's state from the server's own list, or None when the server has no such route."""
    try:
        status, servers = probe_request(base, password, "GET", "/mcp", timeout=SKILL_LIST_TIMEOUT)
    except json.JSONDecodeError:
        return None
    if status != 200 or not isinstance(servers, dict):
        return None
    entry = servers.get(BROWSER_SERVER)
    return entry if isinstance(entry, dict) else {"status": "not configured"}


def browser_verdict(page, marker, parts):
    """What a session's tool calls show: the page's text came back, and the outside page did not."""
    calls = [part for part in parts if isinstance(part, dict) and part.get("type") == "tool"]
    states = [(call.get("tool"), call.get("state") if isinstance(call.get("state"), dict) else {}) for call in calls]
    done = [(tool, state) for tool, state in states if state.get("status") == "completed"]
    outside = [state for tool, state in states if tool == BROWSER_NAVIGATE
               and BROWSER_OUTSIDE in json.dumps(state.get("input") or {})]
    loaded = [tool for tool, state in done if tool == BROWSER_NAVIGATE and page in json.dumps(state.get("input") or {})]
    read = [state for tool, state in done if tool == BROWSER_SNAPSHOT and marker in str(state.get("output") or "")]
    if not calls:
        said = " ".join(str(part.get("text")) for part in parts if isinstance(part, dict) and part.get("type") == "text")
        return f"not available: the model made no browser call (it said: {said[:200]!r})"
    if not loaded:
        errors = " ".join(str(state.get("error") or state.get("output") or state.get("status")) for _, state in states)
        return f"failed: no page load of {page}: {errors[:300]}"
    if not read:
        return f"failed: {page} loaded but no snapshot held its text"
    if not outside:
        return "failed: the page loaded but the model never tried the outside page, so the origin limit is unchecked"
    text = " ".join(str(state.get("output") or state.get("error") or "") for state in outside)
    if "Example Domain" in text or "ERR_BLOCKED" not in text:
        return f"failed: the outside page was not refused: {text[:300]}"
    return f"worked: loaded {page}, read {marker!r} from its text, {BROWSER_OUTSIDE} refused"


def browser_probe(argv):
    """Ask a running OpenCode server to load a local page through the browser MCP, read it, and try a public page.

    Deliberate: the session allows only the two browser tools, for the reason web_probe gives, and the verdict reads
    the tool outputs, so a model's own words cannot pass it.
    """
    opts = parse_probe_args(argv, "browser-probe", ("--url", "--password", "--model", "--page", "--marker"), ())
    provider, sep, model_id = opts["--model"].partition("/")
    if not sep or not provider or not model_id:
        return f"failed: model {opts['--model']!r} is not provider/model"
    base, password, page = opts["--url"], opts["--password"], opts["--page"]
    permission = [{"permission": "*", "pattern": "*", "action": "deny"},
                  {"permission": BROWSER_NAVIGATE, "pattern": "*", "action": "allow"},
                  {"permission": BROWSER_SNAPSHOT, "pattern": "*", "action": "allow"}]
    try:
        state = browser_status(base, password)
        if state is not None and state.get("status") != "connected":
            return f"not available: the browser MCP is {state.get('status')}: {str(state.get('error') or '')[:300]}"
        status, session = probe_request(base, password, "POST", "/session",
                                        {"title": "browser probe", "permission": permission}, timeout=SESSION_TIMEOUT)
    except PROBE_ERRORS as exc:
        return f"failed: cannot reach the OpenCode server: {exc}"
    if status != 200 or not isinstance(session, dict) or not session.get("id"):
        return f"failed: POST /session returned HTTP {status}: {json.dumps(session)[:300]}"
    sid = session["id"]
    prompt = (f"Do these three steps in order, one tool call each. 1. Call {BROWSER_NAVIGATE} with url {page}. "
              f"2. Call {BROWSER_SNAPSHOT}. 3. Call {BROWSER_NAVIGATE} with url {BROWSER_OUTSIDE}. "
              "Step 3 may fail; that is expected. Then reply with the single word done.")
    try:
        body = {"model": {"providerID": provider, "modelID": model_id}, "parts": [{"type": "text", "text": prompt}]}
        try:
            status, reply = probe_request(base, password, "POST", f"/session/{sid}/message", body,
                                          timeout=BROWSER_PROMPT_TIMEOUT)
        except PROBE_ERRORS as exc:
            return f"failed: no reply from the prompt: {exc}"
        if status != 200 or not isinstance(reply, dict) or not isinstance(reply.get("info"), dict):
            return f"failed: POST /session/{sid}/message returned HTTP {status}: {json.dumps(reply)[:300]}"
        if reply["info"].get("error") is not None:
            return f"failed: {error_text(reply['info']['error'])}"
        try:
            parts = session_parts(base, password, sid)
        except (urllib.error.URLError, TimeoutError, ValueError) as exc:
            return f"failed: cannot read the session: {exc}"
        return browser_verdict(page, opts["--marker"], parts)
    finally:
        try:
            probe_request(base, password, "DELETE", f"/session/{sid}", timeout=10)
        except PROBE_ERRORS:
            pass


def skill_name(skill_file, folder):
    """The server lists a skill under the `name:` in its frontmatter, which can differ from its folder."""
    with open(skill_file, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().splitlines()
    if lines[:1] == ["---"]:
        for line in lines[1:]:
            if line.strip() == "---":
                break
            if line.startswith("name:"):
                return line[len("name:"):].strip().strip("\"'") or folder
    return folder


def user_skill_names(skills_dir):
    """The skills a Claude Code user has: each folder in skills_dir that holds a SKILL.md, by its listed name."""
    if not os.path.isdir(skills_dir):
        return []
    files = [(os.path.join(skills_dir, name, "SKILL.md"), name) for name in os.listdir(skills_dir)]
    return sorted(skill_name(path, name) for path, name in files if os.path.isfile(path))


def skill_verdict(listed, probe_name, marker, user_names):
    """What the server's skill list shows. A skill counts as loaded only with its body, the part a session is given."""
    bodies = {skill.get("name"): str(skill.get("content") or "") for skill in listed if isinstance(skill, dict)}
    if probe_name not in bodies:
        return f"not loaded: the throwaway project skill {probe_name} is not listed (the server lists {len(bodies)})"
    if marker not in bodies[probe_name]:
        return f"not loaded: the throwaway project skill {probe_name} is listed without its body"
    loaded = [name for name in user_names if bodies.get(name)]
    missing = [name for name in user_names if not bodies.get(name)]
    if missing:
        return f"not loaded: {len(loaded)} of {len(user_names)} user skills listed, missing {', '.join(missing)}"
    names = f" ({', '.join(loaded)})" if loaded else ""
    return f"loaded: a throwaway project skill and {len(loaded)} of {len(user_names)} user skills{names}"


def skill_probe(argv):
    """Ask a running OpenCode server which skills it loaded for a directory. The list costs no model call.

    `--directory` is the throwaway project holding `--name`, whose body holds `--marker`; `--user-skills` is the folder
    of the user's own skills, which OpenCode reads for every project.
    """
    opts = parse_probe_args(argv, "skill-probe", ("--url", "--password", "--directory", "--name", "--marker",
                                                  "--user-skills"), ())
    path = f"/skill?directory={urllib.parse.quote(opts['--directory'], safe='')}"
    try:
        status, listed = probe_request(opts["--url"], opts["--password"], "GET", path, timeout=SKILL_LIST_TIMEOUT)
    except json.JSONDecodeError:
        return "not available: the server has no skill list (GET /skill did not answer with JSON)"
    except (urllib.error.URLError, TimeoutError) as exc:
        return f"failed: cannot reach the OpenCode server: {exc}"
    if status == 404:
        return "not available: the server has no skill list (GET /skill returned HTTP 404)"
    if status != 200 or not isinstance(listed, list):
        return f"failed: GET /skill returned HTTP {status}: {json.dumps(listed)[:300]}"
    return skill_verdict(listed, opts["--name"], opts["--marker"], user_skill_names(opts["--user-skills"]))


def skill_call_verdict(name, marker, parts):
    """What a session's parts show: a completed skill call and the marker in the model's last text.

    A marker without the call is the model guessing, and a call without the marker did not deliver the skill body.
    """
    calls = [part for part in parts
             if isinstance(part, dict) and part.get("type") == "tool" and part.get("tool") == "skill"]
    states = [call.get("state") if isinstance(call.get("state"), dict) else {} for call in calls]
    said = ""
    for part in parts:
        if isinstance(part, dict) and part.get("type") == "text":
            said = str(part.get("text") or "")
    if not calls:
        return f"not available: the model made no skill call (it said: {said[:200]!r})"
    if not any(state.get("status") == "completed" for state in states):
        errors = " ".join(str(state.get("error") or state.get("status")) for state in states)
        return f"failed: the skill call did not complete: {errors[:300]}"
    if marker not in said:
        return f"failed: the skill call completed but the reply did not hold the marker (it said: {said[:200]!r})"
    return f"worked: called skill {name} and replied with its marker"


def skill_call_probe(argv):
    """Ask a running OpenCode server to call the skill tool for a project skill and report what it returned.

    Deliberate: the session allows only the skill tool, for the reason web_probe gives. The verdict reads the tool
    call in the session and the marker in the reply, so a model that guessed the marker without loading the skill
    cannot pass. The session is created in the project directory, where the skill lives.
    """
    opts = parse_probe_args(argv, "skill-call", ("--url", "--password", "--model", "--directory", "--name",
                                                 "--marker"), ())
    provider, sep, model_id = opts["--model"].partition("/")
    if not sep or not provider or not model_id:
        return f"failed: model {opts['--model']!r} is not provider/model"
    base, password, directory = opts["--url"], opts["--password"], opts["--directory"]
    permission = [{"permission": "*", "pattern": "*", "action": "deny"},
                  {"permission": "skill", "pattern": "*", "action": "allow"}]
    try:
        status, session = probe_request(base, password, "POST", "/session",
                                        {"title": "skill call probe", "permission": permission},
                                        timeout=SESSION_TIMEOUT, directory=directory)
    except PROBE_ERRORS as exc:
        return f"failed: cannot reach the OpenCode server: {exc}"
    if status != 200 or not isinstance(session, dict) or not session.get("id"):
        return f"failed: POST /session returned HTTP {status}: {json.dumps(session)[:300]}"
    sid = session["id"]
    prompt = (f"Use the skill tool to load the skill {opts['--name']}, then reply with the marker word it contains, "
              "and nothing else.")
    try:
        body = {"model": {"providerID": provider, "modelID": model_id},
                "parts": [{"type": "text", "text": prompt}]}
        try:
            status, reply = probe_request(base, password, "POST", f"/session/{sid}/message", body,
                                          timeout=SKILL_CALL_TIMEOUT, directory=directory)
        except PROBE_ERRORS as exc:
            return f"failed: no reply from the prompt: {exc}"
        if status != 200 or not isinstance(reply, dict) or not isinstance(reply.get("info"), dict):
            return f"failed: POST /session/{sid}/message returned HTTP {status}: {json.dumps(reply)[:300]}"
        if reply["info"].get("error") is not None:
            return f"failed: {error_text(reply['info']['error'])}"
        try:
            parts = session_parts(base, password, sid, directory)
        except (urllib.error.URLError, TimeoutError, ValueError) as exc:
            return f"failed: cannot read the session: {exc}"
        return skill_call_verdict(opts["--name"], opts["--marker"], parts)
    finally:
        try:
            probe_request(base, password, "DELETE", f"/session/{sid}", timeout=10, directory=directory)
        except PROBE_ERRORS:
            pass


def variants(spec):
    """Print the model's variant names, in the order `opencode models` lists them.

    `opencode models <provider> --verbose` writes the model ID on its own line, then that model's JSON object, so the
    block is read from the ID line rather than searched for by model id in a JSON string (the same id may appear in
    another model's fields)."""
    provider, sep, model_id = spec.partition("/")
    if not sep or not provider or not model_id:
        print(f"opencode_run: {spec!r} is not provider/model", file=sys.stderr)
        return 1
    try:
        proc = subprocess.run(["opencode", "models", provider, "--verbose"],
                              capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.SubprocessError) as exc:
        print(f"opencode_run: cannot run `opencode models {provider} --verbose`: {exc}", file=sys.stderr)
        return 2
    if proc.returncode != 0:
        detail = proc.stderr.strip()[:300] or f"exit {proc.returncode}"
        print(f"opencode_run: `opencode models {provider} --verbose` failed: {detail}", file=sys.stderr)
        return 2
    lines = proc.stdout.splitlines()
    try:
        start = next(i for i, line in enumerate(lines) if line.strip() == spec)
    except StopIteration:
        print(f"opencode_run: no model {spec} in `opencode models {provider} --verbose`", file=sys.stderr)
        return 1
    try:
        info, _ = json.JSONDecoder().raw_decode("\n".join(lines[start + 1:]).lstrip())
    except ValueError as exc:
        print(f"opencode_run: cannot read the listing for {spec}: {exc}", file=sys.stderr)
        return 2
    for name in (info.get("variants") or {}):
        print(name)
    return 0


def main(argv):
    cmd, args = argv[0], argv[1:]
    if cmd == "config":
        if args == ["--read-only"]:
            print(json.dumps(build_readonly_config(), indent=2))
            return 0
        tools, deny, i = [], [], 0
        temperature = top_p = None
        while i < len(args):
            if args[i] == "--deny":
                if i + 1 >= len(args):
                    sys.exit("opencode_run: --deny needs a value")
                deny.append(args[i + 1]); i += 2
            elif args[i] in ("--temperature", "--top-p"):
                if i + 1 >= len(args):
                    sys.exit(f"opencode_run: {args[i]} needs a value")
                if args[i] == "--temperature":
                    temperature = sampling_value(args[i], args[i + 1], 0.0, 2.0)
                else:
                    top_p = sampling_value(args[i], args[i + 1], 0.0, 1.0, low_open=True)
                i += 2
            else:
                tools.append(args[i]); i += 1
        print(json.dumps(build_config(tools, deny, temperature, top_p), indent=2))
    elif cmd == "variants":
        return variants(*args)
    elif cmd == "watch":
        watch(*args)
    elif cmd == "check":
        _, errs = checked(*args)
        print("\n".join(errs))
        return 1 if errs else 0
    elif cmd == "over":
        return 0 if totals(args[0])[0] > float(args[1]) else 1
    elif cmd == "session":
        sid = next((ev["sessionID"] for ev in events(args[0]) if ev.get("sessionID")), "")
        if not sid:
            print("opencode_run: no sessionID in the log", file=sys.stderr)
            return 1
        print(sid)
    elif cmd == "result":
        refused = args[args.index("--refused") + 1] if "--refused" in args else None
        result(*args[:4], refused=refused)
    elif cmd == "events-denials":
        print(json.dumps(event_denials(args[0])))
    elif cmd == "limit":
        hit = limit(args[0])
        if hit is None:
            return 1
        print(f"{hit[0]}\t{hit[1] if hit[1] is not None else ''}")
    elif cmd == "schema-probe":
        line = schema_probe(args)
        print(line)
        return 1 if line.startswith(("failed:", "unsupported:")) else 0
    elif cmd == "web-probe":
        line = web_probe(args)
        print(line)
        return 0 if line.startswith("worked:") else 1
    elif cmd == "browser-probe":
        line = browser_probe(args)
        print(line)
        return 0 if line.startswith("worked:") else 1
    elif cmd == "skill-probe":
        line = skill_probe(args)
        print(line)
        return 0 if line.startswith("loaded:") else 1
    elif cmd == "skill-call":
        line = skill_call_probe(args)
        print(line)
        return 0 if line.startswith("worked:") else 1
    else:
        sys.exit(f"opencode_run: unknown command {cmd!r}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
