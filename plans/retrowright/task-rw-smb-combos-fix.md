# retrowright: combos, the README number and a stricter combo rule

Track: full

This continues this branch (`7d90ef4`). Read your earlier result first; keep what is there. Never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository.

## Blocking, from the review
- README.md:102 (rule 3): The manual paragraph says "slowing at the manual friction (38/256 a frame by default, the coasting friction, so a manual rolls as far as coasting)", but skate-pedal.tunables.json, the README's own defaults list in the same section and the Tune section give the manual friction and the coasting friction as 28. A user reading the sentence gets the wrong default. Change 38/256 to 28/256.

## The combo rule, chosen in play
Plain ollies must not keep a combo alive: only a landed trick, a stomp, or a manual does. An air that adds no step ends the combo on landing (or, if he lands into a manual, the manual keeps it). Use the extra RAM byte your last result named. Movie test: ollie, kickflip, land, plain ollie, land, stomp: the stomp starts again at 100.

## Suggestions, take the quick ones
- .ws-evidence/runs.tsv:20: The first after-combos-final run (--reporter=verbose) exited 1 and its log was overwritten 16 seconds later by the passing --reporter=dot run under the same label, so what failed is not recoverable. Give a failed run its own label so the before/after pair stays readable; the precheck's rule-15 flag comes from this and from the dot-reporter commands not matching the earlier command strings.
- harness/smbSkate.test.ts:1625: The combo coins' step (comboCoin) is only exercised at its default of 2: no coin at step 1, a coin at steps 2, 3 and 11. A run with it tuned to 1 (a coin for the first trick) or 4 (none for the third) would show the patch reads the byte, as the comboWindow test does at 120.
- harness/smbSkate.test.ts:1914: The hand-placed movies for the loose board, the fire flower, the recorded play and the vine replay on a ROM tuned back to the coasting friction of 38, so those paths are no longer run at the default build's 28 (the ride into the Goomba and the bail tests still are). Re-placing them at 28 when there is time would put the whole suite on the shipped defaults.
- harness/smbSkate.test.ts:1624: The builder's unknowns note that no one has played the 60-frame window and the half-trick grace, and that a combo with only a stomp in the current air carries on through a hit in that air. Both are design questions for a play session, not defects; record the decision in the README once settled.

## Prior art
The branch as it is.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The README states 28 where it gives the manual and coasting friction; the combo-rule movie test fails on `7d90ef4` and passes now, no lag frames (logs).
- `npm test`, `npm run e2e:tune` and `npm run build` pass in full (logs).
