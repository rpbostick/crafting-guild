# Fix round 1 for `task-bw-weather-rename.md`

The review of this branch at 11ba9df found blocking issues. Fix each one, with a test where the finding is about behaviour, commit, and re-run the covering test files through ws-run. Do nothing else; suggestions are carried to a later task.

## Blocking findings
- `README.md:224` (rule 3): User-facing doc says a step counts as rain 'above the ride window's 0.1 mm/h dry threshold'. The threshold is DEFAULT_MAX_RATE_MM_PER_HOUR in src/weather/sky/dryWindow.ts, used only by dryWindows(); rideWindow in ride.ts has no dry threshold. Say the dry-window threshold (`DEFAULT_MAX_RATE_MM_PER_HOUR` in `src/weather/sky/dryWindow.ts`).
- `src/recommend/need.ts:105` (rule 3): The comment changed from "skywright's dry-window threshold" (correct) to "the ride window's dry threshold", which is wrong: the constant belongs to dryWindow.ts, not rideWindow. Change it to "the dry-window threshold".
- `src/recommend/need.test.ts:111` (rule 3): Test name credits the 0.1 mm/h dry threshold to the ride window; it is dryWindow.ts's DEFAULT_MAX_RATE_MM_PER_HOUR. Rename the test to match.
- `src/suggest/timeline.test.ts:156` (rule 3): Same false credit in the test name ('above the ride window's dry threshold'). Rename to the dry-window threshold.

## Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `git mv`, `git add`, `git commit`, `grep *`. One command per Bash call. Run jest with `--runInBand`. No installs.

## The original task (for context)
## Rename skywrightService to weatherService

Track: light
Resume: the worktree holds e517d26 (the export and options type renamed). Continue from it.

The weather code now lives in `src/weather/sky/` (copied from skywright). `src/weather/skywrightService.ts` and its `createSkywrightWeatherService` export are the last names that point at the old library; `src/app/index.tsx` and `src/weather/fakeWeatherService.ts` import it.

### What to build
1. `git mv src/weather/skywrightService.ts src/weather/liveWeatherService.ts` (not `weatherService.ts`: it would differ only in case from `WeatherService.ts` and collide on macOS and Windows; it pairs with `fakeWeatherService.ts`); rename the export to `createWeatherService`; update every import and mention (code, tests, README), except `src/weather/sky/SOURCE.md`, `THIRD-PARTY-NOTICES.md` and history notes, which name skywright on purpose.
2. Reword the comments and test names that say "skywright's …" (about 35, in src/recommend, src/suggest, src/ui/format.ts, src/model/comfort.ts, src/screens/TodayScreen.test.tsx, and README.md lines 145-290) to name the code in `./sky` or say what it does. `docs/research/` stays as history.
3. No behaviour changes.

### Prior art
A rename; no library.

### Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `git mv`, `git add`, `git commit`, `grep *`. One command per Bash call. Run jest with `--runInBand`. No installs.

### Leave alone
`src/weather/sky/`, `server/`.

### Done when
- `grep -rn -i skywright src README.md` finds only `src/weather/sky/SOURCE.md`, the sky folder's own files, and lines that describe where the code came from.
- `npm run typecheck` passes; the jest files that import the renamed module pass with `--runInBand`.
