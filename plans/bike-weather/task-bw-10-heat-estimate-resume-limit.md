# Resume after the usage limit

An earlier run of this task stopped at the usage limit. Run `git status` and `git log --oneline main..` first, keep what is there (untracked `src/recommend/heat.ts`, the fixture files beside it and the notes under `.ws-evidence/` are that run's work; nothing is committed yet), and finish the task below.

## Bike Weather: an estimated WBGT with its uncertainty, as a pure module (not wired in yet)

On a hot day the app today shows a note with the heat index. Heat stress for someone exercising outdoors is better described by the wet-bulb globe temperature (WBGT), which sports medicine uses, but a true WBGT needs solar radiation and the forecast (`skywright`'s `HourlyPoint`) has none: it has temperature, humidity, dew point, wind, cloud cover, UV and the time. This task builds the estimate the app will show: a WBGT **range** from what the forecast does have, honest about what it does not know, with a clear warning level, and with a place for a measured solar value to replace the guess later.

Uses WebSearch and WebFetch to check formulas, reference values and thresholds against their sources.

Read first: `docs/research/clothing-weather.md` §1.4 (heat index, WBGT, the Bureau of Meteorology approximation, Liljegren, the ACSM flags), its table of libraries (jsthermalcomfort, thermofeel, lwbgt, feels) and §3.7's heat step; `src/recommend/need.ts` (`heatNote`) and `reasons.ts` (how a note becomes a sentence); skywright's `HourlyPoint`, `heatIndexC` and its README (it is installed from a sibling checkout; read it under `node_modules/skywright`).

### Where the code goes
New files only: `src/recommend/heat.ts`, `src/recommend/heat.test.ts`, fixtures beside them if needed, and `docs/research/heat-estimate.md`. **Edit no existing file** except `package.json` and `package-lock.json` if a dependency is added: another branch is changing `src/recommend/` and the README. Wiring the estimate into `need.ts`, the sentences and the screen is the next task; list in the result exactly what that task must change.

### Measure first
The method is chosen by numbers, not by reasoning. Candidates, at least:
- (a) the Bureau of Meteorology approximation from temperature and vapour pressure alone;
- (b) a shade value (natural wet bulb from temperature, humidity and wind; globe temperature equal to air temperature) and a full-sun value (globe temperature from an estimated solar load), giving a range;
- (c) as (b) with the solar load estimated per hour from the sun's elevation at the place and time and the forecast's cloud cover (a clear-sky model scaled by cloud), so the range narrows at night, under overcast and at low sun.
For each: its error against published reference values (worked examples or tables in the sources, the Liljegren validation figures the report cites, or values computed with a trusted implementation whose inputs and outputs are published), over a set of at least twelve cases spanning cool-humid, hot-dry, hot-humid, windy, overcast, low sun and night; and how often the true value falls inside the stated range. Put the table in `docs/research/heat-estimate.md` and choose by it. A fourth candidate is welcome.

### What to build
1. `estimateWbgt(input)`: a pure function. Input: air temperature, relative humidity (or dew point), wind speed at the person, cloud cover, the time and the latitude and longitude (for the sun's elevation only), and an optional measured solar radiation. Output: `{ lowC, highC, bestC, basis }` where `basis` says what the range rests on (`'estimated-sun'` or `'measured-sun'`) and names each assumption made, so a caller can show the caveat in words. With measured solar radiation the same function returns the narrow, better value: that is the place a later solar source plugs in, and a test shows the range tightening when it is given.
2. A rider moves: say in the document how riding speed changes the wet-bulb and globe terms, apply it if the sources support a method, and otherwise state that the estimate is for the air speed given and let the caller pass the apparent wind.
3. `heatWarning(estimate, effort)`: a level (`none`, `caution`, `high`, `extreme`) from published activity thresholds (the ACSM flags the report cites, or a better-sourced scale for recreational cycling and walking if one is found), judged on the **high** end of the range when the sun is estimated, so the warning errs toward care. Each threshold carries its source in a comment.
4. Over an outing: a helper that takes the outing's hours and returns the worst hour's estimate and warning and when it occurs.
5. No place or coordinates are stored or logged anywhere; they pass through the function only.
6. `docs/research/heat-estimate.md`: the candidates and the table, the method chosen and why, its stated error, what the range means in plain words, the thresholds and their sources, what a measured solar value would improve and by how much, and the sentence templates proposed for the screen: a plain note, the number with its caveat ("estimated without sun data"), and the warning at each level. Every claim carries its source link, marked `[read]` when the page itself was fetched and read.

### Prior art
- `jsthermalcomfort` (MIT) has WBGT and related indices but is about 1 MB unpacked and depends on mathjs; `feels` (MIT) has an approximate WBGT and is unmaintained; `thermofeel` (Apache-2.0, Python) is a clean reference for the radiation and globe-temperature estimates; `lwbgt` (Apache-2.0 plus an Argonne notice) is Liljegren's model. Check each one's current state and licence. Use a package directly if it does the job at an acceptable size (measure what it adds to the web export with `npx expo export --platform web` before and after), or port the few formulas needed with the source and licence notice in the file header. Do not write a formula from memory: each one is taken from a named source and tested against that source's own values. GPL and AGPL code is reference only and is not copied.
- The sun's elevation: use skywright if it already computes it; otherwise `suncalc` (BSD-2-Clause, small) or a port of the NOAA solar position equations with their source. Say which and why.
- The heat index stays skywright's `heatIndexC`.

### Commands
One command per Bash call, each check you cite through the evidence runner: `npx jest --runInBand <paths>`, `npm run typecheck`, `npx tsc --noEmit`, `npx expo export --platform web`, `npm install <package>` and `npm ls <package>` (only if a package is adopted), `node`, `git status`, `git diff`, `git log`, `git add`, `git commit`, `git restore --source=<ref> -- <path>`, `git clean -f -- <path>`, `grep`, `ls`, `cat`, `mkdir`. No plain `rm` or `mv`. Scratch files go under `.ws-evidence/scratch/`.

### Done when
`npx jest --runInBand src/recommend/heat.test.ts` and `npm run typecheck` pass; `heat.ts` gives the range, the warning and the outing helper with the tests above (reference cases from the sources, the range tightening with measured solar, night and overcast, thresholds at their edges, no coordinates in any output); `docs/research/heat-estimate.md` holds the comparison and the method; no existing source file is edited; and the result states the method chosen with its measured error, the typical width of the range on a clear summer afternoon, any dependency added with its size, and the list of changes the wiring task must make. Safe to re-run from scratch. Commit after each numbered item.
