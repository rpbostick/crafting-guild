# Bike Weather research: what made Dark Sky good, how to rebuild it, and what to add for riders

Dark Sky was a weather app many people considered the best of its time. Apple bought it in 2020, shut the app down, folded parts of it into Apple Weather and turned its API into WeatherKit; many users felt the result lost what made Dark Sky good. Bike Weather (a paid app: weather → what to wear, for cycling and everyday) wants to recreate everything good about Dark Sky and then improve on it for riders. This is a research report, no code.

## Part 1: what Dark Sky was
From primary sources where possible (Dark Sky's own blog and docs on the Wayback Machine, its API documentation, launch coverage, App Store reviews, Apple's announcements, and post-shutdown write-ups and user discussions):
- **Features**, each with how it worked: the down-to-the-minute precipitation forecast ("rain starting in 12 minutes") and how it was produced (radar nowcasting, its own model blending, which data sources); next-hour precipitation notifications; the timeline and graph UI (next hour, next 24 hours, the week); the radar map and its animation; Time Machine (past and future dates); the API (Forecast and Time Machine endpoints, fields, pricing, why developers liked it).
- **Why people loved it**: accuracy perception, the UI's density and speed, the notifications, the voice of the summaries. Quote users and reviewers with sources.
- **What happened after 2020**: what Apple Weather kept, changed or dropped; what WeatherKit offers today (including "next hour" minute forecasts and where they are available); what users say got worse. Cite.

## Part 2: rebuilding it today
For each feature worth keeping, how Bike Weather could provide it now, with the data source and its cost and terms:
- **Minute-level precipitation** for the next 1–2 hours: which providers offer it, at what resolution and in which countries (WeatherKit next hour, Tomorrow.io, Open-Meteo `minutely_15`, others), and whether a radar nowcast of our own is realistic (public radar mosaics such as NOAA MRMS and their licences, and any open nowcasting models). Say plainly what it would cost to run our own versus buying it.
- **Notifications** before rain at the user's location: what that needs on iOS and Android (background location or a coarse saved place, a server or on-device checks, battery and privacy cost). Bike Weather's privacy rules: coordinates leave the device rounded to 0.01°, nothing is collected on a server without opt-in.
- **Timeline UI, radar map, time machine**: data sources and licences for each (radar tiles especially).

## Part 3: improvements for riders
Concrete ideas, each with what data it needs and whether it's feasible for a small team:
- **Ride timing**: "leave by 5:10 to stay dry", a dry-window finder over the next hours for a ride of a given length.
- **Weather along the route**, not at one point: wind as headwind/tailwind/crosswind per leg, rain timing along the route at riding speed.
- **What to wear for the rain and wind you'll actually hit**, tied to the outfit recommender and the comfort feedback loop.
- Anything else the research turns up that riders ask for (cite rider forums, cycling app reviews).

## Output
`docs/research/dark-sky.md` in this repo: Part 1, Part 2 as a table (feature, data source, cost, terms, feasibility) with notes, Part 3 as a ranked list, and a short closing section: which features belong in Bike Weather's core loop (milestone 2) and which later, and what this means for the provider choice (a separate report, `docs/research/weather-providers.md`, compares providers; do not repeat it, refer to it if it exists on main). Cite every claim about Dark Sky, Apple, prices and terms with its source URL and the date read.

## Commands
Use WebSearch and WebFetch for the research. Commit the report with `git add` and `git commit`. No other commands are needed.

## Done when
The report covers all three parts with cited sources and ends with the core-loop recommendation.
