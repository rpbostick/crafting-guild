# Bike Weather: product plan

**In flight right now**
Nothing for Bike Weather itself yet. Milestone 1: skywright is done (steps 1-6 merged 2026-09-28); figurewright is at step B2 (`fw-dress`). The Bike Weather skeleton waits until figurewright is satisfactory. **Release gate:** skywright is published to npm only after Bike Weather's core loop uses it (skywright plan step 7).

## Requirements (operator, 2026-09-27)
- A closed-source, paid app for the iOS and Android app stores. Working title "Bike Weather".
- The user builds an avatar of themselves and a library of their real clothing. The app reads the forecast and suggests a weather-appropriate outfit, shown on the avatar. It also plans clothing for trips.
- Two modes from the start: **ride** (cycling: ride length, time of day, wind chill at riding speed, rain; cycling gear) and **everyday**.
- Tiers: a free version with usable functionality, an inexpensive paid version (more item slots, outfits, options), possibly a premium version later.
- Data lives on the device at first, with export/import.
- A comfort feedback loop: the user rates how an outfit felt, and recommendations adjust to that user.
- Longer-term goals: ethically gathered (opt-in, anonymised) real-world clothing and comfort data, useful to researchers, clothing makers and vendors; tasteful partnerships with manufacturers and sellers (suggest suitable products, collect product feedback). Nothing leaves the device without opt-in.

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

## Milestones
1. **Tools satisfactory** (separate projects): the weather library + demo app; the body/garment tool + demo app.
2. **Bike Weather core loop**: avatar builder, clothing library from garment templates with ratings, today's forecast, suggested outfit on the avatar in ride/everyday mode, comfort rating, export/import. Closing this milestone includes publishing skywright (its plan's step 7) and asking Patrick about figurewright's release.
3. **Trips, tiers and purchases**: multi-day, multi-place trips with a packing list; free/paid gating; in-app purchase.
4. Later: poses (riding), opt-in data contribution, partner products, commercial weather provider, store release.

## Machine
- 2026-09-27: Patrick: use a current Node ("no sense building on outdated"). Switched at 21:40 MDT: `~/.local/node` → `node-v24.21.0` (LTS; old kept at `~/.local/node-v20.17.0`). node_modules reinstalled in skywright, skywright/example, figurewright; all suites green (skywright 158, figurewright 1405), no engine warnings.

- 2026-09-28: clothing layers like real clothing (underwear to coat, hats, snowpants, gloves); several colour-coded garments at once with lower layers visible; add/remove layers in order; later a get-dressed / undress / layer animation with garments exploding out like FreeCell. figurewright's compose step must expose per-garment groups and an exploded layout (see `plans/figurewright/plan.md`, Requirements).
- 2026-09-28: private repos on GitHub for figurewright, skywright and bike-weather (merges push). The cycling hot-weather comfort model (wind and sweat cooling at speed) lives in Bike Weather's recommendation engine.
