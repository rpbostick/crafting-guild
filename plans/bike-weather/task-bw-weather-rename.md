# Rename skywrightService to weatherService

Track: light

The weather code now lives in `src/weather/sky/` (copied from skywright). `src/weather/skywrightService.ts` and its `createSkywrightWeatherService` export are the last names that point at the old library; `src/app/index.tsx` and `src/weather/fakeWeatherService.ts` import it.

## What to build
1. `git mv src/weather/skywrightService.ts src/weather/weatherService.ts`; rename the export to `createWeatherService`; update every import and mention (code, tests, README), except `src/weather/sky/SOURCE.md`, `THIRD-PARTY-NOTICES.md` and history notes, which name skywright on purpose.
2. No behaviour changes.

## Prior art
A rename; no library.

## Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `git mv`, `git add`, `git commit`, `grep *`. One command per Bash call. Run jest with `--runInBand`. No installs.

## Leave alone
`src/weather/sky/`, `server/`.

## Done when
- `grep -rn -i skywright src README.md` finds only `src/weather/sky/SOURCE.md`, the sky folder's own files, and lines that describe where the code came from.
- `npm run typecheck` passes; the jest files that import the renamed module pass with `--runInBand`.
