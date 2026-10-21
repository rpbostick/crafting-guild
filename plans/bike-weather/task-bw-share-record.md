# Shared rating record: the type, its validation and "what is shared"

Track: light

Step 2 of `plans/bike-weather/ratings-share.md`. Build the record a comfort rating becomes when it is shared. Nothing is uploaded yet and no screen changes; this is the model only. Read `docs/research/ratings-sharing.md`, sections "What a shared rating can carry", "2. Altitude" (Recommendation), "3. Country" (Recommendation) and "4. The 10-contributor scrub" ("What counts as a contributor"). Read by section; don't read the whole report.

## What to build (in `src/model/shared.ts` and its test file)
1. `SharedRating`, versioned (`version: 1`), holding exactly the fields the report's table marks "yes" or "coarsened": the conditions, mode, effort and comfort; each worn garment as `templateId`, `warmth`, `wind`, `water`, plus `brand` and `model` normalised; carried garments the same way with `putOn`; `ratedOn` as the day (`YYYY-MM-DD`, UTC); a fresh random `uploadId` (not the rating's `id`); and `region`.
2. `Region`: `zone?` (a Köppen code such as `Cfb`), `country?` (ISO 3166-1 alpha-2, upper case), `altitudeBand?`. Each part is left out when unknown, never guessed.
   - `altitudeBand(elevationM)`: 500 m bands named by their lower bound (`0`, `500`, `1000`, `1500`), everything at or above 2000 m as `2000+`, below 0 as `0`. Use the forecast's `elevationM`, falling back to the place's; neither gives no band.
   - The zone comes from a lookup passed in, `(lat, lon) => string | undefined`. The Köppen grid is the next task (`bw-share-koppen`); until then callers pass none and the zone is left out.
   - The country is the place's `countryCode` (skywright's geocoder already gives it).
   - The region is worked out when the rating is made and kept on the rating coarse: never store or share latitude and longitude on it. Find where a `ComfortRating` is created and add an optional `region` to `ComfortRating` there, validated in `validComfortRating`. Ratings already stored or imported without one stay valid.
3. Brand and model: `normaliseBrand` / `normaliseModel` map free text to a known list (a `KNOWN_BRANDS` module, case-insensitive, trimmed); anything else becomes `other`. Start the list empty, with a comment saying where entries come from. A model is kept only when its brand is known and the model is on that brand's list.
4. `toSharedRating(rating, garments, random)`: builds the record from a stored rating and the wardrobe's garments; `random` makes the `uploadId` so tests are deterministic. Garment `name`, `color` and `id`, the rating `id`, any place and any time finer than the day are never in the output. A test checks that by serialising the output and asserting none of those values appear in it, over a seeded set of 100+ generated ratings.
5. `validSharedRating(record)`: rejects unknown versions, unknown fields, out-of-range values and malformed region parts. The server will reuse it, so it imports nothing from React Native or Expo.
6. `describeShared(record)`: the "what is shared" text, a short list of plain sentences, one per thing shared, that the Settings preview will show (step 3). Test it against one fixed record.

## Prior art
`src/model/comfort.ts` (`validComfortRating`, `sameComfortRating`) and `src/model/garment.ts` (`validGarment`) are the validation style to follow. `src/model/transfer.ts` is the existing export of one's own ratings, which keeps everything; this record is the reduced one. skywright's `sky-coarse-location` rounds coordinates; we go further and drop them. The contributor key (HMAC of a secret per install) belongs to the upload step, not here.

## Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `node *`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`.

## Leave alone
`src/avatar/`, `src/screens/`, `src/recommend/`.

## Done when
- `SharedRating`, `Region`, `altitudeBand`, the normalisers, `toSharedRating`, `validSharedRating` and `describeShared` exist with tests.
- The seeded test (100+ ratings) shows no garment name, colour or id, rating id, coordinate or time finer than the day in any output, and every output passes `validSharedRating`.
- Ratings without a region still load and import (an existing transfer test still passes).
- `npm run typecheck` passes, and the jest files for `src/model/` pass with `--runInBand` (the merge gate runs the whole suite).
