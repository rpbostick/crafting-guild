# colorwright: e2e scripts create their evidence directories
Track: light

You are continuing `agent/cw-scrub`. `scripts/evidence/` is now untracked, so its subdirectories don't exist on a fresh clone. The review blocks on five e2e scripts that write screenshots and logs there without creating the directory first:
- `scripts/skin-control-e2e-check.js:44`
- `scripts/skin-tone-feature-e2e-check.js:42`
- `scripts/hair-colour-e2e-check.js:45`
- `scripts/per-part-color-independence-e2e-check.js:58`
- `scripts/facialhair-accessories-all-poses-e2e-check.js:63`

Before the first write, add `fs.mkdirSync(dir, { recursive: true })` for each output directory (screenshots and `path.dirname(LOG_PATH)`), as `scripts/hats-e2e-check.js` already does. Then grep every other `scripts/*.js` for writes under `scripts/evidence/` without a mkdir, and fix those the same way.

## Check
For each fixed script, `node -e "require('fs').rmSync('scripts/evidence/<its dir>',{recursive:true,force:true})"`, then run the script's first write path once: a `node --check` plus a run with the static server if it starts without a backend, or a short unit test on a shared helper if you factor one out. Save the output. `node --test "frontend/tests/*.test.js"` passes.

## Commands
One command per Bash call: `node …`, `node --test …`, `git grep …`. Do not install anything.

## Done when
No script writes into a directory it didn't create.
