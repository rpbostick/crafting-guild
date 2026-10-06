# Bike Weather: effort on comfort ratings, names for saved outfits, and heat in the suggestion (no screen yet)

The Today view-model (`src/suggest/`) is ready for a screen except for four things the screen would get wrong today: a comfort rating stores no effort, so a hard ride rated just right teaches the app the rider runs warm; a saved outfit has no name; heat is a heat-index note where an estimated WBGT with its uncertainty is wanted; and a few failure cases are worded wrongly. This task fixes them in the model and the view-model, so the screen task after it is layout only.

Read first: `README.md`, all of `src/model/`, `src/recommend/` (especially `learn.ts`, `need.ts`, `reasons.ts`, `defaults.ts`, and `heat.ts` with `docs/research/heat-estimate.md`), all of `src/suggest/`, `docs/research/clothing-weather.md` §3.3 to §3.7.

## What to build
1. **Effort on a rating.** `Effort` (easy, moderate, hard) moves to the model so the model does not import from `src/recommend/`. A `ride` comfort rating stores the effort of the outing it was given for; an `everyday` rating stores none. `rateOutfit` takes it from the outing. `learn.ts` reads each rating at its own effort; a rating with no effort recorded is read at moderate, as now. Test: three just-right ratings of hard rides at a band's midpoint leave the learned offset at zero (today they move it by about -1.5 °C), and the same for easy rides.
2. **A name on a saved outfit.** `Outfit` gains an optional `name`: trimmed, not empty when present, at most 60 characters. Wherever a saved outfit is shown by the view-model it has a `title`: its name, or its garments as today when it has none.
3. **A suggested name.** `suggestedOutfitName(...)` builds a name from the conditions the outfit was chosen for and the mode, in the app's plain voice ("Cool showery ride", "Cold dry walk"): temperature word from the need's band, then rain, then wind only when it is the notable thing. When a saved outfit already has that name (compared without regard to case), the next free number is appended ("Cool showery ride 2", then 3). The ready suggestion carries the suggested name for saving what it shows, with exactly the garment ids to save. Tests cover each temperature word's edges, the numbering (including a gap: with "X" and "X 3" saved the next is "X 2"), and that a user's own name is never changed.
4. **The stored document is version 2.** The step from version 1 changes no record (effort and name are both optional in what is read); a version 1 document still loads and is written back as version 2; an export from this version is refused by nothing in this code that reads version 2. `describeExport` is unchanged. Tests: a version 1 document with garments, an outfit and ratings loads unchanged; a version 2 document with an effort and a name round-trips through export and import, `replace` and `merge`.
5. **A rating matches its saved outfit.** `suggestToday` hands out a rating for the garments worn, not those carried; a saved outfit that includes a carried garment is then not recognised as the outfit rated (`sameGarments` in `recommend.ts`) and never earns `provenHere`. Match a rating to a saved outfit on its worn garments, or carry the saved outfit's id on the rating; choose the smaller change and test it.
6. **Heat.** Replace the heat-index note with the estimate from `src/recommend/heat.ts`, following the list of changes its document gives for wiring: the worst hour of the outing, the WBGT as a range with its best value, the basis (estimated or measured sun), and the warning level for the outing's effort. The sentences (in `reasons.ts` or `words.ts`, one place): a plain note in the app's voice; the number with its caveat stated every time it is shown ("estimated without sun data; it could be a few degrees either way" in the document's own measured terms, not these words); and a clear warning at the higher levels that says what to do. The ready suggestion exposes heat as its own field (level, the sentences, the numbers), not only inside the notes list, so a screen can give it weight. The heat index stays available as a number for the note. `HEAT_SHOWN_AS` goes away if nothing reads it. Tests at each warning level, at night, and with a measured solar value.
7. **Failure cases** (`suggestion.ts`): every `WeatherError` that is not `network` or a listed HTTP status falls through to "an app update is needed" with no retry; match the refusal kinds positively and treat the rest as retryable, with tests for an `http` error with no status and an unknown kind.
8. **Small things in the files this touches:** `offsetMsOfTime` (`outing.ts`) is a second UTC-offset parser beside `LOCAL_TIME` in `src/ui/format.ts`: share one. `capitalised` and the rain-class words exist in both `words.ts` and `reasons.ts`: export one of each. The comment at `outing.ts` justifying the throw ("the forecast is fetched for today from midnight") holds for one provider only; give the reason that covers both.
9. **README**: the model and suggestion sections describe effort, names, the version 2 document and the heat estimate.

## Leave alone
`src/screens/`, `src/app/`, `src/weather/`, the garment template table and the outfit layer rule, and whether a carried garment may share a layer with a worn one (it may not, as now).

## Privacy rules
No place or coordinates in anything stored, exported or logged; the heat estimate receives them and returns none.

## Prior art
- `src/recommend/heat.ts` and its document supply the heat method; nothing here re-derives it.
- The migration mechanism is `migrateDocument` in `src/model/document.ts`; use it as it is.
- No new dependency. Date and duration helpers stay hand-written only where `src/ui/format.ts` already has the pattern; do not add a second one.

## Commands
One command per Bash call, each check you cite through the evidence runner: `npx jest --runInBand <paths>`, `npm test`, `npm run typecheck`, `npx tsc --noEmit`, `git status`, `git diff`, `git log`, `git add`, `git commit`, `git mv`, `git rm`, `git restore --source=<ref> -- <path>`, `git clean -f -- <path>`, `grep`, `ls`, `cat`, `mkdir`. No installs, no plain `rm` or `mv`.

## Done when
`npm test && npm run typecheck` pass; the tests named above exist; the README matches; and the result states the number of tests with the log it comes from (the whole suite), three suggested names and three heat sentences (one per shown level) exactly as a screen would show them, and anything in `heat.ts`'s wiring list that was not done and why. Safe to re-run from scratch. Commit after each numbered item.
