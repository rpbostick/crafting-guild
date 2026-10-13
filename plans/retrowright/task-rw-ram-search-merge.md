# retrowright: bring the tools panel up to date with main

Track: light

`main` gained the patches feature (rw-patches) after this branch was made. Merging this branch fails on conflicts in `README.md`, `package.json`, `src/styles.css`, `src/ui/App.tsx` and `e2e/a11y.mjs`.

## What to do
1. Run `git merge main`. Resolve each conflict so that both features are kept whole: the tools panel (F4, RAM search, watch list, memory viewer, the focus-after-click rule) and the patches (Apply patch…, the patch harness command, its npm scripts, its accessibility audits).
2. Commit the merge.
3. Type-check, then run the tests for both features and both e2e scripts: `node e2e/patch.mjs` and the tools e2e script this branch added. Then run `npm run a11y` and `npm run build`.

## Prior art
Not applicable: a merge of two finished features.

## Commands
`git merge main`, `git merge main --no-edit`, `git add *`, `git commit *`, `npx tsc *`, `npx vitest *`, `npm run *`, `node *`, `firefox --headless *`. One command per Bash call.

## Done when
- The branch contains main, and no conflict markers are left (`git grep -n '<<<<<<<'` finds none).
- The unit tests for both features pass, `node e2e/patch.mjs` and the tools e2e pass, `npm run a11y` passes and `npm run build` passes, each with its log in `.ws-evidence/`.
