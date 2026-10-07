# Bike Weather: the timeline review's carry-forwards

**Track: light.** Six small items from the reviews of the timeline views and the shelves follow-ups. Nothing changes on the screen except the README; no preview.

Read first: `src/screens/wardrobe/SegmentedChoice.tsx` (the view switch); `src/screens/today/TimelineColumn.test.tsx`, `TimelineStrip.test.tsx`, `timelineLayout.ts`; `src/transfer/webTransfer.test.ts` (the three focus tests); `README.md` (the Today section's timeline paragraph and the long line in the suggestion-states paragraph near "the gaps, the saved outfits").

## What to build
1. **The switch fits four labels.** A test of `SegmentedChoice` with the four outfit view labels (Shelves, List, Strip, Timeline) at a 360 px wide layout: every label renders whole, none truncated or wrapped to a second line, in both themes. If the component cannot be measured in the test renderer, test the width bound the previous builder estimated by hand (about 65 px for "Timeline" in a 79 px option) as a unit test of whatever sizing function or constant decides the option width, and say so.
2. **A red run on record for the column test.** `TimelineColumn.test.tsx` has no failing run before its passing one. Add one assertion that fails against a deliberately wrong layout constant (change it, run, record the failure, restore it, run, record the pass) so the test is shown to bite. The evidence runner logs both runs.
3. **The README's hour labels.** The timeline paragraph says the labels are "the start, each whole hour and the end"; `stripLabels` and `columnLabels` drop a label that would overlap a kept one or sit under a pin's tick. Add the clause. Rewrap the one over-long line near "the gaps, the saved outfits" at the paragraph's own width (about 100 columns), words unchanged.
4. **One focus test.** The two picker focus tests at lines 109 and 118 of `webTransfer.test.ts` are the same scenario over two input classes; fold them into one `it.each` over the two classes, keeping the comment that the second class guards against reintroducing the `'oncancel' in input` gate.
5. **Pictures of the timeline views in the evidence.** Render `TimelineStrip` and `TimelineColumn` over the `RAIN_POSSIBLE` fixture to an image a reviewer can open: if the project has no renderer that writes a PNG without a browser, write the React Native Testing Library tree of each view as text under `.ws-evidence/` and name that in the result as the nearest thing; do not add a package for this.

## Leave alone
The views' layout and the suggestion's shapes; `src/recommend/`; everything outside the files named.

## Tests
`npx jest --runInBand src/screens src/transfer src/ui` and `npx tsc --noEmit` pass; item 2 has its failing run on record.

## Prior art
No new code of note; `it.each` is jest's own.

## Commands
One command per Bash call, each check you cite through the evidence runner: `npx jest --runInBand <paths>`, `npm test`, `npm run typecheck`, `npx tsc --noEmit`, `git status`, `git diff`, `git log`, `git add`, `git commit`, `git restore --source=<ref> -- <path>`, `grep`, `ls`, `cat`, `mkdir`. No plain `rm` or `mv`, no `npm install`.

## Done when
`npm test && npm run typecheck` pass; the four-label test exists (or the width-bound test, with the reason); the column test's red run is on record; the README's hour-label clause and the rewrapped line are in; the two focus tests are one `it.each`; the views' pictures or trees are in the evidence; the result states the number of tests with the log it comes from. Commit after each numbered item. Safe to re-run from scratch.
