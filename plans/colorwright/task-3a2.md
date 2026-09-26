# 3a-2: make the old e2e checks work with the carousel rows, retire the one-offs

Since the carousel rows merged (`e39dce1`, 2026-09-24), every category is a 5-tile row with «‹›» paging, None first and Title Case names. Many older `scripts/*-e2e-check.js` scripts still look for the old wrapping grid and fail, and two scripts (`e2e-smoke-check.js`, `investigate-fresh-session-screenshot-artifact.js`) still default to port :8792, which is no longer the app. These checks are not in `scripts/run-all-tests.sh`; they are run by hand. **No visible change to the app.** Use one command per Bash call.

Commands you may run: `node ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `git grep ...`, `bash -n ...`, and git add/commit/rm/mv.

**Browser ports: use only 8790-8795.** Another builder is running browser checks on 8796-8799 at the same time. Never run a script on a port outside 8790-8795.

## 1. A shared helper
- The recently rewritten checks (`rows-`, `hats-`, `hair-colour-`, `skin-control-`, `per-part-color-independence-`, `facialhair-accessories-all-poses-e2e-check.js`) each carry their own server start-up and tile lookup. Add `scripts/e2e-app.js` (next to `scripts/e2e-browser.js`) with what they share: start the backend on a given port plus the frontend proxy on port+1 (as `rows-e2e-check.js` does), stop them, and `findTile(page, category, label)` that pages the category's row until the tile with that label is visible and returns it. Read those scripts first and take the working code from them; don't invent a new approach.
- Every script you rewrite takes `--port N` (uses N and N+1) with a default inside 8790-8795.

## 2. Triage every older script
For each `scripts/*.js` other than the six above, `e2e-browser.js`, `mock-static-server.js` and `demo-screenshots.js`: read it and decide.
- **Rewrite** it with the helper if it guards a feature that still exists (colorization, colour swatches, head persistence, session recovery, head-first flow, outfit alignment, body-style re-pick, cross-family heads/faces/facial hair, skin tone, and so on). Then run it on 8790-8795 and get it passing. If it fails because the app is actually wrong, don't fix the app: record the failure and stop that script there.
- **Retire** it (`git rm`) if it was a one-off investigation or its feature is gone or fully covered by a newer check. Name its last valid commit (the last master commit where it still passed or matched the UI; `git log` on the frontend helps) in `scripts/RETIRED.md`, one line each: script, last valid commit, why retired, what covers it now.
- `e2e-smoke-check.js` and `investigate-fresh-session-screenshot-artifact.js` must not default to :8792 after this, whichever way you decide.

## 3. Carried review suggestions
- `scripts/e2e-browser.js:9`: use a plain `require('puppeteer-core')`; the fallback finds nothing the first require missed. Line 37: say the cache lookup is Linux-only.
- `backend/README.md` still describes the old seeding (`seed_catalog` skipping an already-seeded db). Describe today's startup catalog sync (it syncs the catalog table to the manifest and never touches saved looks), and add a troubleshooting entry for the duplicate-id startup error.
- The dangling-look warning in the backend (find it with `git grep -n -i dangling backend`) overstates the outfit case. Make its wording match what it checks, and pin the wording with a test if none covers it.
- `scripts/evidence/facialhair-accessories-all-poses/render.js:14` and `scripts/evidence/hat-beanie-fill/render-grid.js:14` hold a `/home/<user>` path: change only that line to use `require('../../e2e-browser')`. Leave the rest of `scripts/evidence/` alone.

## Evidence
`scripts/evidence/3a-2/README.md`: a table of every script with its decision (rewritten / retired / kept as is), the command you ran, and pass/fail counts and exit code. Logs in `scripts/evidence/3a-2/logs/`. Repo-relative paths only. The full `bash scripts/run-all-tests.sh` output goes in `scripts/evidence/3a-2/unit-tests.log`.

## Leave alone
`frontend/`, `pipeline/`, `assets/`, `.claude/`, and the framing and assertions of the six recent checks above (you may switch them to the shared helper, but keep their assertions and don't change their default ports).

## Done when
- Every `scripts/*-e2e-check.js` left in the repo passes when run on 8790-8795, or its failure is shown to be an app bug and recorded in the README.
- `git grep -n 8792 -- scripts ':!scripts/evidence'` prints nothing.
- `scripts/RETIRED.md` lists every retired script with a commit.
- `git diff master --stat -- frontend pipeline assets` is empty.
- `bash scripts/run-all-tests.sh` exits 0 and its log is committed.
