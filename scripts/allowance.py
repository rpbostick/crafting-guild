#!/usr/bin/env python3
"""OpenCode Go spend against one shared, weighted pool, from OpenCode's local database (opened read-only).

report                 one line per window: the summed percentage, each model's spend and its part, and the
                       total the hold uses
check --model <id>     exit 0 under the hold, 3 past it (the reason on stdout), 4 unmeasured (why on stdout)
past                   one line naming every window past the hold; nothing when none is

Every command takes --db <file> --hold <percent> --limits "<model=5h,7d,30d> ..." [--now <epoch seconds>]
[--starts "<5h-epoch>,<7d-epoch>,<30d-epoch>"].

The pool is shared and weighted: a window's percentage is the sum of each model's spend divided by that
model's limit, so a model alone reaches 100% at its own limit. Every number is an estimate. Go counts each
request in the response's `opencode.allowance`, which reaches neither the event stream nor this database, so
the meter sums the priced `cost` OpenCode stores on each assistant message. With WS_ALLOWANCE_STARTS unset
the windows are rolling and the output says so; when set, each window counts from the Console's start, and a
window whose time has passed starts at the first request after it. Only this machine's sessions count.

Deliberate: Python's sqlite3 module, not the sqlite3 command, which a machine with OpenCode need not have.
"""
import os
import sqlite3
import sys
import time

PROVIDER = "opencode-go"
HOUR = 3600
WINDOWS = (("5h", 5 * HOUR), ("7d", 7 * 24 * HOUR), ("30d", 30 * 24 * HOUR))
LONGEST = WINDOWS[-1][1]
PAST, UNMEASURED, UNREADABLE = 3, 4, 2


class Unreadable(Exception):
    """The settings or the database cannot be read: the meter must not read as zero spend."""


def parse_limits(text):
    limits = {}
    for entry in text.split():
        model, _, dollars = entry.partition("=")
        try:
            values = [float(part) for part in dollars.split(",")]
        except ValueError:
            values = []
        if not model or len(values) != len(WINDOWS) or min(values) <= 0:
            raise Unreadable(f"limit '{entry}' is not <model>=<5h>,<7d>,<30d> in dollars (WS_ALLOWANCE_LIMITS)")
        limits[model] = dict(zip((name for name, _ in WINDOWS), values))
    return limits


def parse_starts(text):
    """The Console's window starts as three epochs, or None when the windows roll."""
    if not text:
        return None
    try:
        starts = [int(part) for part in text.split(",")]
    except ValueError:
        starts = []
    if len(starts) != len(WINDOWS):
        raise Unreadable(f"starts '{text}' is not <5h-epoch>,<7d-epoch>,<30d-epoch> (WS_ALLOWANCE_STARTS)")
    return starts


def spend_rows(path, now, since):
    """{model: [(epoch seconds, dollars), ...]} oldest first, from <since> to now."""
    try:
        database = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=5)
        rows = database.execute(
            "select json_extract(data, '$.modelID'), time_created, json_extract(data, '$.cost') from message "
            "where time_created >= ? and json_extract(data, '$.providerID') = ? "
            "and json_extract(data, '$.cost') > 0 order by time_created",
            (int(since * 1000), PROVIDER)).fetchall()
    except sqlite3.Error as error:
        raise Unreadable(f"cannot read {path}: {error}") from error
    spend = {}
    for model, created, cost in rows:
        spend.setdefault(f"{PROVIDER}/{model}", []).append((created / 1000, cost))
    return spend


def all_rows(spend):
    return sorted((when, cost) for rows in spend.values() for when, cost in rows)


def first_request_after(rows, when):
    for created, _ in rows:
        if created > when:
            return created
    return None


def window_bounds(starts, rows, now):
    """(name, span, start) per window; start None means a rolling window ending at now."""
    if starts is None:
        return [(name, span, None) for name, span in WINDOWS]
    bounds = []
    for start, (name, span) in zip(starts, WINDOWS):
        # A start the Console gave only holds until its window has passed: the next request after that
        # window's end begins the current one. The longer windows reset at a plan change, which the
        # Console's start names, so in normal use this loop runs only for the 5-hour window.
        while start + span <= now:
            following = first_request_after(rows, start + span)
            if following is None:
                start += span
                break
            start = following
        bounds.append((name, span, start))
    return bounds


def window_spend(rows, now, span, start):
    if start is None:
        return sum(cost for when, cost in rows if now - span < when <= now)
    return sum(cost for when, cost in rows if start <= when <= now)


def window_parts(spend, limits, name, span, start, now):
    """(model, spent, limit, percent) per model; limit and percent are None for a model with no limit."""
    parts = []
    for model in sorted(set(limits) | set(spend)):
        spent = window_spend(spend.get(model, []), now, span, start)
        limit = limits.get(model)
        if limit is None:
            parts.append((model, spent, None, None))
        else:
            parts.append((model, spent, limit[name], spent / limit[name] * 100))
    return parts


def pooled_percent(parts):
    return sum(part for _, _, limit, part in parts if limit is not None)


def clears_at(spend, limits, name, span, start, now, hold):
    """When this window's pooled percentage drops under <hold>: its reset, or the spend ageing out."""
    if start is not None:
        return start + span
    threshold = hold / 100
    events = sorted((when, cost / limits[model][name])
                    for model, rows in spend.items() if model in limits
                    for when, cost in rows)
    total = sum(weight for when, weight in events if now - span < when <= now)
    for when, weight in events:
        if now - span < when <= now:
            total -= weight
            if total < threshold:
                return when + span
    return now


def over_hold(spend, limits, hold, now, starts):
    """(window, pooled percent, parts, clears) for each window at or past the hold."""
    found = []
    for name, span, start in window_bounds(starts, all_rows(spend), now):
        parts = window_parts(spend, limits, name, span, start, now)
        percent = pooled_percent(parts)
        if percent >= hold:
            found.append((name, percent, parts, clears_at(spend, limits, name, span, start, now, hold)))
    return found


def describe(window):
    name, percent, parts, _ = window
    pieces = []
    for model, spent, limit, part in parts:
        if limit is None:
            pieces.append(f"{model} ~${spent:.2f} (no limit, not counted)")
        else:
            pieces.append(f"{model} ~${spent:.2f}/${limit:g} {part:.1f}%")
    return f"{name} summed ~{percent:.1f}% (" + ", ".join(pieces) + ")"


def reason(found, hold):
    text = "; ".join(describe(window) for window in found)
    clear = time.strftime("%Y-%m-%d %H:%M", time.localtime(max(window[3] for window in found)))
    return f"{PROVIDER} pool is past the {hold:g}% allowance hold: {text}, estimated; clears about {clear}"


def report(path, limits, hold, now, starts):
    spend = spend_rows(path, now, min([now - LONGEST] + (starts or [])))
    rows = all_rows(spend)
    print("OpenCode Go spend, one shared, weighted pool. Every number is an estimate (~), from OpenCode's priced cost:")
    if starts is None:
        print("opencode.allowance is not in the local record; windows are taken as rolling, this machine only.")
    else:
        print("opencode.allowance is not in the local record; window starts are taken from WS_ALLOWANCE_STARTS, this machine only.")
    for name, span, start in window_bounds(starts, rows, now):
        label = f"{name} rolling" if start is None else f"{name} from {time.strftime('%Y-%m-%d %H:%M', time.localtime(start))}"
        parts = window_parts(spend, limits, name, span, start, now)
        if not any(limit is not None for _, _, limit, _ in parts):
            print(f"{label}  not measured: no model has a limit in WS_ALLOWANCE_LIMITS")
            continue
        percent = pooled_percent(parts)
        cells = ", ".join(f"{model} ~${spent:.2f} (no limit, not counted)" if limit is None
                          else f"{model} ~${spent:.2f}/${limit:g} {part:.1f}%"
                          for model, spent, limit, part in parts)
        flag = "  PAST HOLD" if percent >= hold else ""
        print(f"{label}  summed ~{percent:.1f}% (the hold uses this): {cells}{flag}")
    print(f"Hold: {hold:g}% of the summed window total (WS_ALLOWANCE_HOLD). Held: ws bench run, ws review-compare, shadow reviews.")
    print("The Console shows the real remainder; a model that stopped below its limit here means the limits need lowering.")


def check(path, limits, hold, now, model, starts):
    if not model.startswith(f"{PROVIDER}/"):
        return 0
    if not os.path.exists(path):
        print(f"no OpenCode database at {path}, so the allowance is not measured")
        return UNMEASURED
    spend = spend_rows(path, now, min([now - LONGEST] + (starts or [])))
    found = over_hold(spend, limits, hold, now, starts)
    if found:
        print(reason(found, hold))
        return PAST
    if model not in limits:
        print(f"{model} has no limit in WS_ALLOWANCE_LIMITS, so its allowance is not measured")
        return UNMEASURED
    return 0


def past(path, limits, hold, now, starts):
    # Deliberate: no database is a machine that has never run OpenCode, not a fault to print at every cold start.
    if not os.path.exists(path):
        return 0
    spend = spend_rows(path, now, min([now - LONGEST] + (starts or [])))
    found = over_hold(spend, limits, hold, now, starts)
    if found:
        print(reason(found, hold))
    return 0


def options(words):
    """The flags as a dict; an unknown or valueless flag is an error, so a typed --hold is never ignored."""
    found = {}
    for flag, value in zip(words[::2], words[1::2] + [None]):
        if flag not in ("--db", "--hold", "--limits", "--now", "--model", "--starts") or value is None:
            raise Unreadable(f"bad flag {flag}")
        found[flag[2:]] = value
    return found


def main(argv):
    if not argv or argv[0] not in ("report", "check", "past"):
        print("usage: allowance.py report|check|past --db <file> --hold <percent> --limits <table> [--now <epoch>] "
              "[--starts <5h>,<7d>,<30d>] [--model <id>]", file=sys.stderr)
        return UNREADABLE
    try:
        flags = options(argv[1:])
        missing = [name for name in ("db", "hold", "limits") if name not in flags]
        if missing:
            raise Unreadable(f"missing --{missing[0]}")
        try:
            hold = float(flags["hold"])
            now = float(flags.get("now", time.time()))
        except ValueError as error:
            raise Unreadable(f"--hold and --now take numbers (WS_ALLOWANCE_HOLD): {error}") from error
        limits = parse_limits(flags["limits"])
        starts = parse_starts(flags.get("starts", ""))
        if argv[0] == "report":
            if not os.path.exists(flags["db"]):
                raise Unreadable(f"no OpenCode database at {flags['db']} (WS_ALLOWANCE_DB)")
            report(flags["db"], limits, hold, now, starts)
            return 0
        if argv[0] == "check":
            if "model" not in flags:
                raise Unreadable("check needs --model")
            return check(flags["db"], limits, hold, now, flags["model"], starts)
        return past(flags["db"], limits, hold, now, starts)
    except Unreadable as error:
        print(f"allowance meter failed: {error}")
        return UNREADABLE


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
