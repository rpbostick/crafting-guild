# Bike Weather: product plan

**In flight right now**
Nothing for Bike Weather itself yet. Milestone 1 (the tools) is running: skywright steps 1-3 and figurewright's spike and port, dispatched 2026-09-27 19:00 MDT; see `plans/skywright/plan.md` and `plans/figurewright/plan.md`. The Bike Weather skeleton (Expo app) waits until both tools are satisfactory.

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

## Orchestrator defaults (not objected to)
- Weather goes through a provider interface. Open-Meteo's free tier while building (non-commercial only); choose a commercial provider (Open-Meteo paid, WeatherKit, OpenWeather) before launch.
- Recommendation: rules comparing garment warmth ratings against feels-like temperature (wind chill at riding speed in ride mode), plus a learned per-user hot/cold offset from comfort ratings.
- Data model from day one: garments carry warmth/wind/water ratings and optional brand/model; each comfort rating is stored with the conditions and the outfit worn.

## Milestones
1. **Tools satisfactory** (separate projects): the weather library + demo app; the body/garment tool + demo app.
2. **Bike Weather core loop**: avatar builder, clothing library from garment templates with ratings, today's forecast, suggested outfit on the avatar in ride/everyday mode, comfort rating, export/import.
3. **Trips, tiers and purchases**: multi-day, multi-place trips with a packing list; free/paid gating; in-app purchase.
4. Later: poses (riding), opt-in data contribution, partner products, commercial weather provider, store release.
