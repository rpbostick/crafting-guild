#!/usr/bin/env python3
"""Counts the deciding review's blocking findings that another review names, under the nearby-text rule.

Usage: review_match.py count <claude-json> <review-file>
       review_match.py report <runs-dir> <workspace>
       review_match.py union <pass-review> <cost> [<pass-review> <cost>...]

Named means the same file and either a line within EXACT (the rule review-shadow.tsv was written under) or a line
within WINDOW and the same fault by word match. The first arm keeps the older count as a floor. Word matching adds no
model call, so a finding reworded past the threshold stays unnamed: the count is a lower bound.

`report` recomputes review-shadow.tsv from the kept records and never writes. Its first line is nine numbers: named,
rows recomputed, rows, named at windows 5, 10, 20 and 40, rows changed, records damaged. One `changed <name> <sha>
written <n>: <reason>` or `damaged <path>: <reason>` line follows for each of the last two.
Claude's findings come from a review on record at the row's SHA, or from the automatic fix task the chain log names.
A row keeps its written count when its records are gone or damaged, and when they changed after it was written: a fix
task a later round rewrote, or a recount that differs at EXACT, where the nearby rule and the written rule are the same
rule. So a difference from the written total is the counting rule's and never a drop.
"""
import csv, glob, json, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
words = __import__("lessons-check").words

EXACT = 5
# Deliberate: wide enough for two cases checked by hand, a blocker 8 lines off and one 17 lines off.
WINDOW = 20
SWEEP = (5, 10, 20, 40)
SAME_FAULT = 0.25  # share of the shorter finding's meaningful words that the other holds
MIN_SHARED = 2     # one shared word in a short finding is chance
REWRITTEN = object()
STOP = set("that this with from have when which into than then they them were been does each only also must "
           "should would could there their while where what about after before because still same line file "
           "says said uses used".split())


def meaningful(text):
    return {word for word in words(text or "") if len(word) >= 4 and word not in STOP}


def same_fault(first_why, second_why):
    left, right = meaningful(first_why), meaningful(second_why)
    if not left or not right:
        return False
    shared = len(left & right)
    return shared >= MIN_SHARED and shared / min(len(left), len(right)) >= SAME_FAULT


def named(finding, other, window):
    if finding.get("file") != other.get("file"):
        return False
    distance = abs(finding["line"] - other["line"])
    return distance <= EXACT or (distance <= window and same_fault(finding.get("why"), other.get("why")))


def count(claude, blocking, window=WINDOW):
    return sum(1 for finding in claude if any(named(finding, other, window) for other in blocking))


STRICTNESS = ("merge", "fix-first", "do-not-merge")


def duplicates(finding, others, by_fault=False):
    """Whether `finding` names a file of one of `others` with a line within EXACT, and, when by_fault, the same fault.
    Two different blocking faults three lines apart are separate work, so a later one must survive the union."""
    return any(finding.get("file") == other.get("file")
               and abs(finding["line"] - other["line"]) <= EXACT
               and (not by_fault or same_fault(finding.get("why"), other.get("why")))
               for other in others)


def dedupe(findings, by_fault=False):
    """First occurrence wins; a later finding is the same one when `duplicates` holds. Blocking findings are deduped
    by fault as well as by line: two passes word the same fault differently, and two different faults 3 lines apart
    must both reach the fix task. Suggestions keep the line rule alone."""
    kept = []
    for finding in findings:
        if not duplicates(finding, kept, by_fault):
            kept.append(finding)
    return kept


def union(reviews, costs):
    """One review from several passes at the same SHA: the blocking findings and the suggestions of every pass, each
    deduped, the strictest verdict, a summary naming each pass's verdict, and the summed cost. A suggestion that
    repeats a blocking finding's fault within EXACT lines is dropped: the fix task carries the blocking entry. A
    verdict outside the schema fails loud rather than ranking as the mildest."""
    for review in reviews:
        if review.get("verdict") not in STRICTNESS:
            raise ValueError("verdict %r is not one of %s" % (review.get("verdict"), ", ".join(STRICTNESS)))
    verdict = max((review["verdict"] for review in reviews), key=STRICTNESS.index)
    summary = "%d passes (%s). " % (len(reviews), "; ".join(
        "pass %d: %s" % (number, review["verdict"]) for number, review in enumerate(reviews, 1)))
    summary += " ".join("Pass %d: %s" % (number, review.get("summary", "")) for number, review in enumerate(reviews, 1))
    blocking = dedupe([item for review in reviews for item in review.get("blocking") or []], by_fault=True)
    suggestions = dedupe([item for review in reviews for item in review.get("suggestions") or []])
    return {
        "verdict": verdict,
        "summary": summary,
        "blocking": blocking,
        "suggestions": [item for item in suggestions if not duplicates(item, blocking, by_fault=True)],
        "passes": len(reviews),
        "total_cost_usd": round(sum(costs), 6),
    }


def read_text(path):
    """A run file holds whatever a command printed, so a byte that is not UTF-8 must not cost the whole read."""
    with open(path, encoding="utf-8", errors="replace") as handle:
        return handle.read()


def load(path, damaged):
    """The JSON object at path, or None. A file that is there and holds no object also goes in `damaged`: a broken
    record is a fault to report, not a review that never ran."""
    try:
        record = json.loads(read_text(path))
    except FileNotFoundError:
        return None
    except (OSError, ValueError) as error:
        damaged[path] = str(error)
        return None
    if not isinstance(record, dict):
        damaged[path] = "not a JSON object"
        return None
    return record


def by_round(path):
    """The round number, or None for a file that is not a numbered round."""
    match = re.search(r"\.(\d+)\.json$", path)
    return int(match.group(1)) if match else None


def rounds(pattern):
    """Oldest first; the file at the current path is the newest."""
    return sorted((path for path in glob.glob(pattern) if by_round(path) is not None), key=by_round)


def same_sha(first, second):
    return bool(first) and bool(second) and (first.startswith(second) or second.startswith(first))


def fix_tasks(runs):
    """{(name, sha): task path}, and the keys whose task a later review rewrote, from the chain log's review line and
    the fix line after it. The chain gives every round its own file now, but a kept log can name one path twice: chain
    runs used to number from 1 each time, so the second wrote over the first's file."""
    found, last_writer, pending = {}, {}, None
    try:
        lines = read_text(os.path.join(runs, "chain.log")).splitlines()
    except OSError:
        return found, set()
    for line in lines:
        text = line.rsplit("  ", 1)[-1]
        review = re.fullmatch(r"(.+): review at ([0-9a-f]+): fix-first", text)
        fix = re.fullmatch(r"(.+): fix-first; automatic fix round \d+ \((.*)\)", text)
        if review:
            pending = review.groups()
        elif fix and pending and fix.group(1) == pending[0]:
            found[pending] = fix.group(2)
            last_writer[fix.group(2)] = pending
            pending = None
    return found, {key for key, task in found.items() if last_writer[task] != key}


def task_findings(path):
    out, on = [], False
    try:
        lines = read_text(path).splitlines()
    except OSError:
        return None
    for line in lines:
        if line.startswith("## "):
            on = line.startswith("## Blocking findings")
            continue
        bullet = re.match(r"- `(.+):(\d+)`(?: \(rule [^)]*\))?:? *(.*)", line) if on else None
        if bullet:
            out.append({"file": bullet.group(1), "line": int(bullet.group(2)), "why": bullet.group(3)})
    return out


def claude_findings(runs, workspace, name, sha, expected, tasks, rewritten, damaged):
    """The findings at this SHA, only when their number is the row's: another round's list is not this row's.
    REWRITTEN when the one place that held them now holds a later review's."""
    if expected == 0:
        return []
    paths = rounds(os.path.join(glob.escape(runs), "rounds", glob.escape(name) + ".review.*.json"))
    for path in paths + [os.path.join(runs, name + ".review.json")]:
        record = load(path, damaged)
        if record and same_sha(record.get("reviewed_sha"), sha) and len(record.get("blocking") or []) == expected:
            return record["blocking"]
    for (task_name, task_sha), task in tasks.items():
        if task_name == name and same_sha(task_sha, sha):
            if (task_name, task_sha) in rewritten:
                return REWRITTEN
            findings = task_findings(task if os.path.isabs(task) else os.path.join(workspace, task))
            if findings is not None and len(findings) == expected:
                return findings
    return None


def shadow_records(runs, name, sha):
    base = os.path.join(runs, "shadow", name + "-" + sha)
    paths = rounds(os.path.join(glob.escape(runs), "shadow", "rounds", glob.escape(name + "-" + sha) + ".*.json"))
    if os.path.exists(base + ".json"):
        paths.append(base + ".json")
    return paths


def whole(text):
    return int(text) if (text or "").isdigit() else 0


def report(runs, workspace):
    tsv = os.path.join(runs, "review-shadow.tsv")
    with open(tsv, newline="", encoding="utf-8", errors="replace") as handle:
        rows = [row for row in csv.DictReader(handle, delimiter="\t", quoting=csv.QUOTE_NONE) if row.get("name")]
    tasks, rewritten = fix_tasks(runs)
    changed, damaged = [], {}
    seen = {}
    for row in rows:
        seen.setdefault((row["name"], row["sha"]), []).append(row)
    done, windows = 0, {size: 0 for size in SWEEP}
    total = 0
    for (name, sha), group in seen.items():
        paths = shadow_records(runs, name, sha)
        # Rows and records pair from the newest back: the records a same-SHA re-review overwrote are the oldest.
        finished = [row for row in group if row.get("shadow verdict") != "error"]
        paired = dict(zip(map(id, reversed(finished)), reversed(paths)))
        for row in group:
            written = whole(row.get("claude findings named"))
            expected = whole(row.get("claude blocking"))
            claude = claude_findings(runs, workspace, name, sha, expected, tasks, rewritten, damaged)
            record = load(paired[id(row)], damaged) if id(row) in paired else None
            blocking = record.get("blocking") if record else None
            reason = None
            if claude is REWRITTEN:
                reason = "a later review rewrote the fix task that held its findings"
            elif claude is not None and blocking is not None and count(claude, blocking, EXACT) != written:
                reason = "the records now give %d at %d lines" % (count(claude, blocking, EXACT), EXACT)
            if reason:
                changed.append("changed %s %s written %d: %s" % (name, sha[:7], written, reason))
            if reason or claude is None or blocking is None:
                total += written
                for size in SWEEP:
                    windows[size] += written
                continue
            done += 1
            total += count(claude, blocking)
            for size in SWEEP:
                windows[size] += count(claude, blocking, size)
    print(total, done, len(rows), *(windows[size] for size in SWEEP), len(changed), len(damaged))
    for line in changed:
        print(line)
    for path, why in damaged.items():
        print("damaged %s: %s" % (path, why))


def main():
    if len(sys.argv) == 4 and sys.argv[1] == "count":
        record = load(sys.argv[3], {})
        if record is None:
            sys.exit("review_match.py: cannot read " + sys.argv[3])
        print(count(json.loads(sys.argv[2]), record.get("blocking") or []))
    elif len(sys.argv) == 4 and sys.argv[1] == "report":
        report(sys.argv[2], sys.argv[3])
    elif len(sys.argv) >= 4 and sys.argv[1] == "union" and len(sys.argv) % 2 == 0:
        # Pairs of <pass review file> <cost>; a missing or unreadable pass fails the union.
        pairs = list(zip(sys.argv[2::2], sys.argv[3::2]))
        reviews = []
        for path, _ in pairs:
            record = load(path, {})
            if record is None:
                sys.exit("review_match.py: cannot read " + path)
            reviews.append(record)
        try:
            merged = union(reviews, [float(cost) for _, cost in pairs])
        except ValueError as error:
            sys.exit("review_match.py: " + str(error))
        print(json.dumps(merged))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
