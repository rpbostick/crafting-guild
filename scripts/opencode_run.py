#!/usr/bin/env python3
"""OpenCode builder runs, for scripts/opencode-builder.sh and scripts/dispatch.sh.

config   <tool>... [--deny <tool>]...   the OpenCode config a builder runs under, from dispatch's Claude-style grants
watch    <log> <budget> <pid>          stop <pid> once the step costs in <log> pass <budget> dollars
check    <log> <schema>                exit 0 when the last text part is a valid result; else print the errors
over     <log> <budget>                exit 0 when the step costs in <log> are past <budget>
session  <log>                         the session ID the log's events carry
result   <log> <schema> <budget> <duration_ms> [--refused <reason>]
                                       the Claude-shaped result line scripts/lib.sh result_json finds

Python stdlib only: jsonschema is not installed, so `validate` covers the keywords schema/result.json uses
(type, enum, properties, required, items) and fails loud on any other keyword.
"""
import json
import os
import re
import signal
import sys
import time

# Deliberate: every permission is set, ending in allow or deny. A builder runs headless, so a rule left at OpenCode's
# default "ask" (doom_loop, a read of .env) would wait on a prompt nobody answers.
FIXED = {"read": "allow", "glob": "allow", "grep": "allow", "list": "allow", "lsp": "allow",
         "todoread": "allow", "todowrite": "allow", "task": "deny", "skill": "deny", "question": "deny",
         "doom_loop": "deny", "external_directory": "deny", "codesearch": "deny"}
KNOWN = {"type", "enum", "properties", "required", "items", "description"}
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
    if isinstance(value, list) and "items" in schema:
        for i, item in enumerate(value):
            errs += validate(item, schema["items"], f"{path}[{i}]")
    return errs


def checked(log, schema_path):
    with open(schema_path, encoding="utf-8") as fh:
        schema = json.load(fh)
    obj, err = extract(last_text(log))
    if err:
        return None, [err]
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
    line = {"type": "result", "agent": "opencode", "total_cost_usd": round(cost, 6), "duration_ms": int(duration_ms),
            "usage": {"output_tokens": out, "cache_read_input_tokens": cache},
            "permission_denials": denials(log), "structured_output": so, "result": text}
    end_log_line(log)
    # Compact separators: result_json (scripts/lib.sh) greps for "type":"result" with no space.
    print(json.dumps(line, separators=(",", ":")))


def main(argv):
    cmd, args = argv[0], argv[1:]
    if cmd == "config":
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
    else:
        sys.exit(f"opencode_run: unknown command {cmd!r}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
