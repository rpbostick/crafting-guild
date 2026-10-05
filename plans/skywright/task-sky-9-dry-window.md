# skywright: dry-window finder and "leave by"

A rider wants to know when a ride of a given length stays dry: "dry from 17:10 for 50 minutes", "leave by 17:05 or after 17:50". This is a pure function over a forecast already fetched. It reads `Forecast.subHourly` (15-minute or finer steps) where that covers the time, and the hourly points beyond it.

Read first: `src/model.ts` (`SubHourly`, `precipRateMmPerHour`), `src/ride.ts` (how a ride's start and duration are given and how hours are overlapped), `test/ride.test.ts`, the fixtures `test/fixtures/open-meteo-minutely-houston-unixtime.json` (showers with dry gaps in the first six hours) and `open-meteo-minutely-munich-unixtime.json` (rain ending in the first hour).

## Build: `src/dryWindow.ts`, one new line in `src/index.ts`
1. **A precipitation timeline**: `precipTimeline(forecast, { from, until })` returns consecutive steps `{ startMs, endMs, precipMm, rateMmPerHour, probabilityPct?, resolution: 'sub-hourly' | 'hourly' }` covering `from` to `until`: sub-hourly steps while `subHourly` has them, then hourly points from where it ends, with no overlap and no gap at the join. A forecast without `subHourly` gives hourly steps only.
2. **`dryWindows(forecast, opts)`**: `opts` has `durationMin`, `from` (a `Date` or ISO time, as `RideOptions.start`), `until`, and thresholds with named default constants: `maxRateMmPerHour` (default 0.1, the lowest amount the fixtures report in a step, expressed as a rate: state the source in the comment) and `maxProbabilityPct` (default 30, applied only to steps that carry a probability and report no amount). Returns every maximal span, at least `durationMin` long, in which each step is dry by those thresholds: `{ start, end, resolution }` with `resolution` the coarsest step the span touches, in time order. Times come back as ISO strings with the offset of the step they fall in.
3. **`leaveBy(forecast, opts)`** with the same options: `{ now: boolean, earliestStart?: string, latestStartOfFirstWindow?: string, nextWindowStart?: string, resolution? }`. `now` is true when a ride starting at `from` stays dry; `latestStartOfFirstWindow` is the last start that still finishes dry in the first window ("leave by"); `nextWindowStart` is the start of the window after it ("or after"). No window before `until`: every field but `now` is undefined.
4. A span's edges fall on step boundaries; do not interpolate inside a step. A ride longer than the timeline, a non-positive duration or `until` before `from` throws a `RangeError` with the value in the message.
5. README: a short section with one example of each function.

## Tests (`test/dryWindow.test.ts`)
- Houston: the windows the fixture's 15-minute amounts give for a 30-minute and a 120-minute ride, written out as times in the test, not recomputed with the same code; `leaveBy` for a start in the first shower and for a start in the first gap.
- Munich: not dry now, dry after the third step.
- The join: a window that starts in the sub-hourly part and ends in the hourly part has resolution `hourly`; no step is counted twice at the join.
- A forecast without `subHourly` (Boulder) works on hourly data.
- The probability threshold applies only where no amount is given.
- The thrown errors in 4.

## Prior art
No library fits: this is a sliding window over one array, and the apps that offer it (Tailwind GPS's best hour to leave, moopmoop's "leave later") are closed. Reuse `src/ride.ts`'s parsing of a start time and its overlap of a ride with forecast hours rather than writing them again; move a shared helper into its own file if both need it.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest <files>`, `npx tsc --noEmit`, `npm run demo:typecheck`, `node`. Do not run `npm install`.

## Done when
The three functions are exported, the tests and typechecks pass, and the README shows them. The demo app is unchanged.
