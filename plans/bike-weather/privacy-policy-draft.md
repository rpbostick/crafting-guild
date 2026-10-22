# Privacy policy: draft (step 6 of ratings-share.md)

Draft written 2026-10-21 from the code as merged (Settings aaa246d, Worker 332ac3a) and the upload branch under review. For Patrick to edit. Nothing here is published; the upload endpoint stays empty until this is final. Decisions taken 2026-10-21 (Patrick); what is left is marked **[fill]**.

---

## Bike Weather privacy policy

**Short version.** Your wardrobe, outfits and ratings stay on your phone. If you leave sharing on, the app sends an anonymous copy of each comfort rating so riders in similar weather get better suggestions. A shared rating has no exact location, no account, no device ID, and a new random ID each time. You can turn sharing off in Settings at any time, and the app works the same without it. No ads, no selling data, no marketing.

### What stays on your phone
- Your garments (names, colours, brands, ratings), saved outfits and comfort ratings.
- Your sharing choice, and a random secret the app uses to make the contributor key (below). The secret never leaves the phone, and is deleted when you turn sharing off.
- Backups you export are files you control; the app does not send them anywhere.

### What the app sends, and to whom
**Weather forecasts.** To get a forecast, the app sends the place you look up, as coordinates rounded to 0.01° (about 1 km), to Open-Meteo (open-meteo.com), and if Open-Meteo does not answer, to the Norwegian Meteorological Institute (api.met.no). Searching for a place sends the text you type to Open-Meteo's geocoding service. These services see your device's internet address, as any website does. Their own privacy policies apply.

**Shared comfort ratings (on by default; Settings → Share comfort ratings).** When you rate how comfortable you were, the app sends:
- the weather you rated it in: temperature, feels-like, wind, rain, and the kind of conditions;
- whether it was a ride or everyday outing, your effort, and how comfortable you were;
- each garment's kind and its warmth, wind and water ratings; brand and model only when they are on the app's list of known brands, otherwise "other";
- the day (not the time);
- your region, kept coarse: climate zone (Köppen), country, and altitude in 500 m bands;
- a fresh random ID for that rating, and a contributor key.

It never sends garment names or colours, the place or coordinates, the time of day, or your rating's own ID. Settings shows the exact lines that would be shared for your latest rating.

**The contributor key** lets the server count how many different people contributed to a region in a year, without being able to link your ratings across regions or years. It is made on your phone from the random secret, your region and the year. Turning sharing off and on makes a new secret.

**When it is sent.** At most once a day, in one batch, only while sharing is on. Ratings made while sharing was off are never sent later.

### What the server keeps
The ratings server runs on Cloudflare Workers with a Cloudflare D1 database. It stores each shared rating as listed above, plus the day the batch arrived. It does not read or store your internet address, the time of day, or any request headers, and request logging is turned off. Cloudflare's network still sees your internet address when the request passes through it, as for any website; Cloudflare's privacy policy applies to that. After five years, what could link a shared rating to anyone is removed: its contributor key is replaced with a random label that nobody can recreate, and its random ID and the day it arrived are deleted. The rest of the rating (the weather, the clothes and how comfortable you were) is kept, so the recommendations keep their history.

### What is published
The app's recommendation table is built from shared ratings. A region or brand with fewer than about 10 different contributors is merged into a broader group ("other") before anything is published, so a small group cannot be picked out. Counts are rounded. No research dataset is published now. If one is published later, it will use the same 10-contributor check and give dates only by week, and this policy will change first (see below).

### Your choices
- Turn sharing off in Settings at any time. Ratings not yet sent are deleted from the phone's queue, and the secret is deleted.
- Because shared ratings carry no account or device ID, the server cannot tell which ratings are yours, so it cannot find or delete them on request.

### Children
Bike Weather is not directed at children under 13. Because shared ratings identify no one, the app does not ask anyone's age.

### Changes and contact
Questions about this policy: **[fill: the app's own contact address]**. When this policy changes, the app shows a short notice with a link the first time it starts after the change, and the date below changes. Last updated: **[fill: date of publishing]**.

---

## Notes for the edit
- Work these decisions need before the endpoint goes live: the ratings Worker removes a rating's identifiers at five years (random group label in place of the contributor key; upload ID and arrival day deleted) and, from a daily scheduled check, flags 60 days ahead when the first are due, shown at cold start (Patrick asked for a reminder before removal starts); the in-app notice when the policy changes; the contact address (Patrick makes it).
- No marketing use, no advertising, no sale of data: decided 2026-10-09; said in the short version (Patrick, 2026-10-21).
- Facts above come from: `src/model/shared.ts` (`describeShared`), `src/share/` (contributor key, queue, once a day), `server/migrations/` (no IP, no time, `received_on`), `server/wrangler.toml` (invocation logs off), skywright `coords.ts` (0.01° rounding, used by both `openMeteo.ts` and `metNorway.ts:52`), and the research report's scrub section (10 plus 0-3, rounded to 5).
- Before publishing: run `release-audit.md` for the app's store listing, and have the text checked by someone who knows the privacy law where the app is offered (GDPR in the EU and UK, for example).
