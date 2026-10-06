# Resume after the usage limit

An earlier run of this task stopped at the usage limit without writing a result. Run `git status` and `git log --oneline main..` first, read the uncommitted files that are there, keep what is sound, commit it, and finish the task below.

## Bike Weather research: what to wear for the weather, and how to recommend it (research only, no code)

Bike Weather suggests an outfit from the user's own wardrobe for the forecast, in two modes: **ride** (cycling: effort, riding speed and its wind, ride length) and **everyday** (walking about). The user can also build their own outfits and rate how each felt (too cold … too warm); recommendations and the user's own outfits should both converge on what suits the weather for that person. Forecasts come from the skywright library (temperature, feels-like, wind speed and direction, precipitation by hour and, where available, by 15 minutes, cloud and condition). This report gives the recommendation engine its footing. No code.

Read first in this repo: `README.md`, `src/model/` (garments carry whole-number warmth, wind and water ratings from 0 to 5; a comfort rating stores the conditions and the outfit worn), `docs/research/dark-sky.md` (its closing section on the core loop).

### Part 1: the science, briefly and with sources
- **Clothing insulation**: the clo unit; ISO 9920's garment and ensemble values and how garment values add into an ensemble; how wind and body movement reduce insulation; air and wind permeability; what wetting does.
- **How much is needed**: required insulation for a temperature, wind and activity level (ISO 11079 IREQ and simpler published models); metabolic rate by activity (the Compendium of Physical Activities' MET values for cycling at several efforts and for walking), and why a rider at speed needs less insulation on the core than a walker but more wind protection.
- **Wind at riding speed**: apparent wind from riding speed plus headwind or tailwind; which wind-chill formulation is valid at those speeds and where it stops being valid.
- **Heat**: sweat and evaporative cooling at speed, humidity, sun; the indices used (heat index, WBGT, UTCI) and what can be computed from a forecast.
- **Rain**: what changes in light rain, steady rain and cold rain; water resistance against breathability.
- **Extremities and regions**: hands, feet, head, neck, legs and core have different needs; what the literature and cycling guidance say about each.
- **People differ**: by how much (sex, body size, acclimatisation, effort), and what the personal comfort model literature says about learning one person's offset from a handful of ratings.

### Part 2: what exists
- Cycling and running "what to wear" tools, apps and published temperature charts (apparel makers' guides, clubs' charts, apps and calculators). For each: inputs, output, the scale it uses, and what users say is good or wrong. Include open-source ones with their licences.
- Open-source code for the formulas (thermal comfort libraries, wind chill, UTCI), with licence and language; say what could be used from TypeScript or ported, and its size.

### Part 3: what Bike Weather should do
- **Garment ratings**: keep, change or extend the 0 to 5 warmth, wind and water ratings; how each step maps to something physical (approximate clo, wind-blocking, water resistance); whether ratings need a body region and a layer role (base, mid, outer, shell).
- **A starter catalog**: a table of garment templates for ride and everyday (tops, bottoms, outer layers, gloves, headwear, footwear, accessories such as arm warmers and overshoes), each with its region, layer role, default ratings and the source for them.
- **Recommendation, version 1**: a rule-based method specified closely enough to build: inputs (the forecast for the ride or outing window and its worst conditions, mode, effort, ride speed and length), the need per body region (insulation, wind, water), how an outfit from the user's wardrobe is scored against that need, and how ties and missing garments are handled. Give worked examples: a 5 °C dry windy ride, a 12 °C ride with showers, a 28 °C humid ride, a −5 °C walk.
- **Learning from comfort ratings**: a simple, explainable per-user adjustment (and per region if the data supports it), how many ratings it needs before it moves, and how the user's own outfits and their ratings feed it.
- **Building expertise**: the product means to become expert in human comfort in the weather and to be a premier, high-quality weather app that is a pleasure to use. Say what the app should record from the first version (on the device, nothing leaving it without opt-in) so that its comfort model can keep improving, which open questions in the literature such data could help answer, and which features in this area users find delightful rather than merely correct (cite app reviews and rider forums).
- **What to leave for later**, and the questions the product owner has to answer.

### Output
`docs/research/clothing-weather.md`: Parts 1 to 3, tables where they fit, the version 1 method last. Cite every claim, value and price with its source URL and the date read; mark anything that could not be checked as unverified. State reasons as facts; no first person.

### Commands
Use WebSearch and WebFetch for the research. `ls`, `cat` and `grep` to read this repo. Commit the report with `git add` and `git commit`. No other commands are needed.

### Done when
The report is committed, covers all three parts with cited sources, includes the starter catalog table and the four worked examples, and the result states in one sentence each: the rating scheme recommended, the version 1 method, and the learning rule.
