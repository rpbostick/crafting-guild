# figurewright step 2, fix 1: the Bear head SVGs, and the skipped tests

Track: light

You are continuing on your branch `agent/fw-port` (tip 9ee4944). You found that Bear's asset `parts/<pose>/head/Bear.svg` wasn't vendored. The orchestrator has now copied the 9 files from colorwright b527691 into your worktree, untracked: `vendor/colorwright/parts/<pose>/head/Bear.svg` for all 9 poses.

1. Commit the 9 files as they are (`git add vendor/colorwright/parts/*/head/Bear.svg`), and add one line to `vendor/colorwright/NOTICE.md`: the `head` slot is left out except each pose's `head/Bear.svg`, which the Bear head style's `asset` points to. That is the only change to `vendor/` you may make.
2. In `test/colorwright/vendor.ts`, turn `testNeedingBearSvg` back into `test` so the 16 skipped tests run. If the helper is then pointless, inline it.
3. Keep `parseLook`/`parseLookColors` stricter than colorwright (throwing on a non-string slot id or a non-object colour entry). Say so in a comment where they differ from colorwright, and make sure a test covers each of the two throws.
4. Do not commit the `node_modules` symlink (main's `.gitignore` now ignores it; your branch may still show it as untracked; leave it).

## Commands
One command per Bash call. `npx jest test/colorwright`, `npx tsc --noEmit`, and git add/commit. Do not run `npm install`.

## Done when
All ported tests run with none skipped (report the count against the 881 passed + 16 skipped before), `npx tsc --noEmit` is clean.
