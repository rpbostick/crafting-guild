# Fix round 1 for `task-bw-16-shelves-followups.md`

The review of this branch at 7c088c7 found blocking issues. Fix each one, with a test where the finding is about behaviour, commit, and re-run the covering test files through ws-run. Do nothing else; suggestions are carried to a later task.

## Blocking findings
- `src/transfer/webTransfer.ts:59` (rule 3): The gate `!('oncancel' in input)` and the docstring above it (lines 30-32) claim that an input with `oncancel` has a `cancel` event. `oncancel` is a GlobalEventHandlers attribute present on every HTMLElement since browsers shipped `<dialog>` (Chrome 37, 2014; Safari 15.4, 2022), while `cancel` on `<input type=file>` only arrived in Chrome 113 and Safari 16.4 (2023). In Chrome 37-112 and Safari 15.4-16.3 (iOS 15 iPhones stuck there) the property exists, the fallback is skipped, and a cancelled dialog never settles the promise: the pending-for-good hang the fallback was added to avoid, and a regression from main for those users. Also rule 1 in spirit: a feature test that silently takes the wrong branch. Fix-first: remove the gate or replace it with a signal that tracks the file input's cancel support, and reword lines 30-32 and README line 103 to say what the code actually detects. Reviewer note: the browser facts come from memory of the HTML spec and release notes, not from a run here; the builder should confirm with MDN's compatibility tables for GlobalEventHandlers.oncancel and HTMLInputElement cancel_event before choosing the fix.

## The original task (for context)
## Bike Weather: the carried-shelves review's carry-forwards

**Track: light.** Three small fixes from the review of the Shelves view branch, none visible on the screen; no preview is needed.

Read first: `src/recommend/reasons.ts` and `src/suggest/suggestion.ts` (both have a `keepsDry`); `src/transfer/webTransfer.ts` and its test; `README.md` (the Today section's when-line sentence near "From 09:00 if it rains", and the back-up section's file-dialog sentence near "sends no `cancel`").

### What to build
1. **One `keepsDry`.** `src/suggest/suggestion.ts` holds a line-for-line copy of the private `keepsDry` in `src/recommend/reasons.ts`, with a docstring saying the two must agree. Export the original from `reasons.ts` (docstring: what it decides and that `suggestion.ts`'s when-line uses it too) and import it in `suggestion.ts`; delete the copy. This is the only change allowed in `src/recommend/`. The existing tests in `src/recommend/reasons.test.ts`, `src/suggest/suggestion.test.ts` and `src/suggest/words.test.ts` pass unchanged.
2. **The web file dialog's focus fallback only where it is needed.** In `pickFileText` the window-focus fallback runs in every browser; where the file chooser is not modal to the window (some Linux desktop choosers), focus can come back while the dialog is still open, the promise resolves `undefined` after the grace period, and the file picked afterwards fires a `change` that `settle` ignores, so it is silently dropped. Add the focus listener only when the input has no `cancel` event (`!('oncancel' in input)`); browsers with it settle through `cancel` or `change` alone. Say in the docstring why. Tests in `src/transfer/webTransfer.test.ts`: with an input that has `oncancel`, a focus coming back does not settle and a later `change` still delivers the file; without it, the present focus-and-grace behaviour holds (the existing focus tests). Check whether jsdom's `HTMLInputElement` has `oncancel` and state it in the result; if it does, the "without" tests make an input that lacks it (delete the property on the instance or fake the element), since what is under test is the branch, not jsdom.
3. **README.** The Today section's when-line sentence names its two other forms: "If it rains" when no single step crosses the rain threshold by amount or chance, and "Not expected to go on" for a garment a saved outfit carries that the day does not call for. The back-up section's file-dialog sentence says the focus fallback applies only to browsers without the `cancel` event.

### Leave alone
The List view keeps showing a carried garment's reason, not its when-line (decided). Everything else in `src/recommend/`, the stored shapes, the screens.

### Tests
`npx jest --runInBand src/recommend src/suggest src/transfer` and `npx tsc --noEmit` pass; item 2 has a failing run on record before its passing one.

### Prior art
- Feature detection by `'oncancel' in input` is the usual check for the `cancel` event on a file input (MDN, HTMLInputElement: cancel event); no package.

### Commands
One command per Bash call, each check you cite through the evidence runner: `npx jest --runInBand <paths>`, `npm test`, `npm run typecheck`, `npx tsc --noEmit`, `git status`, `git diff`, `git log`, `git add`, `git commit`, `git restore --source=<ref> -- <path>`, `grep`, `ls`, `cat`. No `rm`, `mv`, `npm install`.

### Done when
`npm test && npm run typecheck` pass; one `keepsDry` exists, exported from `reasons.ts`; the focus fallback is gated on the missing `cancel` event with tests both ways; the README names the when-line's other forms and the fallback's scope; the result states the number of tests with the log it comes from and whether jsdom's input has `oncancel`. Commit after each numbered item. Safe to re-run from scratch.
