"""A Claude Code Stop hook: a reply whose leading local time is more than two minutes off the clock is sent back to be
corrected. The hook reads its JSON on stdin, finds the reply that is ending, and prints the block decision when that
reply starts with HH:MM followed by an em dash or hyphen. The reply is the last assistant text block and the text
blocks before it with no intervening entry that starts a reply. An operator message, a notification, or a tool result
answering the question tool ends one reply and starts the next; a plain tool result (a command, a read) does not,
since a reply that runs tools continues after the result, nor does an injected meta note. The time written in the
transcript is compared with the reply's own timestamp, so a long reply is not judged against the clock at its end.
A timestamp without a zone falls back to the clock instead of guessing one, and an unreadable transcript or stdin
passes the reply through rather than blocking it. WS_NOW=HH:MM overrides the clock for the selftest, and `--selftest`
runs the cases on fake transcripts."""
import json
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime
from zoneinfo import ZoneInfo

LEADING_TIME = re.compile(r"^\s*(\d{1,2}):(\d{2})\s+[—-]")
OFF_BY = 2


def current_minute():
    """Minutes since midnight on the local clock, in WS_TZ when set."""
    override = os.environ.get("WS_NOW")
    if override:
        hour, minute = override.split(":")
        return int(hour) * 60 + int(minute)
    zone = os.environ.get("WS_TZ")
    if zone:
        now = datetime.now(ZoneInfo(zone))
    else:
        now = datetime.now()
    return now.hour * 60 + now.minute


def question_tool_ids(entries):
    """The ids of question-tool calls, whose results carry the operator's answer rather than a tool's output."""
    ids = set()
    for event in entries:
        if event.get("type") != "assistant":
            continue
        content = (event.get("message") or {}).get("content") or []
        for part in content:
            if (
                isinstance(part, dict)
                and part.get("type") == "tool_use"
                and part.get("name") == "AskUserQuestion"
                and part.get("id")
            ):
                ids.add(part["id"])
    return ids


def starts_new_reply(event, question_ids):
    """True for a user entry that opens a new reply: an operator message, a notification, or a question answer.

    A plain tool result does not open a reply: the reply that called the tool goes on after it, so a progress note
    before a tool call is still judged against the reply's own opening time. An injected meta note also arrives as a
    user entry but sits between the text blocks of one reply, so it does not.
    """
    if event.get("type") != "user":
        return False
    if event.get("isMeta") or (event.get("message") or {}).get("isMeta"):
        return False
    content = (event.get("message") or {}).get("content")
    if isinstance(content, str):
        return True
    if isinstance(content, list):
        for part in content:
            if not isinstance(part, dict):
                continue
            if part.get("type") != "tool_result":
                return True
            if part.get("tool_use_id") in question_ids:
                return True
    return False


def timestamp_minute(stamp):
    """Minutes since midnight in WS_TZ (or local) for a transcript timestamp, or None when absent or unreadable."""
    if not isinstance(stamp, str) or not stamp:
        return None
    try:
        at = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
    except ValueError:
        return None
    if at.tzinfo is None:
        # Transcript timestamps carry a zone (Claude Code writes UTC with a trailing Z). A naive one is a broken
        # shape, so return None and let the caller fall back to the clock rather than guess a zone.
        return None
    zone = os.environ.get("WS_TZ")
    at = at.astimezone(ZoneInfo(zone)) if zone else at.astimezone()
    return at.hour * 60 + at.minute


def text_blocks(event):
    """The non-blank text blocks of an assistant entry, in order."""
    if event.get("type") != "assistant":
        return []
    content = (event.get("message") or {}).get("content") or []
    return [
        part.get("text") or ""
        for part in content
        if isinstance(part, dict) and part.get("type") == "text" and (part.get("text") or "").strip()
    ]


def last_turn_text(path):
    """The text of the reply that is ending and its first text block's timestamp, or (None, None) when unreadable.

    The reply is the last assistant text block and the text blocks before it with no intervening user entry that
    starts a new reply. Walking back from the last text block stops at the first such user entry, so the leading time
    judged is the one the reply opened with, not one from an earlier answer in the same transcript.
    """
    try:
        with open(path, errors="replace") as transcript:
            lines = transcript.readlines()
    except OSError:
        # Deliberate: a Stop hook that blocked on its own unreadable transcript would trap the reply it cannot
        # judge, so a missing or unreadable file passes the reply through.
        return None, None
    entries = []
    for line in lines:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if isinstance(event, dict):
            entries.append(event)
    last = None
    for index, event in enumerate(entries):
        if text_blocks(event):
            last = index
    if last is None:
        return None, None
    question_ids = question_tool_ids(entries)
    # An operator message or question answer after the last text block opens a newer reply. That reply has no text
    # yet (it only ran tools), so the text found here belongs to an older reply and must not be judged again.
    for event in entries[last + 1:]:
        if starts_new_reply(event, question_ids):
            return None, None
    start = last
    while start > 0 and not starts_new_reply(entries[start - 1], question_ids):
        start -= 1
    texts = []
    written = None
    for event in entries[start:last + 1]:
        for text in text_blocks(event):
            if written is None:
                written = event.get("timestamp")
            texts.append(text)
    return "\n".join(texts), written


def gap_in_minutes(typed, now):
    """The signed distance from now to the typed time, shortest way around midnight."""
    gap = (typed - now + 1440) % 1440
    return gap - 1440 if gap > 720 else gap


def check(hook):
    """The block reason for a reply whose leading time is off the clock, or None when the reply passes."""
    text, written = last_turn_text(hook.get("transcript_path") or "")
    if not text:
        return None
    match = LEADING_TIME.match(text)
    if not match:
        return None
    hour, minute = int(match.group(1)), int(match.group(2))
    if hour > 23 or minute > 59:
        return None
    typed = hour * 60 + minute
    now = timestamp_minute(written)
    if now is None:
        # Deliberate: a timestamp with no zone falls back to the clock at the end of the reply, so a long reply is
        # judged against its end time rather than its start. A timestamp comparison cannot fix that without a zone.
        now = current_minute()
    if abs(gap_in_minutes(typed, now)) <= OFF_BY:
        return None
    return (
        f"reply started with {hour:02d}:{minute:02d}, but the clock says {now // 60:02d}:{now % 60:02d}; "
        "correct the time in a short follow-up and take times from date"
    )


def main():
    try:
        hook = json.loads(sys.stdin.read())
    except ValueError:
        # Deliberate: a hook that cannot parse its own input must not block the reply, so bad stdin passes through.
        return
    if not isinstance(hook, dict) or hook.get("stop_hook_active"):
        return
    block = check(hook)
    if block:
        print(json.dumps({"decision": "block", "reason": block}))


def selftest():
    """Runs the hook as a subprocess on fake transcripts with a fixed clock."""
    fails = 0
    with tempfile.TemporaryDirectory() as tmp:

        def transcript(name, text, at=None):
            path = os.path.join(tmp, name)
            assistant = {"type": "assistant", "message": {"content": [{"type": "text", "text": text}]}}
            if at:
                assistant["timestamp"] = at
            with open(path, "w") as fh:
                fh.write(json.dumps({"type": "user", "message": {"role": "user", "content": "go"}}) + "\n")
                fh.write(json.dumps(assistant) + "\n")
            return path

        def transcript_entries(name, entries):
            """Writes the entries as JSONL and returns the path, so a case can build any transcript shape."""
            path = os.path.join(tmp, name)
            with open(path, "w") as fh:
                for entry in entries:
                    fh.write(json.dumps(entry) + "\n")
            return path

        def operator(text="go"):
            return {"type": "user", "message": {"role": "user", "content": text}}

        def reply(text, at):
            return {"type": "assistant", "timestamp": at, "message": {"content": [{"type": "text", "text": text}]}}

        def transcript_with_tools(name, text, at):
            """A reply that opens with a wrong time, runs a tool, then writes more text after the result."""
            return transcript_entries(name, [
                operator(),
                {"type": "assistant", "timestamp": at, "message": {"content": [
                    {"type": "text", "text": text},
                    {"type": "tool_use", "id": "t1", "name": "Bash", "input": {}},
                ]}},
                tool_result(),
                {"type": "assistant", "message": {"content": [{"type": "text", "text": "done"}]}},
                {"type": "user", "isMeta": True, "message": {"role": "user", "content": "meta"}},
                {"type": "assistant", "message": {"content": [{"type": "text", "text": "still done"}]}},
            ])

        def question_call():
            return {"type": "assistant", "message": {"content": [
                {"type": "tool_use", "id": "q1", "name": "AskUserQuestion", "input": {}},
            ]}}

        def question_answer():
            return {"type": "user", "message": {"role": "user", "content": [
                {"type": "tool_result", "tool_use_id": "q1", "content": "the answer"},
            ]}}

        def notification(text="<task-notification>wait finished</task-notification>"):
            return {"type": "user", "message": {"role": "user", "content": [
                {"type": "text", "text": text},
            ]}}

        def tool_result(tool_id="t1"):
            return {"type": "user", "message": {"role": "user", "content": [
                {"type": "tool_result", "tool_use_id": tool_id, "content": "ok"},
            ]}}

        def run(path, now, active):
            env = dict(os.environ, WS_NOW=now, WS_TZ="UTC")
            result = subprocess.run(
                [sys.executable, "-I", os.path.abspath(__file__)],
                input=json.dumps({"transcript_path": path, "stop_hook_active": active}),
                capture_output=True,
                text=True,
                env=env,
                check=False,
            )
            return result.returncode, result.stdout

        def passes(name, path, now, active=False):
            nonlocal fails
            code, output = run(path, now, active)
            if code == 0 and not output:
                print(f"reply time {name} ok")
            else:
                print(f"reply time {name} FAILED (exit {code}): {output.rstrip()}")
                fails += 1

        def blocks(name, path, now, typed):
            nonlocal fails
            code, output = run(path, now, False)
            try:
                decision = json.loads(output)
            except ValueError:
                decision = {}
            reason = decision.get("reason") or ""
            if code == 0 and decision.get("decision") == "block" and f"reply started with {typed}, but the clock says {now}" in reason:
                print(f"reply time {name} ok")
            else:
                print(f"reply time {name} FAILED (exit {code}): {output.rstrip()}")
                fails += 1

        passes("a matching time", transcript("same.jsonl", "20:15 — merged"), "20:15")
        blocks("a time ten minutes off", transcript("off.jsonl", "20:12 — merged"), "20:01", "20:12")
        passes("stop_hook_active true", transcript("active.jsonl", "20:12 — merged"), "20:01", True)
        passes("no leading time", transcript("plain.jsonl", "Merged at 20:12; tests pass"), "20:03")
        passes("23:59 against 00:00", transcript("midnight.jsonl", "23:59 — late"), "00:00")
        passes("a missing transcript", os.path.join(tmp, "missing.jsonl"), "20:01")
        # A plain tool result does not start a reply: the reply that called the tool goes on after it.
        blocks(
            "a time off before a tool call",
            transcript_with_tools("tools.jsonl", "20:12 — merging", "2026-01-15T20:01:00+00:00"),
            "20:01",
            "20:12",
        )
        # A question answer or a notification does start one: an earlier answer is never the reply being judged.
        passes(
            "an old wrong reply before a question answer",
            transcript_entries("old-wrong.jsonl", [
                operator(),
                reply("20:24 — from the evening before", "2026-11-02T20:21:00+00:00"),
                question_call(),
                question_answer(),
                reply("08:57 — this morning", "2026-11-03T08:57:00+00:00"),
            ]),
            "08:57",
        )
        blocks(
            "a wrong newest reply after a question answer",
            transcript_entries("new-wrong.jsonl", [
                operator(),
                reply("08:57 — earlier", "2026-11-03T08:57:00+00:00"),
                question_call(),
                question_answer(),
                reply("09:20 — newest", "2026-11-03T09:10:00+00:00"),
            ]),
            "09:10",
            "09:20",
        )
        passes(
            "an old wrong reply before a notification",
            transcript_entries("old-wrong-notice.jsonl", [
                operator(),
                reply("20:24 — from the evening before", "2026-11-02T20:21:00+00:00"),
                notification(),
                reply("08:57 — this morning", "2026-11-03T08:57:00+00:00"),
            ]),
            "08:57",
        )
        # A meta note does not start a reply: the run keeps the time it opened with.
        blocks(
            "the first block of a reply across a meta note",
            transcript_entries("meta-run.jsonl", [
                operator(),
                reply("20:12 — merging", "2026-01-15T20:01:00+00:00"),
                {"type": "user", "isMeta": True, "message": {"role": "user", "content": "meta"}},
                {"type": "assistant", "message": {"content": [{"type": "text", "text": "still merging"}]}},
            ]),
            "20:01",
            "20:12",
        )
        passes(
            "a long turn checked against its own timestamp",
            transcript("long.jsonl", "20:01 — started", "2026-01-15T20:01:00+00:00"),
            "20:40",
        )
        blocks(
            "a single-digit hour off the clock",
            transcript("single.jsonl", "9:12 — merged"),
            "09:01",
            "09:12",
        )
        blocks(
            "a timestamp without a zone falls back to the clock",
            transcript("naive.jsonl", "20:12 — merged", "2026-01-15T20:01:00"),
            "19:00",
            "20:12",
        )
        blocks(
            "a question call with no id does not make a bare tool result an answer",
            transcript_entries("no-id.jsonl", [
                operator(),
                reply("20:12 — merging", "2026-01-15T20:01:00+00:00"),
                {"type": "assistant", "message": {"content": [
                    {"type": "tool_use", "name": "AskUserQuestion", "input": {}},
                ]}},
                {"type": "user", "message": {"role": "user", "content": [
                    {"type": "tool_result", "content": "ok"},
                ]}},
                {"type": "assistant", "message": {"content": [{"type": "text", "text": "still merging"}]}},
            ]),
            "20:01",
            "20:12",
        )
        passes(
            "a tool-only newest reply after an operator message",
            transcript_entries("tool-only-newest.jsonl", [
                operator(),
                reply("20:12 — earlier", "2026-11-02T20:01:00+00:00"),
                operator(),
                {"type": "assistant", "message": {"content": [
                    {"type": "tool_use", "id": "t2", "name": "Bash", "input": {}},
                ]}},
            ]),
            "20:01",
        )
        # A saved turn with each content block in its own assistant entry, an attachment entry and a system entry:
        # the shape a real transcript writes, so a schema mismatch fails here instead of letting a wrong time through.
        # Deliberate: the fixture is reduced to the fields the hook reads today, so it is not a full transcript
        # sample; a field the hook should read later will not appear here until the fixture is extended.
        blocks(
            "a sanitised real turn with a question answer",
            os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures", "reply-time-real-turn.jsonl"),
            "09:00",
            "09:05",
        )
    if fails:
        return 1
    print("reply-time check ok")
    return 0


if __name__ == "__main__":
    if sys.argv[1:] == ["--selftest"]:
        sys.exit(selftest())
    main()
