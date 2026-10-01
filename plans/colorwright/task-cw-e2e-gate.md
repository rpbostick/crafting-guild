# colorwright: the browser checks run in the test suite, not by hand

`scripts/` holds about 32 browser checks (`*-e2e-check.js`, plus `check_*.py` and similar) that drive the real app through `scripts/e2e-app.js` and `scripts/e2e-browser.js`. `scripts/run-all-tests.sh`, the merge gate, runs none of them. Each was written for one change, run by hand a few times, and then never again, so a regression in any of those behaviours passes the gate. Make them part of the suite, or delete the ones that no longer test anything.

Read first: `scripts/run-all-tests.sh`, `scripts/e2e-app.js` (`runE2e`, ports, `freshDbEnv`), `scripts/e2e-browser.js`, and every check script's header comment (what it checks and why).

## Build
1. **Inventory** (`scripts/e2e/README.md`): each check, what it verifies, its port, how long it takes, whether it passes on master today, and whether another check or a unit test already covers it. Run each once through the evidence runner, one at a time.
2. **Prune.** A check that duplicates another or tests a feature that no longer exists is deleted, with the reason in the inventory. A check that fails on master because the app changed on purpose is updated to the current behaviour; one that fails because of a real bug is kept failing and reported (do not fix product code here; list the bug in `open_questions`).
3. **One runner**: `scripts/run-e2e.sh` (or a node runner) runs every kept check in sequence, each on its own port, one browser at a time, and prints one PASS/FAIL line per check, the total time, and an exit code that is 0 only when all passed. A check that cannot find Chrome fails loud, never skips.
4. **In the gate.** Add the runner to `scripts/run-all-tests.sh` after the unit suites, with its own `--- e2e: exit N ---` line. The whole gate should stay under 5 minutes on this machine: measure it. If the browser checks alone push it past that, say which checks cost the most and make them faster (shared backend start, fewer page loads) before considering anything else.

## Tests
- The runner's own behaviour: a deliberately failing check (a temporary script) makes it exit non-zero and name the check; save that run, then remove the script.
- `bash scripts/run-all-tests.sh` passes on the branch, with the e2e section in its log, run through the evidence runner. This one full run is allowed because the task is the gate itself.

## Commands
One command per Bash call, each through the evidence runner: `node scripts/<check>.js`, `bash scripts/run-e2e.sh`, `bash scripts/run-all-tests.sh`, `node --test <files>`, `backend/.venv/bin/pytest <files>`. Do not run `npm install` or `pip install`. One browser at a time.

## Done when
Every kept browser check runs in `scripts/run-all-tests.sh` through one runner, the pruned ones are gone with their reasons in the inventory, the gate's time is measured and under 5 minutes (or the task says exactly why not), and the suite passes.
