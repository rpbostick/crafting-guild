# Carried review suggestions: a stale path, three comments

Track: light

Small follow-ups from the reviews of bw-weather-rename and bw-index-followup. No behaviour changes.

## What to build
1. `docs/research/ratings-sharing.md:159` says `searchPlaces` is in `src/weather/skywrightService.ts`, which no longer exists. Point it at the file that now holds it (find it with grep; it should be `src/weather/liveWeatherService.ts`).
2. `src/suggest/outing.ts:31`: the doc comment calls 18 km/h "`RIDING_SPEEDS_KMH`'s for this activity", but the constant used is `DEFAULT_RIDE_ACTIVITY` ('commuting'). Reword it so it says plainly that 18 km/h is the `RIDING_SPEEDS_KMH` speed for the default activity, and check the number against the code.
3. `README.md:291`: "rounded to 0.01° ... by `src/weather/sky/`" names a folder as the actor; say "by the providers in `src/weather/sky/`", matching the comment in `liveWeatherService.ts`.
4. `server/test/queryPlan.test.ts:20`: add a short comment saying the no-unindexed-scan check only catches lines starting `SCAN <table>`, and that a bare `SEARCH ratings` without an index is caught by the first assertion (the one that requires the index name).

## Prior art
None needed: wording only.

## Commands
`grep *`, `npx jest *`, `npx tsc *`, `npm run typecheck`, `npm --prefix server test`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`. No installs.

## Leave alone
Everything else; no code behaviour changes.

## Done when
- `grep -rn skywrightService docs src README.md` finds nothing.
- The three comments read as described, and the numbers they state match the code.
- `npm run typecheck` passes, `npx jest --runInBand src/suggest` passes, and `npm --prefix server test` passes.
