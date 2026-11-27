#!/usr/bin/env python3
"""OpenCode Go spend against one shared, weighted pool, from OpenCode's local database (opened read-only).

report                 one line per window: the summed percentage, each model's spend and its part, and the
                       total the hold uses
check --model <id>     exit 0 under the hold, 3 past it (the reason on stdout), 4 unmeasured (why on stdout)
past                   one line naming every window past the hold; nothing when none is

Every command takes --db <file> --hold <percent> --limits "<model=5h,7d,30d> ..."
[--prices "<model=in,out,cache read,cache write,reasoning> ..."] [--now <epoch seconds>]
[--starts "<5h-epoch>,<7d-epoch>,<30d-epoch>"].

The pool is shared and weighted: a window's percentage is the sum of each model's spend divided by that
model's limit, so a model alone reaches 100% at its own limit. Every number is an estimate. Go counts each
request in the response's `opencode.allowance`, which reaches neither the event stream nor this database, so
the meter sums the `cost` OpenCode stores on each assistant message, and prices the token classes itself
(WS_ALLOWANCE_PRICES, dollars per 1M tokens) for the rows the client stores with cost 0. A row with
neither a stored cost nor priced token classes is unmeasured, never 0; measuredness is decided per window, so a
model whose rows in a window are all unpriced is shown there as unmeasured and left out of that window's sum,
and a window holding both counted and unpriced rows says how many it could not count. With WS_ALLOWANCE_STARTS unset
the windows are rolling and the output says so; when set, each window counts from the Console's start, and a
window whose time has passed starts at the first request after it. Only this machine's sessions count.

Deliberate: Python's sqlite3 module, not the sqlite3 command, which a machine with OpenCode need not have.
"""
import os
import sqlite3
import sys
import time
from collections import namedtuple

PROVIDER = "opencode-go"
HOUR = 3600
WINDOWS = (("5h", 5 * HOUR), ("7d", 7 * 24 * HOUR), ("30d", 30 * 24 * HOUR))
LONGEST = WINDOWS[-1][1]
PAST, UNMEASURED, UNREADABLE = 3, 4, 2
# The classes a stored cost covers, in the order a WS_ALLOWANCE_PRICES row lists them: cache write is separate from
# cache read, and a model that charges for it (gpt-5.6-luna) would be underpriced without its own field.
PRICE_FIELDS = ("input", "output", "cache_read", "cache_write", "reasoning")
TOKEN_UNITS = 1_000_000
NO_PRICE = "stored cost is 0 and no price in WS_ALLOWANCE_PRICES"
NO_TOKENS = "stored cost is 0 and the row has no token classes"
Part = namedtuple("Part", "model spent limit percent measured unpriced")


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


def parse_prices(text):
    """{model: {"input": .., "output": .., "cache_read": .., "cache_write": .., "reasoning": ..}} per 1M tokens."""
    prices = {}
    for entry in text.split():
        model, _, figures = entry.partition("=")
        try:
            values = [float(part) for part in figures.split(",")]
        except ValueError:
            values = []
        if not model or len(values) != len(PRICE_FIELDS) or min(values) < 0:
            raise Unreadable(f"price '{entry}' is not <model>=<input>,<output>,<cache read>,<cache write>,<reasoning> "
                             "in dollars per 1M tokens (WS_ALLOWANCE_PRICES)")
        prices[model] = dict(zip(PRICE_FIELDS, values))
    return prices


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


def session_table_present(database):
    """Whether the 2.x table exists: an existing table with no Go row is zero spend, not an unreadable store."""
    return database.execute(
        "select 1 from sqlite_master where type = 'table' and name = 'session_message'").fetchone() is not None


def legacy_table_present(database):
    return database.execute(
        "select 1 from sqlite_master where type = 'table' and name = 'message'").fetchone() is not None


def priced(model, cost, tokens, prices):
    """(dollars, None) where the row is measured, else (None, why it is not)."""
    if cost and cost > 0:
        return cost, None
    if model not in prices:
        return None, NO_PRICE
    if all(count is None for count in tokens):
        return None, NO_TOKENS
    return sum((count or 0) * prices[model][field] for field, count in zip(PRICE_FIELDS, tokens)) / TOKEN_UNITS, None


def spend_rows(path, now, since, prices):
    """({model: [(epoch seconds, dollars), ...]} oldest first, {model: [(epoch seconds, why), ...]} oldest first).

    The second table holds the rows the meter could not price, with their times, so a window can decide whether
    this model is unmeasured here rather than over the whole read. Spans <since> to now.

    Reads session_message (2.x) whenever the table exists — an empty table is zero spend — and the legacy message
    table only when it does not. A database with both is read from session_message alone: the same spend must never
    be counted twice. The legacy table selects cost > 0 and carries no token classes, so its rows are never priced.
    """
    start, ceiling = int(since * 1000), int(now * 1000)
    try:
        database = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=5)
        if session_table_present(database):
            rows = database.execute(
                "select json_extract(data, '$.model.id'), time_created, json_extract(data, '$.cost'), "
                "json_extract(data, '$.tokens.input'), json_extract(data, '$.tokens.output'), "
                "json_extract(data, '$.tokens.cache.read'), json_extract(data, '$.tokens.cache.write'), "
                "json_extract(data, '$.tokens.reasoning') "
                "from session_message where time_created >= ? and time_created <= ? "
                "and json_extract(data, '$.model.providerID') = ? order by time_created",
                (start, ceiling, PROVIDER)).fetchall()
        elif legacy_table_present(database):
            rows = [(model, created, cost, None, None, None, None, None) for model, created, cost in database.execute(
                "select json_extract(data, '$.modelID'), time_created, json_extract(data, '$.cost') from message "
                "where time_created >= ? and json_extract(data, '$.providerID') = ? "
                "and json_extract(data, '$.cost') > 0 order by time_created",
                (start, PROVIDER)).fetchall()]
        else:
            raise Unreadable(f"cannot read {path}: neither a session_message nor a message table (WS_ALLOWANCE_DB)")
    except sqlite3.Error as error:
        raise Unreadable(f"cannot read {path}: {error}") from error
    spend, unmeasured = {}, {}
    for model, created, cost, tokens_in, tokens_out, cache_read, cache_write, reasoning in rows:
        name = f"{PROVIDER}/{model}"
        dollars, why = priced(name, cost, (tokens_in, tokens_out, cache_read, cache_write, reasoning), prices)
        if dollars is None:
            unmeasured.setdefault(name, []).append((created / 1000, why))
            continue
        spend.setdefault(name, []).append((created / 1000, dollars))
    return spend, unmeasured


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


def window_rows(rows, now, span, start):
    """The rows inside one window: a rolling span, or the Console's start."""
    if start is None:
        return [(when, value) for when, value in rows if now - span < when <= now]
    return [(when, value) for when, value in rows if start <= when <= now]


def unmeasured_reason(rows):
    """The distinct reasons this model's rows went unpriced, in the order they were read."""
    reasons = []
    for _, why in rows:
        if why not in reasons:
            reasons.append(why)
    return "; ".join(reasons)


def window_parts(spend, unmeasured, limits, name, span, start, now):
    """One Part per model; percent is None for a model with no limit and for one whose rows in this window are all
    unpriced.

    Measuredness is decided per window: unpriced rows carry their times, so a model whose rows here are all unpriced
    takes an unmeasured cell even when another window holds priced rows, and a window holding both keeps the priced
    dollars in the sum, counts its unpriced rows and says so. A model in the limits table with no row at all still
    takes a cell, so it is shown as measured at $0.00 rather than left out of the report.
    """
    parts = []
    for model in sorted(set(limits) | set(spend) | (set(unmeasured) & set(limits))):
        priced = window_rows(spend.get(model, []), now, span, start)
        unpriced = window_rows(unmeasured.get(model, []), now, span, start)
        spent = sum(cost for _, cost in priced)
        measured = bool(priced) or not unpriced
        limit = limits[model][name] if model in limits else None
        percent = spent / limit * 100 if measured and limit is not None else None
        parts.append(Part(model, spent, limit, percent, measured, len(unpriced)))
    return parts


def pooled_percent(parts):
    return sum(part.percent for part in parts if part.percent is not None)


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


def over_hold(spend, unmeasured, limits, hold, now, starts):
    """(window, pooled percent, parts, clears) for each window at or past the hold."""
    found = []
    for name, span, start in window_bounds(starts, all_rows(spend), now):
        parts = window_parts(spend, unmeasured, limits, name, span, start, now)
        percent = pooled_percent(parts)
        if percent >= hold:
            found.append((name, percent, parts, clears_at(spend, limits, name, span, start, now, hold)))
    return found


def cell(part):
    """One model's column in a window: its spend and part, or why it is not in the sum."""
    if not part.measured:
        return f"{part.model} unmeasured (not counted)"
    if part.unpriced:
        note = f" + {part.unpriced} unpriced (partly not counted)"
        if part.limit is None:
            return f"{part.model} ~${part.spent:.2f}{note}"
        return f"{part.model} ~${part.spent:.2f}/${part.limit:g} {part.percent:.1f}%{note}"
    if part.limit is None:
        return f"{part.model} ~${part.spent:.2f} (no limit, not counted)"
    return f"{part.model} ~${part.spent:.2f}/${part.limit:g} {part.percent:.1f}%"


def describe(window):
    name, percent, parts, _ = window
    return f"{name} summed ~{percent:.1f}% (" + ", ".join(cell(part) for part in parts) + ")"


def reason(found, hold):
    text = "; ".join(describe(window) for window in found)
    clear = time.strftime("%Y-%m-%d %H:%M", time.localtime(max(window[3] for window in found)))
    return f"{PROVIDER} pool is past the {hold:g}% allowance hold: {text}, estimated; clears about {clear}"


def report(path, limits, prices, hold, now, starts):
    spend, unmeasured = spend_rows(path, now, min([now - LONGEST] + (starts or [])), prices)
    rows = all_rows(spend)
    print("OpenCode Go spend, one shared, weighted pool. Every number is an estimate (~), from OpenCode's stored "
          "cost, or WS_ALLOWANCE_PRICES where it stores none:")
    if starts is None:
        print("opencode.allowance is not in the local record; windows are taken as rolling, this machine only.")
    else:
        print("opencode.allowance is not in the local record; window starts are taken from WS_ALLOWANCE_STARTS, this machine only.")
    for model in sorted(unmeasured):
        scope = "some rows not measured" if model in spend else "not measured"
        print(f"{model}  {scope}: {unmeasured_reason(unmeasured[model])}")
    for name, span, start in window_bounds(starts, rows, now):
        label = f"{name} rolling" if start is None else f"{name} from {time.strftime('%Y-%m-%d %H:%M', time.localtime(start))}"
        parts = window_parts(spend, unmeasured, limits, name, span, start, now)
        if not any(part.limit is not None for part in parts):
            print(f"{label}  not measured: no model has a limit in WS_ALLOWANCE_LIMITS")
            continue
        percent = pooled_percent(parts)
        cells = ", ".join(cell(part) for part in parts)
        flag = "  PAST HOLD" if percent >= hold else ""
        print(f"{label}  summed ~{percent:.1f}% (the hold uses this): {cells}{flag}")
    print(f"Hold: {hold:g}% of the summed window total (WS_ALLOWANCE_HOLD). Held: ws bench run, ws review-compare, shadow reviews.")
    print("The Console shows the real remainder; a model that stopped below its limit here means the limits need lowering.")


def check(path, limits, prices, hold, now, model, starts):
    if not model.startswith(f"{PROVIDER}/"):
        return 0
    if not os.path.exists(path):
        print(f"no OpenCode database at {path}, so the allowance is not measured")
        return UNMEASURED
    spend, unmeasured = spend_rows(path, now, min([now - LONGEST] + (starts or [])), prices)
    found = over_hold(spend, unmeasured, limits, hold, now, starts)
    if found:
        print(reason(found, hold))
        return PAST
    if model in unmeasured:
        print(f"{model}: {unmeasured_reason(unmeasured[model])}, so its allowance is not measured")
        return UNMEASURED
    if model not in limits:
        print(f"{model} has no limit in WS_ALLOWANCE_LIMITS, so its allowance is not measured")
        return UNMEASURED
    return 0


def past(path, limits, prices, hold, now, starts):
    # Deliberate: no database is a machine that has never run OpenCode, not a fault to print at every cold start.
    if not os.path.exists(path):
        return 0
    spend, unmeasured = spend_rows(path, now, min([now - LONGEST] + (starts or [])), prices)
    found = over_hold(spend, unmeasured, limits, hold, now, starts)
    if found:
        print(reason(found, hold))
    return 0


def options(words):
    """The flags as a dict; an unknown or valueless flag is an error, so a typed --hold is never ignored."""
    found = {}
    for flag, value in zip(words[::2], words[1::2] + [None]):
        if flag not in ("--db", "--hold", "--limits", "--prices", "--now", "--model", "--starts") or value is None:
            raise Unreadable(f"bad flag {flag}")
        found[flag[2:]] = value
    return found


def main(argv):
    if not argv or argv[0] not in ("report", "check", "past"):
        print("usage: allowance.py report|check|past --db <file> --hold <percent> --limits <table> "
              "[--prices <table>] [--now <epoch>] [--starts <5h>,<7d>,<30d>] [--model <id>]", file=sys.stderr)
        return UNREADABLE
    try:
        flags = options(argv[1:])
        # Prices are optional: without the table every cost-0 row is unmeasured, never a silent $0.
        missing = [name for name in ("db", "hold", "limits") if name not in flags]
        if missing:
            raise Unreadable(f"missing --{missing[0]}")
        try:
            hold = float(flags["hold"])
            now = float(flags.get("now", time.time()))
        except ValueError as error:
            raise Unreadable(f"--hold and --now take numbers (WS_ALLOWANCE_HOLD): {error}") from error
        limits = parse_limits(flags["limits"])
        prices = parse_prices(flags.get("prices", ""))
        starts = parse_starts(flags.get("starts", ""))
        if argv[0] == "report":
            if not os.path.exists(flags["db"]):
                raise Unreadable(f"no OpenCode database at {flags['db']} (WS_ALLOWANCE_DB)")
            report(flags["db"], limits, prices, hold, now, starts)
            return 0
        if argv[0] == "check":
            if "model" not in flags:
                raise Unreadable("check needs --model")
            return check(flags["db"], limits, prices, hold, now, flags["model"], starts)
        return past(flags["db"], limits, prices, hold, now, starts)
    except Unreadable as error:
        print(f"allowance meter failed: {error}")
        return UNREADABLE


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
