# Bike Weather: one table of garment types for the wardrobe and the recommender

Two tables describe garment types today and they disagree. `src/model/templates.ts` has 22 templates, one region each (`torso`, `neck`, ...), with provisional ratings and its own layers. `src/recommend/catalog.ts` has the clothing report's 43 types (`docs/research/clothing-weather.md` §3.2) with the regions each covers (`core`, `arms`, ...), the report's layers and default ratings, `packable` and `footwear`; `src/recommend/coverage.ts` maps each template to a catalog entry. So the recommender places garments by one set of layers and the wardrobe model checks outfits by another (a recommended base layer plus T-shirt is two `base` garments to the model and would be refused), a new garment starts with ratings the recommender was not written for (everyday shorts are warmth 0, so jeans win on a hot day), and a gap can name a type the wardrobe cannot add.

This task makes the template table the catalog: one table, in the model, that the wardrobe, the screens and the recommender all read.

Read first: `README.md`, `docs/research/clothing-weather.md` §3.2 and §3.7 (Step 8), all of `src/model/` and `src/recommend/` with their tests, `src/suggest/` (it imports from both), `src/screens/wardrobe/` and its test, `src/wardrobe/WardrobeProvider.tsx`.

## What to build
1. **The regions move to the model.** The six body regions (`core`, `arms`, `legs`, `hands`, `feet`, `head`) become the model's regions; `torso` and `neck` go away (the neck gaiter and scarf cover `head`, as in the catalog). `src/recommend/regions.ts` keeps its helpers and takes the type from the model, so the model never imports from `src/recommend/`.
2. **One table.** `GarmentTemplate` gains `regions` (the set it covers, replacing the single `region`), `packable` and `footwear`, and takes the catalog's layer, modes, label and default ratings. The table holds all 43 catalog types:
   - the 22 existing template ids stay exactly as they are, each taking the fields of the catalog entry `TEMPLATE_COVERAGE` maps it to today (stored garments name these ids, so no stored garment changes and no document migration is needed);
   - the 21 catalog types no template stands for are added under their catalog ids.
   Where an existing id suits more modes than its catalog entry (`shoes` suits both; the catalog's cycling shoes are for riding), the id keeps the modes and the label it has today, so no stored garment drops out of a mode; say in the result which ids this applied to.
   `packable` is a property of the type only; garments do not store it. `catalog.ts`, `TEMPLATE_COVERAGE` and `coverageOf` then have nothing left to do: remove them, or reduce them to what the recommender still needs, so that no id-to-id mapping and no second ratings table remains. Where a template id and its catalog id differed, gap wording and reasons keep reading the same.
3. **One outfit rule.** Two garments cannot share a layer on a region either of them covers. `assertLayersFit` (model) and the recommender's place rule in `wearability.ts` use one function for this, so an outfit the recommender suggests is always one the model accepts. Add a test that every worked example's suggested outfit passes `assertLayersFit`. The carried garments stay under the same rule as today; do not change that.
4. **A garment's own ratings stay its own.** Stored garments keep the ratings they have. `newGarment` and the starter wardrobe start from the report's defaults. Check `starterWardrobe` for both modes still gives a wardrobe the recommender can dress from on a mild dry day (a test), changing its rows only if it cannot.
5. **Stored documents still load.** A test loads a version 1 wardrobe document holding one garment of each of the 22 existing template ids, an outfit and a comfort rating, and gets them back unchanged. The schema version does not change.
6. **The wardrobe screens** list and pick by the new regions: sections in body order (head, body, arms, hands, legs, feet), a garment under the first region it covers, so a jacket covering body and arms appears once, under body. The picker offers all types that suit the mode, grouped the same way; the editor's subtitle names every region the type covers ("Body and arms"). One word table for region names serves the screens and the recommender's sentences (`regionWords.ts` and `regions.ts` each have one today). Screen-reader hints follow the new words.
7. **README**: the model section and step 3 of "How a recommendation is made" describe the one table; remove what no longer holds.

## Also fix in the files this touches (from earlier reviews of this code)
- `src/recommend/recommend.ts`: `!score.items.includes(item)` compares object identity, so a saved outfit's own garments are not excluded from the owned closers; compare by id, with a test.
- `src/recommend/search.ts`: `choiceBound` counts a garment covering two regions once per region, so ordinary wardrobes fall to the approximate search early; count such a garment once, with a test at the boundary.
- `src/recommend/examples.test.ts`: `inGroup` re-implements `itemsInGroup` from `score.ts`; import the real one.
- `src/recommend/recommend.test.ts`: in "ranks saved outfits by the same score a suggestion gets" only the order assertion can fail, and "uses only the garments whose template suits the mode" passes without the filter but for an id tie-break; give the coat a strictly better score so the mode filter is what the test pins.
- A new test: a hot dry everyday outing with new garments (shorts and trousers both owned) suggests the shorts.
- `src/recommend/defaults.ts` header: `GAP_SUGGESTS` and `HEAT_SHOWN_AS` only mark where a decision lands; say that rather than "the decision changes one line".
- `src/recommend/fixtures/forecasts.ts`: the `FIXTURE_DAY` docstring describes `fixtureTime`; the `WARMING_CALM` docstring reads as history. Give each the reason it exists.
- `src/screens/wardrobe/WardrobeScreen.tsx`: `garments ?? []` in the picker path can never take the fallback; drop it. `GarmentEditor.tsx`: the `remove` docstring promises a sentence fit to show the user, but only `GarmentInUseError` is worded; word the other failures for the user or narrow the docstring.
- Docstrings that only restate a name and signature (`rankSaved`, `rankSavedOutfits`, `garmentsForMode`, `sameGarments`): trim when touched.

## Leave alone
`src/weather/`, `src/screens/TodayScreen.tsx`, `src/app/`, the comfort rating's stored shape, the document's schema version, and what `src/suggest/` returns (edit it only where an import or a type it uses has moved). Effort on ratings and the Today screen are the next task.

## Prior art
- The clothing report's §3.2 catalog, already in the repo as `src/recommend/catalog.ts`, is the table being adopted; nothing new is designed here.
- No library is needed: the table and the rule are plain data and plain functions, as the model already is. No new dependency.

## Commands
One command per Bash call, each check you cite through the evidence runner: `npx jest --runInBand <paths>`, `npm test`, `npm run typecheck`, `npx tsc --noEmit`, `npx expo export --platform web` (to prove the app still bundles; its output directory is ignored, do not commit it), `git status`, `git diff`, `git log`, `git add`, `git commit`, `git mv`, `git rm`, `git restore --source=<ref> -- <path>`, `git clean -f -- <path>`, `grep`, `ls`, `cat`, `mkdir`. No installs, no plain `rm` or `mv`.

## Done when
`npm test && npm run typecheck` pass and the web export builds; one table of 43 garment types in `src/model/` is the only source of regions, layers, default ratings, `packable` and `footwear`; no file names the `torso` or `neck` region; the tests above exist; the README matches; and the result states the number of tests with the log it comes from (the whole suite), every existing test whose expectation changed and why (new default ratings and layers will move some expected outfits: say which and that each new outfit is the method's answer, not a loosened assertion), and the section titles and one editor subtitle exactly as the wardrobe screen now shows them.

Safe to re-run from scratch. Commit after each numbered item so whatever is committed is whole.
