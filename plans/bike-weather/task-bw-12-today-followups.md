# Bike Weather: the Today screen's follow-ups from its review, and the quiet heat line

Track: light

The Today screen (`src/screens/TodayScreen.tsx`, `src/screens/today/`) and its view-model (`src/suggest/`) merged with a list of review suggestions and one product decision. This task does them. No layout changes except that the level-none heat line disappears on cool days.

Read first: `README.md` (the Today screen and `src/suggest` sections); `src/screens/today/RatingPanel.tsx`, `SaveOutfitForm.tsx`, `OutingControls.tsx`, `HeatNotice.tsx`; `src/screens/TodayScreen.tsx` and its test; `src/suggest/rate.ts`, `suggestion.ts`, `words.ts` and their tests; `src/recommend/heat.ts` (the warning levels and their thresholds; do not edit it).

## What to build
1. **One press, one write.** `RatingPanel`'s five level buttons and `SaveOutfitForm`'s "Save this outfit" are disabled (with `accessibilityState.disabled`) while their store write is pending; a second press during the write does nothing. Test: two presses before the fake store resolves store one rating; the same for one outfit.
2. **A start hour that passes.** In `OutingControls`, a chosen start that is no longer among the offered hours is treated as now: the label says now, Earlier is disabled, Later goes to the first remaining hour, and the outing passed on starts now. Test with the injected clock advanced past the chosen hour.
3. **One `errorText`.** The identical helper in `TodayScreen.tsx`, `RatingPanel.tsx`, `SaveOutfitForm.tsx` and `WardrobeScreen.tsx` moves to `src/ui/errorText.ts`; the four import it.
4. **The detail keeps the outing's time.** The detail rating in `src/suggest/rate.ts` copies the one-press rating's `ratedAt` instead of the time the detail was saved, so `learn.ts` weights the outing by its real age. Test.
5. **`carriedUse` counts an outing once.** `carriedUse` in `rate.ts` takes the per-outing ratings (`ratingsPerOuting`) rather than every stored rating, so a one-press rating and its `-detail` are one carried outing. Test with a one-press rating and its detail.
6. **A suggestion for now is asked again when the hour turns.** The screen's request key includes the forecast hour the outing starts in, and the screen asks again when the app returns to the foreground (`AppState`), so a tab left open does not keep the morning's answer at noon. Test: with the injected clock, advancing to the next hour asks the fake service again; the rating panel's "Rated" state belongs to the earlier request and is gone for the new one.
7. **Every control has a role and a label, in every state.** The role-and-label walk in `TodayScreen.test.tsx` runs over the empty-wardrobe and forecast-unavailable states as well as ready.
8. **The quiet heat line hides on cool days.** Decided in `src/suggest/` with a test, not in the screen: when the heat level is none, the heat line is shown only if the estimate's upper bound is within 3 °C of the first caution threshold from `src/recommend/heat.ts` (read the threshold from there; do not copy the number). Below that the ready state carries no heat line at all. The caution, high and extreme lines are unchanged. State the rule in the README's Today section and in `docs/research/heat-estimate.md`'s wiring list.
9. **README**: the version-2 document line names carried garments as `document.ts` does; the Today section reflects 1, 2, 6 and 8.

## Leave alone
`src/recommend/` (a separate task carries its review items), the stored shapes, the wardrobe screens' behaviour (3 only moves a helper), the screen's layout.

## Tests
React Native Testing Library with the fake weather service, the in-memory store and the injected clock, as the existing Today tests do. Each numbered item above names its test. Run `npx jest --runInBand src/screens src/suggest src/ui` and `npx tsc --noEmit`.

## Prior art
- `AppState` from React Native for the foreground event; no package. The disabled-while-pending pattern is the one `GarmentEditor` uses for delete, if it has one; otherwise the simplest `useState` flag.
- The clock injection and the fake service already exist in the Today tests; reuse them.

## Commands
One command per Bash call, each check you cite through the evidence runner: `npx jest --runInBand <paths>`, `npx tsc --noEmit`, `git status`, `git diff`, `git log`, `git add`, `git commit`, `git mv`, `git rm`, `git restore --source=<ref> -- <path>`, `git clean -f -- <path>`, `grep`, `ls`, `cat`, `mkdir`. No plain `rm` or `mv`.

## Done when
`npx jest --runInBand src/screens src/suggest src/ui` and `npx tsc --noEmit` pass with the tests named above added; the four screens import one `errorText`; the README and the heat-estimate wiring list match; the result states the number of tests with the log it comes from and the heat-line rule in one sentence. Commit after each numbered item. Safe to re-run from scratch.
