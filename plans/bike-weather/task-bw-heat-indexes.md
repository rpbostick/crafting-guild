# Heat indexes beside the heat advisory, each with a link to read about it

Track: light

The heat advisory (WBGT, `src/recommend/heat.ts`) stays exactly as it is. Next to it, Today shows three widely known heat indexes, plus Japan's names for the WBGT the app already computes, for the same hour the advisory is judged on (the outing's worst hour, `worstHeatOfOuting`), each with its value, its publisher's category name, one plain sentence on what it measures, and a link to the publisher's page. People in different countries know different ones; the app does not pick a winner.

## What to build
1. `src/recommend/heatIndexes.ts`, pure functions with no React Native imports:
   - **NWS Heat Index** (US National Weather Service), from air temperature and relative humidity: the simple formula, then the Rothfusz regression when that result is 80 °F or more, with the low-humidity and high-humidity adjustments, exactly as https://www.wpc.ncep.noaa.gov/html/heatindex_equation.shtml gives them. Read that page's wording on the simple branch yourself and say in the result how you read "averaged with the temperature". Bands (°F): Caution 80–90, Extreme Caution 90–103, Danger 103–124, Extreme Danger 125 and over (https://www.weather.gov/ama/heatindex); below 80, no band.
   - **Humidex** (Environment and Climate Change Canada), from air temperature and dew point: `T + 0.5555 × (e − 10)`, `e = 6.11 × exp(5417.7530 × (1/273.15 − 1/Td_K))`. ECCC shows it only when T ≥ 20 °C and it is at least 1° above T; outside that, no value. Bands (°C): 20–29 little or no discomfort, 30–39 some discomfort, 40–45 great discomfort, avoid exertion, above 45 dangerous.
   - **Apparent Temperature** (Australian Bureau of Meteorology, Steadman 1994), the version without radiation that BoM publishes: `AT = T + 0.33e − 0.70·ws − 4.00`, e in hPa from RH, ws in m/s at 10 m. No bands (BoM publishes none); show the value as "feels like".
   - Each returns `{ value, unit, band?, shown: boolean }` in the caller's units (metric or imperial, `Units` from `src/settings.ts`).
2. On Today, under the heat notice (`src/screens/today/HeatNotice.tsx` or a sibling component it renders), a compact list: index name, value, band name when there is one, one sentence, and a "Read about it" link that opens the page in the browser (`Linking.openURL`). Links: NWS https://www.weather.gov/ama/heatindex, Humidex https://climate.weather.gc.ca/glossary_e.html, Apparent Temperature http://www.bom.gov.au/info/thermal_stress/. An index with no value at that hour says why in a few words ("only above 20 °C"). The colour is never the only sign of a band.
3. **Japan's WBGT bands**, as a fourth line: the WBGT the app already computes (the advisory's value, `judgedWbgtC`), named by the Ministry of the Environment's exercise guideline: below 21 °C almost safe, 21–25 caution, 25–28 warning, 28–31 severe warning (heavy exercise prohibited), 31 and over danger (exercise prohibited). Link https://www.wbgt.env.go.jp/en/. This only names the existing value; it does not change the advisory.
4. Do not use Open-Meteo's `apparent_temperature` as BoM's value: it uses a different formula (wind cut to 2 m, a radiation term). Compute ours from the hourly inputs.

## Prior art
ECMWF thermofeel (Apache-2.0) implements all three and is the reference used to check them; jsthermalcomfort (MIT, npm) has the BoM formula as `at()`, but its heat index skips the NWS simple step and adjustments and its humidex uses humidity rather than ECCC's dew-point form, so the three are written here (about 15 lines each) against the agencies' own pages. Avoid GPL packages (weather-formulas, comfort-models).

## Test values (checked by hand against the formulas)
- Heat Index: 90 °F, 60% → 99.7; 100 °F, 40% → 109.3; 96 °F, 10% (low-humidity adjustment) → 90.4; 85 °F, 90% (high-humidity adjustment) → 101.8. NWS's chart rounds the first two to 100 and 109.
- Humidex: 30 °C, dew point 15 °C → 34.0; 30 °C, dew point 25 °C → 42.4.
- Apparent Temperature: 25 °C, 30%, 0.1 m/s → 24.1.
- Band edges for each banded index, both sides of each edge (Japan's WBGT bands too: 20.9 / 21.0, 24.9 / 25.0, 27.9 / 28.0, 30.9 / 31.0).

## Commands
`npx jest *`, `npx tsc *`, `npm run typecheck`, `node *`, `npx expo export *`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`.

## Leave alone
`src/recommend/heat.ts` (the WBGT and its thresholds), `src/screens/SettingsScreen.tsx`, `server/`, `src/share/`, `src/avatar/`.

## Done when
- The three functions pass the test values above and their band edges, and return no value outside each index's stated range.
- Today shows the four lines under the heat notice for the outing's worst hour, in the user's units, each with its link (component test, including an hour where Humidex has no value).
- The heat advisory's own tests are unchanged and pass.
- `npm run typecheck` passes; the jest files you touched pass with `--runInBand`.
- A web export succeeds; the result names what to look at in a preview (a warm humid hour, a mild dry one, imperial units).

## Carried from the bw-share-upload review (suggestions; do them where the code is yours to touch)
- `src/share/nativeShareCrypto.test.ts:22`: Rule 2/3: 'native platforms use the native path' only checks the HMAC result. Under Jest, globalThis.crypto exists, so the test would still pass if shareCryptoFor returned webShareCrypto for ios/android. On Hermes that mistake would make every share fail with only a warning. Clear globalThis.crypto in this test, as the web test already does, so it proves the native path is taken.
- `src/screens/today/RatingPanel.tsx:30`: Ratings held in `unshared` while the setting loads live in component state. If the panel unmounts before the setting arrives (for example the outing changes), they are dropped without a warning. This is unlikely since the setting loads fast; a ref or a provider-level hold would close the gap.
- `src/sharing/SharingProvider.tsx:67`: stopSharing runs only on an on→off transition. If it fails (ratingUploads only warns), a queue and secret stay on the device while sharing is off, and nothing cleans them up later. Consider also calling stopSharing on start when the loaded setting is off.
- `src/share/shareQueue.ts:257`: The POST has no timeout or AbortSignal. A fetch that hangs keeps the flush promise open. It does not block the queue's turn, but the outcome is never recorded until the app restarts. Consider an AbortController timeout.
- `.ws-evidence/runs.tsv:12`: Evidence only: the whole-suite red run (before-today-open-handles, killed) and merge-gate-failure.log are not rows in runs.tsv. The only recorded red run is the single-file cold-cache probe. The orchestrator can tidy this.
