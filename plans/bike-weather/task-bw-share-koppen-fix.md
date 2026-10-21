# Fix round: the Köppen asset must not be able to break the Today screen

Track: light

From the review of `agent/bw-share-koppen` at f334a3d.

1. `src/suggest/suggestion.ts:447`: `loadKoppenZone()` sits in the same `Promise.all` as the forecast, so an asset that fails to load turns the whole Today suggestion into an error. The zone is optional on a rating: when the asset fails to load, the suggestion and the rating go on without a zone, and the failure is logged once (`console.warn`). Test that a failing `loadKoppenZone` still gives a suggestion whose rating has country and band but no zone.
2. `src/region/koppenAsset.ts:12`: add a test that mocks `Asset` and `File` / `fetch` and checks that the bytes reach `koppenLookup` on both paths, and that a failed load resets `loading` so a later call tries again.
3. `src/region/region.ts:26` (or wherever the comment names the scheme): cite Beck et al. 2023, as the grid and the credit do.
4. `src/region/koppen.test.ts:80`: replace the duplicate 180°E case with a land point at 179.95°E in the far north-east, read from the `.u8` in `.ws-evidence/`.

## Prior art
Not a build: fixes on this branch.

## Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `node *`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`.

## Done when
- Items 1–4 are done, with the tests named there.
- `npm run typecheck` passes, and the jest files for `src/region/`, `src/suggest/` and `src/screens/today/` pass with `--runInBand`.
