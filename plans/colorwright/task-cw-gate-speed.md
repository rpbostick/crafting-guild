# colorwright: bring the merge gate back under 5 minutes

Track: light

`scripts/run-all-tests.sh` now runs the browser checks through `scripts/run-e2e.sh`, one browser at a time, and the whole gate takes 554 s (the last merge's log: the workspace's `runs/colorwright/cw-e2e-gate.merge-tests.log` is not in this repo; run it yourself to get the per-suite times). Every merge pays this. Get it under 300 s without dropping coverage.

Read first: `scripts/run-e2e.sh`, `scripts/run-all-tests.sh`, `scripts/e2e/README.md` (per-check times), `scripts/e2e-app.js` (how a check starts the backend and its ports).

## Build
1. **Run the browser checks in parallel**: a fixed pool (start with 3; measure 2, 3 and 4 and keep the fastest that stays reliable), each check on its own ports and its own temporary database, as they already are. Output stays one PASS/FAIL line per check in a stable order, and the exit code is non-zero if any failed.
2. **Run the e2e pool alongside the unit suites** if that is faster, with each suite's output kept separate in the log and each suite's exit line kept.
3. If still over 300 s, the slowest checks (per the README) share a backend start or reuse a loaded page instead of reloading; say what was changed in each.

## Tests
- A deliberately failing temporary check still fails the run and is named; save that run, then delete the file with `git rm` if it was committed, or leave it uncommitted and say so.
- Three full runs of `bash scripts/run-all-tests.sh` through the evidence runner, all passing, with their times, so flakiness from parallelism would show.

## Commands
One command per Bash call, each through the evidence runner: `bash scripts/run-e2e.sh`, `bash scripts/run-all-tests.sh`, `node scripts/<check>.js`, `node --test <files>`. Do not install anything.

## Done when
The gate runs under 300 s on this machine in three consecutive passing runs, with every kept check still run.
