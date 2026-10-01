# Bike Weather research: which weather provider to launch on

Bike Weather builds on skywright, which talks to Open-Meteo's free tier. That tier is for non-commercial use only, and Bike Weather is a paid app, so it needs a commercial provider before launch. This is a research report, no code.

## What to compare
Open-Meteo (commercial plans), Apple WeatherKit, OpenWeather (One Call), Tomorrow.io, and any other provider that covers the same fields and is a serious option for a small paid mobile app (say why it was included). For each:
- **Fields**: hourly forecast for at least 2 days and daily for 7: temperature, feels-like (or the inputs to compute it), wind speed and gusts, wind direction, precipitation amount and probability, cloud cover, UV, sunrise and sunset. Note anything skywright's model (`src/model.ts` in the skywright repo, described in its README) has that the provider lacks.
- **Cost** at three sizes: 1,000, 10,000 and 100,000 daily active users, each opening the app about 3 times a day, with skywright's cache (one fetch per place per hour). Show the arithmetic.
- **Licence and terms**: commercial use, attribution required (and how it must be shown), caching allowed and for how long, storing forecasts on the device, rate limits, what happens when a limit is hit.
- **Privacy**: what the provider logs from a request (coordinates, IP, device identifiers), how long, whether it's sold or shared, where it's processed, and whether requests can go through our own proxy so the provider never sees the user's IP. Bike Weather's rule: coordinates leave the device rounded to 0.01°, and nothing else about the user does.
- **Mobile fit**: an API key in the app is extractable. Say for each whether a key can be restricted (by app bundle, by domain), whether the provider recommends a proxy, and what WeatherKit's signed-token model requires (Apple developer account, a server to sign tokens or not).
- **Coverage and quality**: regions covered, models used, update frequency; any published accuracy comparisons (cite them).

## Output
`docs/research/weather-providers.md` in this repo: a comparison table, then one section per provider, then a recommendation in a short paragraph (one provider for launch, one fallback), with the reasons and the open questions a person must answer before signing up. Cite every price, limit and term with its source URL and the date you read it.

## Commands
Use WebSearch and WebFetch for the research. Commit the report with `git add` and `git commit`. No other commands are needed.

## Done when
The report covers each provider on every point above with cited sources, shows the cost arithmetic, and ends with a recommendation and its open questions.
