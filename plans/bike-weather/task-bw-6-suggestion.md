# Bike Weather: today's suggestion as a tested view-model (no screen yet)

`src/recommend/` turns a forecast window, a mode and a wardrobe into an outfit with reasons and gaps, ranks saved outfits, and learns a per-mode offset from comfort ratings. `src/weather/` fetches the forecast through `WeatherService`. Nothing joins them yet. This task builds the join as a view-model the Today screen will show, so the screen task is only layout.

Read first: `README.md`, `src/recommend/` (all of it and its tests), `src/weather/` (`WeatherService`, the fake and its fixtures), `src/model/` (store, outfits, comfort ratings), `src/settings.ts`, `src/screens/TodayScreen.tsx` (how it loads a forecast and injects its clock; read only), `docs/research/clothing-weather.md` §3.3 to §3.7, and `docs/research/dark-sky.md`'s closing section on the core loop.

## Where the code goes
A new folder `src/suggest/` and its tests. **Do not edit any existing file under `src/model/`, `src/screens/`, `src/ui/`, `src/recommend/` or `src/weather/`**: other branches are changing some of them, and the rest are settled. Import from all of them freely. If something needed is missing from one of them, do it inside `src/suggest/` and list it in the result as a change to make there later.

## What to build
1. **The outing** (`outing.ts`): what the user is dressing for: mode, start time, length, and for a ride the speed and effort, with defaults (a ride starting now for an hour at the activity's default speed and moderate effort; an everyday outing covering the next few hours of the day). Pure functions that turn an outing and a forecast into the window `src/recommend/` needs, using skywright's ride window; an outing past the end of the forecast says so rather than guessing.
2. **The suggestion** (`suggestion.ts`): `suggestToday({ weather, store, place, outing, now })` loads the forecast and the wardrobe, applies the learned offset from the stored comfort ratings, and returns one plain object for the screen: the conditions the outfit is chosen for in a sentence, in the forecast's plain voice (the coldest and warmest point, the wind the rider will feel, the rain and when); the suggested garments in dressing order, each with its name, colour, region and its reason; what to carry; the gaps as plain sentences; the user's saved outfits for the mode ranked with a one-line verdict each (fits, a little cold on the hands, too warm); and any warnings (cold, heat). Each state the screen must draw is a value, not an exception: loading is the caller's; no place chosen; an empty wardrobe (offer the starter wardrobe); the forecast unavailable (with what is still known); the outing beyond the forecast.
3. **Rating an outfit** (`rate.ts`): `rateOutfit({ store, outfit or garments, level, conditions, now })` builds and stores the `ComfortRating` the model defines, with the conditions taken from the same window the suggestion used (never a place or coordinates), for a suggested outfit and a self-made one alike. A second rating for the same outing is a new rating, not an edit.
4. **Wording** (`words.ts`): the sentences above in one place, plain and specific, no jargon and no exclamation marks; temperatures and speeds through `src/ui/format.ts`.

## Privacy rules
No place, coordinates or measurements in anything stored or logged here; ratings keep conditions only.

## Tests
With the fake weather service and the in-memory store: a cold dry ride, a showery ride, a hot ride and a cold walk each produce the expected outfit, sentence, carried items and gaps; an empty wardrobe, no place, a failed forecast and an outing beyond the forecast each produce their state; saved outfits are ranked and worded; the learned offset changes the suggestion after enough ratings and not before; `rateOutfit` stores a valid rating with no location in it and a second call stores a second rating. `npm test` and `npm run typecheck` pass.

## Prior art
- `src/recommend/` and skywright (already dependencies of this code) do the choosing and the weather maths; nothing here re-derives either.
- No view-model library is needed: plain functions and plain objects, as the model and the recommender already are. State libraries (zustand, MIT; redux toolkit, MIT) were considered and left for the screen task to decide if the screens need shared state.

## Commands
One command per Bash call: `npm test`, `npx jest <path>`, `npm run typecheck`, `npx tsc --noEmit`, `git add`, `git commit`, `git status`, `git diff`, `grep`, `ls`, `cat`, `mkdir`. No installs.

## Done when
`npm test && npm run typecheck` pass; `src/suggest/` holds the outing, the suggestion, rating and wording with the tests above; the README has a short section on it; and the result states the number of tests with the log it comes from (the whole suite), each thing it had to work around because an existing file could not be edited, and three example sentences exactly as the screen would show them. Safe to re-run from scratch.
