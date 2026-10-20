#!/usr/bin/env python3
"""Tables and measures for `ws bench` (scripts/bench.sh runs the replays; this records and reports them).

  bench.py metrics <run.jsonl>
  bench.py corpus-add <corpus.tsv> <name> <base> <budget> <track> <flags> <first-run.jsonl or "">
  bench.py runs-get <runs.tsv> <task> <arm> <trial>          prints "<run>\t<state>" when the row exists
  bench.py runs-start <runs.tsv> <run> <task> <arm> <trial> <base>
  bench.py runs-finish <runs.tsv> <run> <tests> <result.txt> <review.json> <run.jsonl> <task.md>
  bench.py report [--baseline ARM] <slug>=<runs.tsv>...

Writes take an exclusive lock on <file>.lock: parallel replays record into one runs.tsv at once.
"""
import fcntl, json, os, re, sys
from contextlib import contextmanager
from transcript import run_metrics

CORPUS_COLS = ["name", "base", "budget", "track", "cost", "turns", "peak_context", "flags"]
RUNS_COLS = ["run", "task", "arm", "trial", "base", "state", "tests", "dw_met", "dw_total", "verdict", "blocking",
             "turns", "peak_context", "mean_context", "output_tokens", "cache_reads", "cost", "minutes", "denied"]
METRIC_KEYS = ["turns", "peak_context", "mean_context", "output_tokens", "cache_reads", "cost", "minutes", "denied"]
SMALL_N = 30


@contextmanager
def locked(path):
    with open(path + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def read_tsv(path, cols):
    if not os.path.exists(path):
        return []
    with open(path) as fh:
        lines = fh.read().splitlines()
    if not lines:
        return []
    header = lines[0].split("\t")
    if header != cols:
        sys.exit(f"bench: {path} has columns {header}, expected {cols}")
    return [dict(zip(cols, line.split("\t") + [""] * (len(cols) - len(line.split("\t"))))) for line in lines[1:] if line]


def write_tsv(path, cols, rows):
    tmp = path + ".tmp"
    with open(tmp, "w") as fh:
        fh.write("\t".join(cols) + "\n")
        for row in rows:
            fh.write("\t".join(str(row.get(c, "")).replace("\t", " ").replace("\n", " ") for c in cols) + "\n")
    os.replace(tmp, path)


def metrics_line(path):
    m = run_metrics(path)
    return " ".join(f"{k}={m[k]}" for k in METRIC_KEYS)


def corpus_add(path, name, base, budget, track, flags, jsonl):
    original = run_metrics(jsonl) if jsonl else {}
    row = {"name": name, "base": base, "budget": budget, "track": track, "flags": flags,
           "cost": original.get("cost", ""), "turns": original.get("turns", ""), "peak_context": original.get("peak_context", "")}
    with locked(path):
        rows = [r for r in read_tsv(path, CORPUS_COLS) if r["name"] != name] + [row]
        write_tsv(path, CORPUS_COLS, rows)


def runs_get(path, task, arm, trial):
    for r in read_tsv(path, RUNS_COLS):
        if (r["task"], r["arm"], r["trial"]) == (task, arm, trial):
            print(f"{r['run']}\t{r['state']}")
            return


def runs_start(path, run, task, arm, trial, base):
    with locked(path):
        rows = read_tsv(path, RUNS_COLS)
        if any((r["task"], r["arm"], r["trial"]) == (task, arm, trial) for r in rows):
            sys.exit(f"bench: {task} / {arm} / trial {trial} already has a row in {path}")
        rows.append({"run": run, "task": task, "arm": arm, "trial": trial, "base": base, "state": "started"})
        write_tsv(path, RUNS_COLS, rows)


def done_when_items(task_md):
    """How many items the task's done-when lists (bullets or numbered); a section of prose counts as one."""
    section, on = [], False
    for line in open(task_md, errors="replace"):
        if re.match(r"#+ *done when", line, re.I):
            on = True
            continue
        if on and line.startswith("#"):
            break
        if on:
            section.append(line)
    items = sum(1 for line in section if re.match(r"\s*([-*]|\d+\.)\s", line))
    return items or (1 if any(line.strip() for line in section) else 0)


def done_when_from_check(result_txt):
    """Met and reported items from check-result's lines: a "met" whose evidence is missing (FAIL) is not met."""
    met = reported = 0
    if os.path.exists(result_txt):
        for line in open(result_txt, errors="replace"):
            m = re.match(r"(ok|note|FAIL) +done-when (met|partial|open) ", line)
            if m:
                reported += 1
                met += m.group(1) != "FAIL" and m.group(2) == "met"
    return met, reported


def runs_finish(path, run, tests, result_txt, review_json, jsonl, task_md):
    met, reported = done_when_from_check(result_txt)
    verdict, blocking = "none", ""
    if os.path.exists(review_json):
        review = json.load(open(review_json))
        verdict, blocking = review.get("verdict") or "none", len(review.get("blocking") or [])
    measures = run_metrics(jsonl) if os.path.exists(jsonl) else {k: "" for k in METRIC_KEYS}
    with locked(path):
        rows = read_tsv(path, RUNS_COLS)
        mine = [r for r in rows if r["run"] == run]
        if not mine:
            sys.exit(f"bench: no row for run {run} in {path}")
        mine[0].update({"state": "done", "tests": tests, "dw_met": met, "dw_total": max(reported, done_when_items(task_md)),
                        "verdict": verdict, "blocking": blocking, **measures})
        write_tsv(path, RUNS_COLS, rows)


# --- report ---------------------------------------------------------------------------------------------------

def number(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def mean(values):
    values = [v for v in values if v is not None]
    return sum(values) / len(values) if values else None


def per_run_quality(row):
    met, total = number(row["dw_met"]), number(row["dw_total"])
    return {"tests passed": 1.0 if row["tests"] == "pass" else 0.0,
            "done-when met": met / total if total else None,
            "merge verdicts": 1.0 if row["verdict"] == "merge" else 0.0}


def arm_rate(rows, measure):
    if measure == "done-when met":
        total = sum(number(r["dw_total"]) or 0 for r in rows)
        return sum(number(r["dw_met"]) or 0 for r in rows) / total if total else None
    return mean(per_run_quality(r)[measure] for r in rows)


def trial_spread(rows, measure):
    """Mean over tasks of the range between one arm's trials of a task: how much a rate moves by chance alone."""
    by_task = {}
    for r in rows:
        value = per_run_quality(r)[measure]
        if value is not None:
            by_task.setdefault(r["task"], []).append(value)
    ranges = [max(v) - min(v) for v in by_task.values() if len(v) > 1]
    return sum(ranges) / len(ranges) if ranges else 0.0


def fmt(value, kind=""):
    if value is None:
        return "-"
    if kind == "%":
        return f"{100 * value:.0f}%"
    if kind == "$":
        return f"{value:.2f}"
    return f"{value:.1f}" if abs(value) < 100 else f"{value:.0f}"


def spread_text(values):
    values = [v for v in values if v is not None]
    if not values:
        return "-"
    return f"{fmt(mean(values))} [{fmt(min(values))}-{fmt(max(values))}]"


def report(title, rows, baseline):
    done = [r for r in rows if r["state"] == "done"]
    unfinished = len(rows) - len(done)
    arms = list(dict.fromkeys(r["arm"] for r in done))
    print(f"== {title} ({len(done)} runs{f', {unfinished} not finished and left out' if unfinished else ''})")
    if not arms:
        print("no finished runs")
        return
    base = baseline or arms[0]
    by_arm = {a: [r for r in done if r["arm"] == a] for a in arms}
    tasks = list(dict.fromkeys(r["task"] for r in done))
    n = min(len(v) for v in by_arm.values())
    trials = max(len([r for r in by_arm[a] if r["task"] == t]) for a in arms for t in tasks)
    print(f"baseline arm: {base}" + ("" if base in by_arm else " (no runs here; nothing to compare)"))
    print(f"n = {n} runs per arm ({len(tasks)} tasks, up to {trials} trials each)"
          + (": n is small, so a gap within the trial spread is noise, and one beyond it is a reason to look, not proof"
             if n < SMALL_N else ""))
    width = max(12, *(len(a) + 2 for a in arms))
    head = lambda label: print(f"  {label:<16}" + "".join(f"{a:>{width}}" for a in arms))
    line = lambda label, values: print(f"  {label:<16}" + "".join(f"{v:>{width}}" for v in values))
    print("quality")
    head("")
    for measure in ("tests passed", "done-when met", "merge verdicts"):
        line(measure, [fmt(arm_rate(by_arm[a], measure), "%") for a in arms])
    line("blocking/run", [fmt(mean(number(r["blocking"]) for r in by_arm[a])) for a in arms])
    print("cost (mean per run)")
    for key, label, kind in (("turns", "turns", ""), ("peak_context", "peak context", ""), ("mean_context", "mean context", ""),
                             ("output_tokens", "output tokens", ""), ("cache_reads", "cache reads", ""),
                             ("cost", "cost $", "$"), ("minutes", "minutes", ""), ("denied", "denied calls", "")):
        line(label, [fmt(mean(number(r[key]) for r in by_arm[a]), kind) for a in arms])
    if base in by_arm:
        for arm in arms:
            if arm == base:
                continue
            for measure in ("tests passed", "done-when met", "merge verdicts"):
                ours, theirs = arm_rate(by_arm[arm], measure), arm_rate(by_arm[base], measure)
                if ours is None or theirs is None:
                    continue
                spread = max(trial_spread(by_arm[arm], measure), trial_spread(by_arm[base], measure))
                if theirs - ours > spread + 1e-9:
                    print(f"quality drop: {arm} vs {base}: {measure} {fmt(ours, '%')} against {fmt(theirs, '%')} "
                          f"(lower by {100 * (theirs - ours):.0f} points; trial spread {100 * spread:.0f} points)")
        if trials < 2:
            print("one trial per task: the trial spread is unknown, so any gap is reported")
    print("per task (cost: mean [min-max] over trials)")
    for task in tasks:
        print(f"  {task}")
        for arm in arms:
            mine = [r for r in by_arm[arm] if r["task"] == task]
            if not mine:
                continue
            passed = sum(r["tests"] == "pass" for r in mine)
            met = sum(int(number(r["dw_met"]) or 0) for r in mine)
            total = sum(int(number(r["dw_total"]) or 0) for r in mine)
            merges = sum(r["verdict"] == "merge" for r in mine)
            blocking = mean(number(r["blocking"]) for r in mine)
            print(f"    {arm}: tests {passed}/{len(mine)}  done-when {met}/{total}  merge {merges}/{len(mine)}  "
                  f"blocking {fmt(blocking)}  cost $ {spread_text([number(r['cost']) for r in mine])}  "
                  f"turns {spread_text([number(r['turns']) for r in mine])}  "
                  f"peak context {spread_text([number(r['peak_context']) for r in mine])}  "
                  f"minutes {spread_text([number(r['minutes']) for r in mine])}")


def report_all(args):
    baseline = None
    if args[:1] == ["--baseline"]:
        baseline, args = args[1], args[2:]
    if not args:
        sys.exit("usage: bench.py report [--baseline ARM] <slug>=<runs.tsv>...")
    pooled = []
    for arg in args:
        slug, path = arg.split("=", 1)
        rows = read_tsv(path, RUNS_COLS)
        report(slug, rows, baseline)
        pooled += [dict(r, task=f"{slug}/{r['task']}") for r in rows]
        print()
    if len(args) > 1:
        report("total", pooled, baseline)


def main(argv):
    if not argv:
        sys.exit(__doc__)
    command, args = argv[0], argv[1:]
    if command == "metrics" and len(args) == 1:
        print(metrics_line(args[0]))
    elif command == "corpus-add" and len(args) == 7:
        corpus_add(*args)
    elif command == "runs-get" and len(args) == 4:
        runs_get(*args)
    elif command == "runs-start" and len(args) == 6:
        runs_start(*args)
    elif command == "runs-finish" and len(args) == 7:
        runs_finish(*args)
    elif command == "report":
        report_all(args)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
