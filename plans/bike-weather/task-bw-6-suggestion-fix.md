# Bike Weather fix: a carried rain shell rated as worn, and points from the suggestion's review

Track: light

On this branch only, in `src/suggest/` and the README. Do not edit `src/model/`, `src/screens/`, `src/ui/`, `src/recommend/` or `src/weather/`. Scratch files go under `.ws-evidence/scratch/`, never in the source tree.

## Blocking
`src/suggest/suggestion.ts:261`: `rating.garmentIds` is `score.items`, which includes the garments the same suggestion lists under `carry`, and `rateOutfit` stores them as the outfit worn. `learn.ts` then counts the pocketed rain shell's core warmth, though `score.ts` gives a carried garment none: on the 20 °C rain-possible fixture a just-right rating becomes +4 °C of evidence instead of 0, and three of them would show the user as dressed "2 °C colder". Take `garmentIds` from the garments worn at the cold point (`score.coldWorn`, or expose worn and carried separately and rate the worn ones). Add a test on the rain-possible fixture: the carried shell is not in `rating.garmentIds`, and a just-right rating of that suggestion leaves the offset at 0.

## Also fix
- `suggestion.ts:218`: `isEmptyFor` is false as soon as one garment suits the mode, so a user who took the everyday starter and switches to ride gets a suggestion of shoes, beanie and gloves and is never offered the ride starter. Treat a wardrobe with no core garment or no legs garment for the mode as needing the starter offer (the state can carry what is there), and test it.
- `suggestion.ts:168`: `dressingKey` puts accessories after shells, so the list reads jersey, rain shell, arm warmers. Arm warmers go on before a jacket: order by what goes on first, and test jersey, arm warmers, rain shell.
- `suggestion.ts:139`: every `WeatherError` becomes "No forecast right now… try again". Read the error kinds `src/weather/` and skywright define and map only outage and network errors to that state; a bad request or an unreadable response is a different state with its own sentence.
- `suggestion.test.ts`: add `suggestToday` on the MET Norway fallback alone (`createFakeWeatherService(['open-meteo'])`: a different first hour, no precipitation probability, a different forecast end), and an abort through the fake service with an aborted signal, showing it propagates as an abort and not as forecast-unavailable.
- `words.ts:80`: `rainWhen` reports one span from the first wet step to the last, so two separate showers read as continuous rain; say both. Test its "until" and "from" branches and `windPhrase`'s little-wind branch.
- `words.ts:27` and `outing.ts:36`: `durationText` mis-writes non-whole minutes (59.6 gives "60 minutes", 119.7 gives "1 hour 60 minutes", 0.4 gives nothing): require whole minutes in `validOuting` and make `durationText` correct for every whole number.
- `suggestion.ts:284`: `learnOffsets` runs twice per suggestion; compute it once.
- `rate.ts:13`: the docstring says learning reads the rating at the design temperature the suggestion used; that holds only at moderate effort, since ratings store no effort. Say so.
- `words.ts:1` and `README.md:126`: "every sentence" overstates it: reasons, gaps, warnings and notes come from `src/recommend/reasons.ts`. Say which sentences are here.
- Run the whole suite on the clean tip and name its log and counts in the result.

## Prior art
None needed: this corrects the view-model against the recommender's own rules.

## Commands
One command per Bash call: `npm test`, `npx jest <path>`, `npm run typecheck`, `npx tsc --noEmit`, `git add`, `git commit`, `git status`, `git diff`, `grep`, `ls`, `cat`, `mkdir`.

## Done when
`npm test && npm run typecheck` pass; the carried-shell test is in; the smaller fixes are in with their tests; the change is committed; and the result states the number of tests with the log it comes from.
