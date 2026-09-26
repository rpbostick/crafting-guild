# Cleanup sweep: e2e browser paths and carried review suggestions

Colorwright's recent reviews left small, non-blocking suggestions, and most of the e2e scripts hard-code `/home/patrickb/...` paths for puppeteer-core and Chrome (checklist rule 18). This task clears them. **No visible change to the app**: the catalog, the pipeline's output and what the app draws stay exactly as they are. Use one command per Bash call.

Commands you may run: `node ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `pipeline/.venv/bin/python3 ...`, `sed -i ...` (one file per command), and git add/commit/rm/mv.

## 1. One browser helper for the e2e scripts
- Add `scripts/e2e-browser.js` exporting `puppeteer` (`require('puppeteer-core')`, falling back to `path.join(__dirname, 'node_modules', 'puppeteer-core')`) and `chromePath(explicit)`: the explicit argument if given, else `process.env.CHROME_PATH`, else the newest `chrome-linux64/chrome` under `path.join(os.homedir(), '.cache', 'puppeteer', 'chrome')`, else throw an error saying how to pass it.
- Make every tracked `scripts/*.js` that hard-codes a `/home/patrickb` path use it (list them with `grep -rln /home/patrickb scripts --include=*.js`, leaving out `node_modules` and `scripts/evidence/`). That includes `scripts/hats-e2e-check.js` (its inline version from the hats round), `rows-e2e-check.js`, `hair-colour-e2e-check.js`, `skin-control-e2e-check.js` and `e2e-smoke-check.js`. Keep each script's existing positional chrome-path argument working. Change nothing else in those scripts. Don't touch `scripts/evidence/`; those are records of past runs.
- Check: `node --check` on every changed script, and `grep -rn /home/patrickb scripts --include=*.js` shows only `node_modules` and `scripts/evidence/` hits. Then run two for real with no chrome argument: `node scripts/hats-e2e-check.js --no-renders --log build/sweep-hats.log` and `node scripts/rows-e2e-check.js --no-screenshots --log build/sweep-rows.log` (build/ is gitignored). Report their pass/fail lines and exits.

## 2. Carried suggestions
- `scripts/install-hooks.sh`: also remove a leftover `post-commit` or `post-merge` in `.git/hooks/` if it's the old v1 dispatcher (check its content for `agentic-workspace` first; leave anything else alone), and print what it removed.
- `scripts/evidence/review-hook-refresh-2026-09-23.log`: `git rm` it (it documents a hook that no longer exists and was edited in place).
- `README.md:374` and `plans/requirements.md:2777` name `toolkit.db.add_look_hat_column`, which is now `add_look_columns`: name the current function first. `backend/README.md:52`: the 2026-09-24 approval of the in-place migration was extended to `carried_colors_json` by plan 18 step 5b-3 (2026-09-25); say so.
- Rewrap the overlong lines at `README.md:155` and `README.md:215` to match their paragraphs. Fix the missing space in `frontend/logic.js:154`'s `COLOR_ROLE_ORDER`.
- `frontend/logic.js` `withFacialHairFollowing` (about line 246): limit the result to the equipped item's own roles, so a stale key (such as Full-4's old `outline`) is dropped. Add a test that fails before the change.
- `backend/toolkit/validation.py` (about line 141): log the colour roles it drops (one `logging` warning naming slot, item and roles). Add a test using `caplog`.
- `backend/tests/test_hat_slot.py:38`: pin the pre-hat look columns to master's list as it was before the hat (a literal list with a comment citing the commit), instead of deriving it from today's model. At line 69, test that `init_db` fails on an old db when the migration is patched to a no-op, instead of calling the private `_check_schema_matches_models`.
- `backend/tests/test_carried_colors.py:55`: show the migration tests have teeth. Temporarily remove `carried_colors_json` from `ADDED_LOOK_COLUMNS`, run those tests, save the output to `scripts/evidence/sweep-1/teeth-added-columns.log`, restore it, and commit only the log.

## Evidence
`scripts/evidence/sweep-1/README.md` with every command, its result and exit code, repo-relative paths only. The full `bash scripts/run-all-tests.sh` output goes in `scripts/evidence/sweep-1/unit-tests.log`.

## Leave alone
`assets/`, the pipeline modules, `.claude/`, `scripts/evidence/` apart from the one `git rm` above and the new `sweep-1/`.

## Done when
- `grep -rn /home/patrickb scripts --include=*.js | grep -v -e node_modules -e scripts/evidence/` prints nothing.
- Both e2e runs report 0 failed, with no chrome argument given.
- `git diff master --stat -- assets pipeline` is empty.
- `bash scripts/run-all-tests.sh` exits 0 and its log is committed.
