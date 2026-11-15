#!/usr/bin/env python3
"""The denied calls of one run and the grant each would have needed, one line for `ws wait` to print.

A deny guard names the closest grant in the refusal the model receives, so that name is read back from the run log
when it is there; a call OpenCode's own permission map refused carries no refusal text, so its grant is computed
from the builder's grant file by the same rule (`scripts/grant-suggest.js`): the grant sharing the longest run of
the command's own words. A call no grant shares a first word with is reported as uncovered.

Usage: denied-summary.py <run.jsonl> [grants-file]
The run's events file (`<name>.events.jsonl` beside it) is read too, so a denial the permission events record and
the log does not is still counted. Prints nothing, exit 0, when the run made no denied call, and when its grants
file does not exist: a run recorded before the grants list existed, or an imported one, has no list to compare a
refusal with.
"""

import json
import os
import re
import sys

DENIAL = re.compile(r"permission|prevents you from using|rejected", re.I)
CLOSEST = re.compile(r"closest grant: (Bash\([^)]*\))")
NO_GRANT = "no grant covers this"
SHOWN = 3


def lines(path):
    """JSON records of a file, one per line; a partial last line is not a record."""
    try:
        handle = open(path, encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return
    with handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(record, dict):
                yield record


def label(tool, tool_input):
    """The call as a person reads it: its command, else its path or pattern, else the tool's name."""
    if isinstance(tool_input, dict):
        for key in ("command", "filePath", "path", "pattern", "title"):
            if tool_input.get(key):
                return str(tool_input[key])
    return str(tool or "tool")


def logged_denials(log):
    """Denied calls in the agent log: OpenCode's failed tool calls and Claude's result line, with any refusal text."""
    found = []
    for record in lines(log):
        if record.get("type") == "tool_use":
            part = record.get("part") or {}
            state = part.get("state") or {}
            message = str(state.get("error", ""))
            if state.get("status") == "error" and DENIAL.search(message):
                found.append((label(part.get("tool"), state.get("input") or {}), message))
        elif record.get("type") == "result":
            for denial in record.get("permission_denials") or []:
                if isinstance(denial, dict):
                    found.append((label(denial.get("tool_name"), denial.get("tool_input") or {}), ""))
    return found


def event_denials(log):
    """Denied tool calls from the run-events plugin: the refused permission and a failed call's refusal text."""
    found = []
    by_request = {}
    for record in lines(events_path(log)):
        kind = record.get("event")
        if kind in ("permission.asked", "permission.ask"):
            by_request[record.get("request_id") or ""] = record
            if kind == "permission.ask" and str(record.get("status", "")).lower() in ("deny", "reject"):
                found.append((label(record.get("title"), record.get("metadata") or {}), ""))
        elif kind == "permission.replied" and str(record.get("reply", "")).lower() in ("deny", "reject"):
            ask = by_request.get(record.get("request_id") or "", record)
            found.append((label(ask.get("title"), ask.get("metadata") or {}), ""))
        elif kind == "tool.finished" and record.get("status") == "error":
            message = str(record.get("message", ""))
            if DENIAL.search(message):
                found.append((label(record.get("tool_name"), record.get("tool_input") or {}), message))
    return found


def events_path(log):
    """The builder's event file sits beside its log, as scripts/opencode_run.py reads it."""
    return log[:-6] + ".events.jsonl" if log.endswith(".jsonl") else log + ".events.jsonl"


def grant_pattern(grants):
    """One grant rule reduced to its pattern words, whatever `Bash(...)` wrapper it was written with."""
    body = re.sub(r"^Bash\((.*)\)$", r"\1", grants.strip())
    return body.split()


def word_matches(word, pattern):
    if "*" not in pattern:
        return word == pattern
    regex = "^" + ".*".join(re.escape(part) for part in pattern.split("*")) + "$"
    return re.match(regex, word) is not None


def closest_grant(command, grants):
    """The grant sharing the longest run of the command's first words, as `Bash(...)`, or None."""
    words = command.split()
    best = None
    best_words = 0
    for grant in grants:
        pattern = grant_pattern(grant)
        matched = 0
        while matched < len(words) and matched < len(pattern) and word_matches(words[matched], pattern[matched]):
            matched += 1
        if matched > best_words:
            best = " ".join(pattern)
            best_words = matched
    return f"Bash({best})" if best else None


def suggestion(command, message, grants):
    """The grant named in the refusal, else the closest grant in the builder's list."""
    named = CLOSEST.search(message or "")
    if named:
        return named.group(1)
    if NO_GRANT in (message or ""):
        return None
    if grants is None:
        return None
    return closest_grant(command, grants)


def summary(log, grants_path=None):
    """The denied calls of a run, each with its suggested grant, in the order they first appear."""
    grants = None
    if grants_path:
        with open(grants_path, encoding="utf-8", errors="replace") as handle:
            grants = [line.strip() for line in handle if line.strip()]
    found = {}
    for command, message in logged_denials(log) + event_denials(log):
        found.setdefault(command, suggestion(command, message, grants))
    return list(found.items())


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        print("usage: denied-summary.py <run.jsonl> [grants-file]", file=sys.stderr)
        return 2
    grants_path = argv[2] if len(argv) > 2 else None
    # `ws wait` passes the grants path for every run, including the ones recorded before dispatch wrote the list:
    # without it a refusal has no list to compare against, so there is no summary to print.
    if grants_path is not None and not os.path.exists(grants_path):
        return 0
    denied = summary(argv[1], grants_path)
    if not denied:
        return 0
    shown = []
    for command, grant in denied[:SHOWN]:
        shown.append(f"{command} (closest grant: {grant})" if grant else f"{command} (no grant covers this)")
    rest = len(denied) - len(shown)
    print(f"denied: {len(denied)} call(s); " + "; ".join(shown) + (f", {rest} more" if rest > 0 else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
