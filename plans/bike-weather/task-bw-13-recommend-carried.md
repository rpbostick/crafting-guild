# Bike Weather: the recommendation engine's carried review items

Track: light

Review suggestions on `src/recommend/` have been carried through three tasks that were told to leave that folder alone. This task does them, in `src/recommend/` only.

Read first: `README.md` (the recommendation section); `src/recommend/recommend.ts`, `need.ts`, `heat.ts`, `reasons.ts`, `wearability.ts` and their tests; `src/suggest/rate.ts` (item 5 only); `docs/research/heat-estimate.md`.

## What to build
1. **A clashing saved outfit cannot become the suggestion.** `savedCandidates` in `recommend.ts` leaves out a stored outfit that breaks the one-per-layer or one-footwear rule (`clashBetween`), so `fitsBeside`'s promise in `wearability.ts` holds for every suggested outfit. The outfit is still ranked in the saved list and flagged as needing attention. Test: a stored outfit with two garments on one layer that would win on score is not the suggestion and is listed with its flag.
2. **The heat estimate never takes the suggestion down.** A test sweeps `estimateWbgt` through the forecast range (air −35 to 50 °C in steps, relative humidity 0 to 100 % including 0 and 100, wind calm to 30 m/s, day and night, clear and overcast) and asserts no throw and a finite result. Where 0 % humidity is refused today, floor it to the smallest value the method accepts and say so in the docstring and in `heat-estimate.md`; if the solver can fail to converge, return the bound it reached with `basis` saying so rather than throwing. `needFor` in `need.ts` still runs the estimate only where it does now.
3. **A walk gets its own heat sentence.** In `reasons.ts` the heat caution for everyday mode no longer says to ease off on climbs; it says, in plain words, to slow down, keep to shade and carry water. Rides keep their sentence. Test both modes at the same conditions.
4. **Two documentation corrections.** `CLEAR_SKY_SHARE`'s docstring in `heat.ts` names 1.15, matching `EXPECTED_CLOUD_RATIOS`; the test "put the low share near the 5th percentile and the high share above all but one ratio" in `heat.test.ts` asserts the low share too.
5. **Rating a saved outfit with carried garments.** `ReadySuggestion.save` stores worn and carried together; rating that outfit through `worn: { outfit }` counts the carried shell as worn. Make the smaller of two changes and test it: either the `{ outfit }` path takes an optional carried split that `rate.ts` passes, or the docstring on `rateOutfit` says callers pass `{ garmentIds }` plus `carried` for such outfits and `rate.ts` does so. State which in the result.

## Leave alone
Everything outside `src/recommend/` except the one call site in `src/suggest/rate.ts` for item 5 and the two documents named; the stored shapes; the screens.

## Prior art
The method and its sources are already chosen in `docs/research/clothing-weather.md` and `heat-estimate.md`; nothing new is researched. The Liljegren port in `heat.ts` is the one estimate.

## Commands
One command per Bash call, each check you cite through the evidence runner: `npx jest --runInBand <paths>`, `npx tsc --noEmit`, `git status`, `git diff`, `git log`, `git add`, `git commit`, `git restore --source=<ref> -- <path>`, `git clean -f -- <path>`, `grep`, `ls`, `cat`, `mkdir`. No plain `rm` or `mv`.

## Done when
`npx jest --runInBand src/recommend src/suggest` and `npx tsc --noEmit` pass with the tests above added; the sweep in 2 covers the stated range; the result states the number of tests with the log it comes from, what 0 % humidity now does, and which change item 5 made. Commit after each numbered item. Safe to re-run from scratch.

## Carried from the bw-today-followups review (suggestions; do them where the code is yours to touch)
- `src/screens/TodayScreen.test.tsx:29`: Rule 3/15: the comment says React Native's jest setup returns no subscription from AppState.addEventListener. React Native 0.65+ ships `addEventListener: jest.fn(() => ({ remove: jest.fn() }))` in jest/setup.js, so the comment is likely wrong (the spy is still needed to capture listeners; say that instead). More importantly, no evidence run covered src/navigation.test.tsx, which mounts the real Today screen through expo-router without this spy; if the stock mock really returned undefined, its unmount would throw on `subscription.remove()`. Run the full `npm test` (jest --runInBand over all of src) before merging and correct the comment to whatever setup.js actually does.
- `src/screens/TodayScreen.test.tsx:337`: Rule 2 (robustness): the hour-turns-while-open test uses a real clock started three seconds before 09:00 and asserts every request so far started before 09:00. showToday plus chooseFirst already spend about 1.5 s in settle() waits, and this file took 88 s in the full run, so under load the first request can land after 09:00 and the test fails without a code defect. Widen the margin (start the clock 10 s before) or drive it with jest fake timers.
- `src/screens/TodayScreen.tsx:259`: Rule 10: SaveOutfitForm and RatingPanel are keyed by requestKey, which now changes every hour for an outing starting now. A one-press rating in flight, an open detail form or a half-typed outfit name at the hour's turn is discarded with the remount, and the stored one-press rating can no longer be given its detail from the screen. The README documents the new panel per hour, so this is a design choice, but consider keeping the old panel while a rating or save is pending or the detail form is open.
- `src/screens/today/RatingPanel.tsx:187`: Consistency with the branch's own rule: Save the detail has no pending guard. A double press stores one record only because the store refuses a duplicate id and the second call's error lands on an unmounted form; disabling it while pending would make that explicit, as the one-press buttons and Save this outfit now are.
- `src/suggest/suggestion.ts:238`: Rule 9: FIRST_CAUTION_C recomputes what heat.ts's private strictestThresholds() already computes (the lowest caution across efforts). Export that function, or a FIRST_CAUTION_C from heat.ts, and read it here so the two cannot drift.
- `.ws-evidence/after-item6.log:1`: Evidence formatting: runs.tsv records two failing after-item6 runs (exit 1 at 23:44:51 and 23:45:33) but the log file was overwritten by the passing third run, so the failures they fixed are not on record. Keep one log per run next time.
