# Synthesis v3 draft: fix round

Continue on this branch. Review findings (blocking), quoted in `/home/patrickb/agentic-workspace-v2/runs/pen-paper-rpg/ppr-synthesis-v3.review.md` (read it):

1. **`tests/balance-v3.test.js:47` and `:52`** rebuild the expected values inside the test (the Opportunist wager from `odds.full - odds.miss`; the cascade lambda copied from `v3.js`) instead of calling `opportunistTable()` and `draftCTable()`. Rewrite them to call the production functions and compare with independently hand-computed numbers written as literals, so a wrong table fails the test. Do the same for any other v3 balance test with the same pattern.
2. **`rules/v3/synthesis.md:3525` (groups-tier-tag)** contradicts itself: four companions are a Band, the module says size steps apply between groups, yet "Party of four against twenty orcs" (Band vs Company) uses only the tier step. Fix the example and `draftCTable` (`scripts/balance/v3.js:282-290`) so group-vs-group uses size steps and person-vs-group uses tiers, as the module text says; recompute and update the table in the doc from the calculator.

Also, from the run's own open question: **model a day of workings** for raw Chaos magic (`magic-chaos-damage`, `magic-chaos-power`): extend the calculator with a daily Power pool so the discussion can show whether the pool closes the 1.78–2.24× gap from level 3; update that discussion with the numbers (still `status=open`, no decision).

## Tests
The rewritten tests fail against a deliberately wrong table (show one red run in `.ws-evidence/` via ws-run), then pass; the v3 format, coverage and CHANGES tests still pass.

## Commands
`node --test tests/<file>.test.js`, `node scripts/balance/<script>.js`, `node scripts/<script>.js`, `git add`, `git commit`. One command per Bash call.

## Done when
Both findings are fixed with tests that exercise the production functions, the day-of-workings numbers are in the Chaos magic discussion, and the tests pass.
