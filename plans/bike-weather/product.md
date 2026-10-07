# Bike Weather: product plan

**In flight right now**
**NOW (2026-10-07 10:25 MDT):** `bw-shelves-followups` merged afc8bcd and pushed. Main holds the Today screen (Shelves default, List), carried garments' when-lines, back up and restore, one `keepsDry`. **Running: the chain** `plans/bike-weather/day.queue`: `bw-timeline-views` (`task-bw-17-timeline-views.md`, $15, **gate**, started 2026-10-07 10:25 MDT): a timeline view-model on the suggestion, two layouts registered as views (Strip, horizontal; Timeline, vertical) after Shelves and List, rain only, carried garments pinned at their put-on step. At the gate: `bin/ws --project bike-weather serve bw-timeline-views 8802`, ask to open in Firefox, he looks at both and may drop one; merge after his OK. Carry forward: rewrap README line 232; the two picker focus tests as one `it.each`. **Next to plan:** the avatar on the Today screen (depends on figurewright's body), export and import of ratings for the research opt-in (daytime talk first), temperature on the timeline later. **Decided by Patrick 2026-10-06 and 07:** shelves first; both timeline layouts as registry views over one view-model, rain only (2026-10-07 10:25 MDT, after a cost estimate: about $12 for both against $8 for one); the level-none heat line hides below the caution edge minus 3 °C; the export lists counts and one line per kind; the research-pooling opt-in waits for a talk; the List view keeps the reason; reviewer Opus for light branches (2.3.5). Older blocks are in `in-flight-history.md`.**
(Older blocks are in `in-flight-history.md`.)

## Requirements (operator, 2026-09-27)
- A closed-source, paid app for the iOS and Android app stores. Working title "Bike Weather".
- The user builds an avatar of themselves and a library of their real clothing. The app reads the forecast and suggests a weather-appropriate outfit, shown on the avatar. It also plans clothing for trips.
- Two modes from the start: **ride** (cycling: ride length, time of day, wind chill at riding speed, rain; cycling gear) and **everyday**.
- Tiers: a free version with usable functionality, an inexpensive paid version (more item slots, outfits, options), possibly a premium version later.
- Data lives on the device at first, with export/import.
- A comfort feedback loop: the user rates how an outfit felt, and recommendations adjust to that user.
- Longer-term goals: ethically gathered (opt-in, anonymised) real-world clothing and comfort data, useful to researchers, clothing makers and vendors; tasteful partnerships with manufacturers and sellers (suggest suitable products, collect product feedback). Nothing leaves the device without opt-in.

- **Direction (Patrick, 2026-10-05):** position Bike Weather as a premier, high-quality weather app with fun features that add to the experience, engagement and joy of using it. Develop expertise in improving human comfort in the weather, and build the business from that expertise and its solutions. The finished core: the app recommends outfits and the user builds their own; both converge on weather-appropriate outfits, on top of good weather data.

## Decisions (operator, 2026-09-27)
| Question | Decision |
|---|---|
| Stack | Expo / React Native, TypeScript, iOS + Android. Expo web for previews on :8801. |
| Audience | Cyclists and everyday users, both from the start. |
| Garment art | Parametric garments generated in code, after a spike. An illustrator later, depending on how well the app sells. |
| Body | Body **shapes** (builds) in one standing pose now; poses (e.g. riding) later. Every garment fits every shape. |
| Data | On the device, with export/import. Sync later, if ever. |
| Structure | Two **standalone open-source tools** (MIT), each its own repo and workspace project, released separately; Bike Weather consumes them as packages. |
| Body tool scope | Open: body shapes, colorwright's head parts (ported), the garment layering engine, basic parametric garments (tee, long sleeve, jacket, pants, shorts, shoes). Closed in Bike Weather: the full cycling/everyday catalog, warmth/wind/water ratings, recommendation engine, comfort data. |
| colorwright | The body tool is a new project that copies colorwright's head/hair/face/hat/accessory SVGs (Open Peeps, CC0) and ports its slot, colour-role and draw-order logic. colorwright is unchanged. Store listings must not use the Open Peeps name. |
| Order | Both tools in parallel; Bike Weather after both are satisfactory. Milestone 1 is the core loop. |

- 2026-09-28: the app may become multi-activity ("Hike Weather" or broader); the name waits on SEO research. No riding pose for now: cycling clothes on the regular pose.

## Orchestrator defaults (not objected to)
- Weather goes through a provider interface. Open-Meteo's free tier while building (non-commercial only); choose a commercial provider (Open-Meteo paid, WeatherKit, OpenWeather) before launch.
- Recommendation: rules comparing garment warmth ratings against feels-like temperature (wind chill at riding speed in ride mode), plus a learned per-user hot/cold offset from comfort ratings.
- Data model from day one: garments carry warmth/wind/water ratings and optional brand/model; each comfort rating is stored with the conditions and the outfit worn.

- `projects/bike-weather.conf` has no `TEST_CMD`, `EXTRA_TOOLS` or `PREVIEW_CMD` yet (the repo is one README commit). The skeleton task sets up Jest and typecheck; set all three in the conf in the same step, before its merge, so no Bike Weather merge pushes without a gate.

## Privacy (audit, 2026-10-01)
- **Protect:** the user's location (GPS fix, home and commute), body measurements (height, chest, waist, hips), clothing library and comfort ratings, and trip plans (where and when they will be away from home). Later, the commercial weather provider's API key.
- **Collect:** nothing on a server. Everything stays on the device; export is a file the user makes. Third parties receive only what a forecast needs: coordinates (weather provider) and place-search text (geocoder), plus the device's IP address.
- **Expose:** each forecast request to the provider; the export file (plain JSON); skywright and figurewright once public (no keys, no personal data in history: `release-audit.md`); any API key shipped in the app bundle is extractable.
- **Misuse:** exact coordinates logged by a provider reveal a home and daily ride times; a leaked export joins body measurements, home and trip dates (an empty house); an extracted key runs up the bill.
- **Rules for the build:** coordinates leave the device rounded to 0.01° (skywright, `sky-coarse-location`); never log coordinates or measurements; the export carries no location history unless the user includes it, and the app says what is in it; the paid provider's key goes through a proxy or a restricted key before launch, never a bare key in the bundle; ask for "while using" location only, and allow a typed place instead.

- 2026-10-01: provider research merged (`docs/research/weather-providers.md`, 755f1ae). Recommends **Open-Meteo commercial behind a small Bike Weather proxy**, WeatherKit REST as fallback; OpenWeather out on cost, Tomorrow.io on terms/privacy. Open for Patrick, after the Dark Sky report: who runs the proxy; iOS-only or both at launch; confirm Open-Meteo prices. Review suggestions for a revision: hourly horizon per provider in the table (OpenWeather 48 h, MET Norway 6-hourly later), state the privacy rule in the doc, WeatherKit's cache limit next to the recommendation, link skywright's files by commit.

## Decisions (Patrick, 2026-10-01, after the provider and Dark Sky reports)
| Question | Decision |
|---|---|
| Core loop | **All of the Dark Sky list** (`docs/research/dark-sky.md`, closing): one-screen timeline (next hour by the minute where available, 24 h, week) in Dark Sky's plain voice; dry-window finder / "leave by" for a ride length; outfit from the worst conditions of the ride window; headwind/tailwind between saved places; opt-in rain alerts for saved rides. |
| Server features | **Every server-backed feature has a no-server fallback**, so costs stay low early and the app works when the server is unreachable. Proxy down → the app calls a keyless provider directly (MET Norway, CC BY, User-Agent only; coordinates still rounded to 0.01°). Alerts without a server → on-device background fetch with local notifications for saved rides (less timely, OS-throttled). Minute rain unavailable → hourly timeline with the dry-window finder on hourly data. The UI says which mode it is in. |
| Minute-level nowcast source | Decide later (Rainbow.ai vs WeatherKit next hour vs own MRMS/OPERA nowcast); build the timeline so the minute layer is optional. |
| Platforms | iOS and Android at launch (WeatherKit, if used, through the proxy's REST signing). |
| Server | Serverless (e.g. Cloudflare Workers): forecast proxy (key out of the app, no IP to provider, shared 0.01°-cell cache, no client IP logging), later alert checks. |
| Provider | Open-Meteo commercial behind the proxy (report recommendation); WeatherKit REST as fallback; confirm prices at signup. |

- **Minute-weather access** (Patrick, 2026-10-01, ideas for tiers): (a) a user can enter **their own API key** for a minute-level provider in settings, stored only on the device and used directly from the phone, so minute rain works with no Bike Weather server or cost; (b) a **small subscription (about $1/month)** unlocks minute-level weather through Bike Weather's proxy and its paid nowcast source. Both fit the "minute layer is optional" design; (b) belongs with milestone 3's tiers and in-app purchase. Check each candidate provider's terms for end-user keys before offering (a).

## Milestones
1. **Tools satisfactory** (separate projects): the weather library + demo app; the body/garment tool + demo app.
2. **Bike Weather core loop**: avatar builder, clothing library from garment templates with ratings, today's forecast, suggested outfit on the avatar in ride/everyday mode, comfort rating, export/import. Closing this milestone includes publishing skywright (its plan's step 7) and asking Patrick about figurewright's release.
3. **Trips, tiers and purchases**: multi-day, multi-place trips with a packing list; free/paid gating; in-app purchase.
4. Later: poses (riding), opt-in data contribution, partner products, commercial weather provider, store release.

## Machine
- 2026-09-27: Patrick: use a current Node ("no sense building on outdated"). Switched at 21:40 MDT: `~/.local/node` → `node-v24.21.0` (LTS; old kept at `~/.local/node-v20.17.0`). node_modules reinstalled in skywright, skywright/example, figurewright; all suites green (skywright 158, figurewright 1405), no engine warnings.

- 2026-09-28: clothing layers like real clothing (underwear to coat, hats, snowpants, gloves); several colour-coded garments at once with lower layers visible; add/remove layers in order; later a get-dressed / undress / layer animation with garments exploding out like FreeCell. figurewright's compose step must expose per-garment groups and an exploded layout (see `plans/figurewright/plan.md`, Requirements).
- 2026-09-28: private repos on GitHub for figurewright, skywright and bike-weather (merges push). The cycling hot-weather comfort model (wind and sweat cooling at speed) lives in Bike Weather's recommendation engine.
