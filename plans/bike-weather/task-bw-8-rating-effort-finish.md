# Bike Weather: finish the rating, effort and heat step

Track: light

An earlier run did items 1 to 7 and 9 of the step (effort on ratings, outfit names, the carried record, document version 2, loading that never locks, one pair of footwear, heat wired in, failure cases, README) and stopped with these left. Run `git status` and `git log --oneline main..` first and keep what is there. Do only what is listed. Uses WebFetch for the licence texts.

1. `offsetMsOfTime` in `src/suggest/outing.ts` still duplicates the `LOCAL_TIME` pattern in `src/ui/format.ts`: export one offset parser from `format.ts` beside `localHourLabel` and use it in both places, with the existing tests still passing and one test of the shared parser.
2. The rain-class words exist in `src/recommend/reasons.ts` and `src/suggest/words.ts` and differ on purpose: one exported table in `reasons.ts` holding both phrasings keyed by use, read by both files, so a new rain class cannot be added to one and missed in the other (a test or a type makes that fail).
3. `THIRD-PARTY-NOTICES.md`: replace the paraphrased MIT (mdljts/wbgt) and BSD-3-Clause (pvlib) texts with the verbatim texts from each project's own LICENSE file, fetched from the project's repository, each with its copyright line as that file gives it. The Argonne notice stays as it is.
4. `docs/research/clothing-weather.md`: §1.4 still gives Liljegren's error without pointing at the measured figures, and §3.7 still says WBGT is not shown until skywright has solar radiation. Correct each with one line that links `docs/research/heat-estimate.md`, without rewriting the report.
5. `docs/research/heat-estimate.md`: the wiring list's items are out of order (10 above 9); renumber.
6. The one-pair-of-footwear rule has no recorded failing run before the change: record one through the evidence runner by a test that fails without the rule (a scratch copy of the test against the rule switched off, under `.ws-evidence/scratch/`, is enough), then the passing run.
7. Run the whole suite and the typecheck through the evidence runner and state the count with its log.

## Commands
One command per Bash call, each check you cite through the evidence runner: `npx jest --runInBand <paths>`, `npm test`, `npm run typecheck`, `git status`, `git diff`, `git log`, `git add`, `git commit`, `git restore --source=<ref> -- <path>`, `git clean -f -- <path>`, `grep`, `ls`, `cat`, `mkdir`. No installs, no plain `rm` or `mv`.

## Done when
Items 1 to 7 are done or answered in the result; `npm test && npm run typecheck` pass; and the result states the number of tests with the log it comes from, three suggested outfit names and three heat sentences (one per shown level) exactly as a screen would show them. Safe to re-run. Commit after each numbered item.
