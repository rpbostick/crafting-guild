# Bike Weather: drop the undrawn heat index and finish the carried sharing suggestions

Track: light

Three small debts left by the heat-index and sharing work. Each is a separate change with its own test.

## What to build

1. **The undrawn `heatIndexC`.** `src/recommend/need.ts` computes a Rothfusz heat index into `Need['heat'].heatIndexC` (line ~240) and `src/suggest/suggestion.ts` copies it into `HeatView.heatIndexC` (lines ~106 and ~284). Nothing draws that field: Today's heat notice draws `HeatView.indexes` (`src/screens/today/HeatIndexList.tsx`) and the WBGT fields. The app should not carry a second heat-index value beside `src/recommend/heatIndexes.ts`.
   - Remove `heatIndexC` from `Need['heat']`, from the computation in `outingHeat`, and from `HeatView` and its assignment. Drop the now-unused imports (`heatIndexC`, and `HEAT_INDEX_MIN_TEMP_C` if nothing else uses it).
   - Keep `src/weather/sky/comfort.ts`'s `heatIndexC`: `apparentTemperatureC` uses it for the "feels like" value and it is skywright's code, not a duplicate in the app's own feature set.
   - Update the assertions that only existed for that field (`src/recommend/need.test.ts` ~162 and ~166, `src/recommend/examples.test.ts` ~233, `src/suggest/suggestion.test.ts` ~274). Keep each test meaningful: if the test has other assertions, delete only the removed one; if the test exists only for this field, delete the test.
2. **The native crypto test.** `src/share/nativeShareCrypto.test.ts:22` ("native platforms use the native path") passes even if `shareCryptoFor` returned the web path, because Jest provides `globalThis.crypto`. Clear `globalThis.crypto` for the body of that test (restore it in `finally`, as the web test already does) and, if useful, assert the native object's identity or a distinguishing property, so the test fails if the wrong implementation is chosen.
3. **A hung upload.** `src/share/shareQueue.ts` (~257) calls `fetch` with no timeout: a fetch that never settles keeps the item's outcome unrecorded until the app restarts. Give the POST an `AbortController` with a timeout (30 s is reasonable; name it as a constant) and clear the timer in `finally`. An abort must take the existing `kept` path, with a problem string, so the queue stays and is retried next time. Test it with fake timers and a fetch that never settles, and check the returned result and that the stored queue is intact.
4. **A rating held while the setting loads.** `src/screens/today/RatingPanel.tsx:30` keeps `unshared` in component state; an unmount before the setting arrives drops those ratings without a warning. Keep the hold in a ref (or lift it to the provider) so it survives an unmount-and-remount of the panel, and test that a rating saved while the setting is loading is still handed to sharing after the setting arrives and the panel has remounted.
5. **Cleanup when sharing is off at start.** `src/sharing/SharingProvider.tsx:67` calls `stopSharing` only on an on→off change. If that call failed earlier, a queue and secret can stay on the device while sharing is off. When the loaded setting is off at start, also call `stopSharing` (never awaited in a way that blocks the first render) and test it: a provider started with a stored off setting clears the queue and secret.

## Prior art
Nothing new is built here; each item is the fix named in the review of the branch that introduced the code. Read the current modules before changing them.

## Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `node *`, `npx expo export *`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`.

## Leave alone
`src/recommend/heat.ts` (the WBGT advisory and its thresholds), `src/recommend/heatIndexes.ts`, `src/screens/today/HeatIndexList.tsx`, `server/`, and the weather providers. No dependency changes.

## Done when
- `heatIndexC` is gone from `Need['heat']` and `HeatView`, and the tests that covered it are updated or removed as above; no other behaviour changes.
- The native-path test fails if `shareCryptoFor` returns `webShareCrypto` for ios/android (show it by temporarily forcing that in a copy of the test under `.ws-evidence/scratch/`, not in the committed test).
- A fetch that never settles produces `kind: 'kept'` with a problem, the stored queue unchanged, and the timer is cleared; the test uses fake timers.
- A rating saved while the sharing setting is loading is still shared after a remount, and a provider started with sharing off clears the queue and secret; both have tests.
- `npm run typecheck` passes and the jest files you touched pass with `--runInBand`.
- A web export succeeds and the result names what to look at in a preview.
