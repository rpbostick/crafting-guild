# Bike Weather: the temperature along the timeline views

The Strip and Timeline views (`src/screens/today/TimelineStrip.tsx`, `TimelineColumn.tsx`, over `src/suggest/timeline.ts`) show the outing's rain and where the carried garments go on. This task adds the temperature at each hour mark, so the person sees the cold or warm hours against the rain and the garments. Which temperature follows the app's own convention (`src/recommend/need.ts`, `Need.forecast`): the **air temperature for a ride**, the wind being said separately as the air on the rider, and the **standing feels-like for everyday**. Visible: a person looks at both views in a browser before the merge.

Read first: `README.md` (Today section, the timeline paragraph); `src/suggest/timeline.ts` and its test (`HourMark`, `outingTimeline`); `src/suggest/suggestion.ts` around the `outingTimeline(` call (what the window offers there: `window.summary.hours`, skywright's `RideHour`s with `temperatureC` and `apparentTemperatureC`, and `window.mode`); `src/recommend/need.ts` lines 176 to 200 (the convention); `src/screens/today/timelineLayout.ts` (`stripLabels`, `columnLabels`, `PlacedLabel`), `TimelineParts.tsx`, both views and their tests; `src/suggest/words.ts` (the views' summary sentence); `src/ui/format.ts` (`formatTemp`).

## What to build
1. **The view-model carries the temperature.** `HourMark` gains `temperatureC?: number`: the value of the forecast hour the mark falls in (the hour whose span holds `atMs`; the outing's end at a whole hour takes the hour before it), air temperature for a ride and `apparentTemperatureC` for everyday, `undefined` when that hour has no value. `OutingTimeline` gains `temperature: 'air' | 'feels-like'` saying which it is. `outingTimeline` takes the hours and the mode as new arguments; `suggestToday` passes `window.summary.hours` and `window.mode`. Tests: a ride's marks carry the air temperature and a walk's the feels-like over the `RAIN_POSSIBLE` fixture and a dry one; a mark on an hour without a feels-like is `undefined`; the end mark at a whole hour reads the hour before.
2. **The strip.** Above the strip, at each placed hour label's position, the figure through `formatTemp` in the person's units ("5°C"); a label that `stripLabels` drops takes its figure with it, and a figure is never drawn without its label. The figure is the same size and colour as the hour label, so the strip reads as time below and temperature above. No line between figures: the rain bar stays the only chart.
3. **The column.** In the gutter beside each placed hour label, the figure after the time ("09:00  5°C"), aligned so the figures form their own column. `columnLabels` unchanged unless the gutter needs widening; say if it did.
4. **The summary sentence** each view uses as its accessible label gains the span, "5°C to 8°C" or "5°C throughout", with "feels like" in front for everyday, from the view-model's marks; tested.
5. **README**: the timeline paragraph says the hour marks carry the temperature, which temperature in each mode and why (the convention), and that it reads the hour the mark falls in.

## Leave alone
`src/recommend/`, the stored shapes, the Shelves and List views, the rain bar and the pins, the rating panel.

## Tests
`npx jest --runInBand src/suggest src/screens` and `npx tsc --noEmit` pass; the whole suite before the result; dark appearance on the figures; the summary sentence; each new assertion has a failing run on record before its passing one.

## Prior art
- Apple Weather's hourly strip puts a temperature figure above each hour; the strip does the same at its hour marks.
- Dark Sky's 24-hour timeline moved a temperature circle left and right with the value; the column's gutter figure is the plain form of that.
- Weather Line draws the hours as a fluctuating temperature line; not taken, a line would be a second chart beside the rain bar, and an outing is four to twelve marks.
- No package: `formatTemp` and the existing label placement do the work.

## Commands
One command per Bash call, each check you cite through the evidence runner: `npx jest --runInBand <paths>`, `npm test`, `npm run typecheck`, `npx tsc --noEmit`, `npx expo export --platform web` (do not commit its output), `git status`, `git diff`, `git log`, `git add`, `git commit`, `git restore --source=<ref> -- <path>`, `grep`, `ls`, `cat`, `mkdir`.

## Done when
`npm test && npm run typecheck` pass and the web export builds; the hour marks carry the temperature by the convention with tests both modes; both views show the figures at the placed labels only; the summary sentence has the span; the README matches; the result states the number of tests with the log it comes from (the whole suite), and the strip's labels with their figures for `RAIN_POSSIBLE` exactly as rendered. A person looks at both views in a browser before the merge. Commit after each numbered item. Safe to re-run from scratch.
