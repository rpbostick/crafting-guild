#!/usr/bin/env python3
"""Automation audit: what builders and the orchestrator keep doing by hand, read from the run logs.

Usage: audit.py <slug> <project_path> <test_cmd> <runs_dir> <plans_dir> [days]
Prints the findings, most repeated first, and writes <runs_dir>/audit.last (cold-start reminds when it is old).
Each finding is something a script could do instead: turn the top one into the next tool fix or light task.
"""
import collections, glob, json, os, re, subprocess, sys, time

slug, path, test_cmd, runs_dir, plans_dir = sys.argv[1:6]
days = int(sys.argv[6]) if len(sys.argv) > 6 else 30
since = time.time() - days * 86400

PROBE = re.compile(r"^(node|python3?|\S*/python3?)\s+-[ce]\b|^(npx )?tsx -e\b|^(node|python3?|(npx )?tsx)\s+\S*(/tmp/|\.ws-evidence/)")
WRAPPER = re.compile(r"(run_logged|run\.js|run_check|grid\.js|scripts/evidence/)")
TEST = re.compile(r"^(npx )?(jest|vitest)|^npm (run )?test|pytest|-m unittest|^node --test")
SCRIPT = re.compile(r"^(npx )?tsx\s+((scripts|spike)/\S+)|^(node|python3?|\S*/python3?)\s+((scripts|spike)/\S+)")

runs = [f for f in glob.glob(os.path.join(runs_dir, "*.jsonl")) if os.path.getmtime(f) >= since]
cat = collections.Counter(); per_script = collections.defaultdict(set); probes_per_run = {}
wrappers = collections.Counter(); wsrun_runs = 0; denied = collections.Counter(); minutes = 0.0
for f in runs:
    name = os.path.basename(f)[:-6]; probes = 0; used_wsrun = False
    for line in open(f, errors="replace"):
        try: e = json.loads(line)
        except ValueError: continue
        if e.get("type") == "result":
            minutes += (e.get("duration_ms") or 0) / 60000
            for d in e.get("permission_denials") or []:
                denied[((d.get("tool_input") or {}).get("command") or d.get("tool_name") or "?").split()[0][:30]] += 1
        if e.get("type") != "assistant": continue
        for c in e["message"].get("content", []):
            if c.get("type") != "tool_use" or c.get("name") != "Bash": continue
            cmd = (c["input"].get("command") or "").strip()
            if "/bin/ws-run " in cmd: used_wsrun = True; cmd = cmd.split(None, 2)[2] if len(cmd.split(None, 2)) > 2 else cmd
            if TEST.search(cmd): cat["test runs"] += 1
            elif WRAPPER.search(cmd): cat["hand-written evidence wrappers"] += 1; wrappers[name] += 1
            elif PROBE.search(cmd): cat["one-off probe scripts"] += 1; probes += 1
            elif m := SCRIPT.search(cmd): cat["committed scripts run by hand"] += 1; per_script[m.group(2) or m.group(5)].add(name)
            elif cmd.startswith("git "): cat["git"] += 1
            else: cat["other"] += 1
    probes_per_run[name] = probes; wsrun_runs += used_wsrun

def tracked(*pats):
    out = subprocess.run(["git", "-C", path, "ls-files", *pats], capture_output=True, text=True).stdout.split()
    return out

# Check scripts in the repo that nothing in the test command's reach runs. A test that names the script
# (a require, or a path it spawns) counts as running it, the same rule precheck.sh uses.
gate_text = test_cmd
named = [w for w in test_cmd.split() if os.path.isfile(os.path.join(path, w))]  # e.g. bash scripts/selftest.sh
for p in tracked("package.json", "scripts/run-all-tests.sh", "jest.config.*", "pytest.ini", *named):
    try: gate_text += open(os.path.join(path, p), errors="replace").read()
    except OSError: pass
tests_text = ""
for p in tracked("test/*", "tests/*", "*/tests/*", "*.test.*"):
    try: tests_text += open(os.path.join(path, p), errors="replace").read()
    except (OSError, IsADirectoryError): pass
unrun = [p for p in tracked("scripts/*", "*/scripts/*")
         if re.search(r"(check|e2e|verify|validate)[^/]*\.(js|ts|py|sh)$", p, re.I)
         and os.path.basename(p) not in gate_text
         and os.path.splitext(os.path.basename(p))[0] not in tests_text]

repeated = sorted(((len(v), k) for k, v in per_script.items() if len(v) >= 3), reverse=True)
fix_tasks = [p for p in glob.glob(os.path.join(plans_dir, "*fix*.md")) if os.path.getmtime(p) >= since]
total = sum(cat.values()) or 1

print(f"automation audit: {slug}, last {days} days, {len(runs)} builder runs, {minutes:.0f} builder minutes")
print("builder Bash calls: " + ", ".join(f"{k} {v} ({100*v//total}%)" for k, v in cat.most_common()))
print(f"runs using ws-run: {wsrun_runs} of {len(runs)}")
print("\nfindings (each is work a script could do):")
n = 0
def finding(text):
    global n; n += 1; print(f"{n}. {text}")
if unrun:
    finding(f"{len(unrun)} check scripts that the test command never runs, so they are re-run by hand or not at all: "
            + ", ".join(unrun[:8]) + (" ..." if len(unrun) > 8 else "") + ". Put them in the suite or delete them.")
if wrappers:
    finding(f"{sum(wrappers.values())} calls to hand-written evidence wrappers in {len(wrappers)} runs "
            f"({', '.join(k for k, _ in wrappers.most_common(4))}). ws-run replaces them.")
for count, script in repeated[:5]:
    finding(f"{script} was run by hand in {count} runs. If it renders or measures something a person approved, pin its output in a test.")
heavy = sorted(((v, k) for k, v in probes_per_run.items() if v >= 15), reverse=True)
if heavy:
    finding(f"{sum(v for v, _ in heavy)} one-off probes in {len(heavy)} runs ({', '.join(f'{k} {v}' for v, k in heavy[:4])}). "
            "Read those runs: a probe repeated across a run is a missing test helper or debug script.")
if denied:
    finding("denied commands (each one cost a turn): " + ", ".join(f"{k} x{v}" for k, v in denied.most_common(5)) + ". Grant them or name the right command in the task.")
if len(fix_tasks) >= 3:
    finding(f"{len(fix_tasks)} fix-round task files. Read their findings for a class of defect a precheck rule or a test helper could catch.")
if n == 0: print("nothing repeated enough to flag")
open(os.path.join(runs_dir, "audit.last"), "w").write(time.strftime("%Y-%m-%d") + "\n")
