#!/usr/bin/env python3
"""OpenCode builder runs, for scripts/opencode-builder.sh and scripts/dispatch.sh.

config   <tool>... [--deny <tool>]...   the OpenCode config a builder runs under, from dispatch's Claude-style grants
config   --read-only                   the OpenCode config a review runs under: reads allowed, everything else denied
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

Python stdlib only: jsonschema is not installed, so `validate` covers the keywords schema/result.json uses
(type, enum, properties, required, items, additionalProperties) and fails loud on any other keyword.
"""
import base64
import email.utils
import json
import os
import re
import signal
import sys
import time
import urllib.error
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
KNOWN = {"type", "enum", "properties", "required", "items", "description", "additionalProperties"}
DENIAL = re.compile(r"permission|prevents you from using|rejected", re.I)


def bash_pattern(grant):
    match = re.fullmatch(r"Bash\((.*)\)", grant)
    return match.group(1) if match else None


def build_config(tools, deny):
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
            cost += part["cost"]
            tok = part.get("tokens", {})
            out += tok.get("output", 0)
            cache += tok.get("cache", {}).get("read", 0)
    return cost, out, cache


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


def normalize(obj):
    """Repair two shapes models write for an empty list: a boolean, and a namespaced duplicate.

    A review's `blocking`/`suggestions` must be arrays. Some models write `"blocking": false` (or true plus a
    `blocking_findings` list) instead of `[]`; accept that rather than throwing away an otherwise valid review.
    """
    if not isinstance(obj, dict):
        return obj
    for key in ("blocking", "suggestions"):
        value = obj.get(key)
        if isinstance(value, bool):
            other = obj.get(f"{key}_findings")
            obj[key] = other if value and isinstance(other, list) else []
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
            "opencode_version": os.environ.get("WS_RUN_OPENCODE_VERSION", ""),
            "usage": {"output_tokens": out, "cache_read_input_tokens": cache},
            "permission_denials": denied_calls, "structured_output": so, "result": text}
    end_log_line(log)
    # Compact separators: result_json (scripts/lib.sh) greps for "type":"result" with no space.
    print(json.dumps(line, separators=(",", ":")))


def probe_request(base, password, method, path, body=None, timeout=180):
    """One JSON call to an `opencode serve`; a non-2xx reply is returned, not raised, so the caller reports it."""
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


def parse_probe_args(args):
    values = {"--retry": "2"}
    allowed = {"--url", "--password", "--model", "--schema", "--prompt", "--retry"}
    i = 0
    while i < len(args):
        if args[i] not in allowed or i + 1 >= len(args):
            sys.exit(f"opencode_run: schema-probe takes {sorted(allowed)} with a value, not {args[i]!r}")
        values[args[i]] = args[i + 1]
        i += 2
    for key in ("--url", "--password", "--model", "--schema", "--prompt"):
        if not values.get(key):
            sys.exit(f"opencode_run: schema-probe needs {key}")
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


def main(argv):
    cmd, args = argv[0], argv[1:]
    if cmd == "config":
        if args == ["--read-only"]:
            print(json.dumps(build_readonly_config(), indent=2))
            return 0
        tools, deny, i = [], [], 0
        while i < len(args):
            if args[i] == "--deny":
                deny.append(args[i + 1]); i += 2
            else:
                tools.append(args[i]); i += 1
        print(json.dumps(build_config(tools, deny), indent=2))
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
    else:
        sys.exit(f"opencode_run: unknown command {cmd!r}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
