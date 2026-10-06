# Bike Weather: a name check for "Enjoy the Weather" and for the app's own name

Track: light

Research only, no code. Uses WebSearch and WebFetch. The output is one new file, `docs/research/naming.md`; edit nothing else except one line in the README's list of research documents if it has one.

## Background
"Bike Weather" is this app's working title. The larger project it belongs to (the app, its weather library, its figure library and the expertise in dressing comfortably for the weather) is to be called **Enjoy the Weather**, shortened to **ETW**. The app's public name is not chosen. Known so far, each to be checked rather than trusted:
- A public project `timosur/bike-weather` on GitHub (AGPL-3.0-or-later, one developer, a web app recommending cycling clothing from the weather, no human commit since 2026-05-30, dependency-bot activity since) already uses the working title.
- `enjoytheweather.com` is registered to someone else and serves a near-empty page titled "Enjoy the Weather". `etw.app` resolves. `enjoytheweather.app` and `enjoytheweather.org` did not resolve.
- "ETW" is also the common abbreviation of Event Tracing for Windows.

## What to find out
1. **"Enjoy the Weather" as a name.** Registered or pending trademarks with that wording or close to it in the classes that matter for a mobile app and weather or clothing-advice services (Nice classes 9 and 42, also 25 and 35), in the USPTO register, the EUIPO register and WIPO's Global Brand Database. Apps with that name or a confusingly close one on the App Store and Google Play. Businesses, sites and social accounts using it. Who holds `enjoytheweather.com` and since when, as far as public records show (RDAP: `https://rdap.org/domain/<name>`), and whether it is offered for sale.
2. **Domains.** Registration status through RDAP for `enjoytheweather` under `.app`, `.org`, `.net`, `.io`, `.co`, and for close forms (`enjoy-the-weather`, `enjoytheweatherapp`, `etw` with `weather`). Say for each: registered (with the creation date), or no record found.
3. **"ETW" as a short form.** What else it stands for and how crowded search and the app stores are for it. Whether it is usable as an app icon label or a package scope (check the npm scope `@etw` and the GitHub organisation name `etw` and `enjoytheweather` by fetching their public pages).
4. **The app's own name.** Is "Bike Weather" usable in public: other apps and products with that name or close to it on both stores and the web, any trademark, and how descriptive names fare for registration and for store search. Then propose six to ten candidate names for the app that sit well under Enjoy the Weather, are not purely descriptive, and suit an app that also covers everyday (non-riding) outings; for each, the same checks in brief (stores, trademark registers, the `.app` and `.com` domains).
5. **What to do first**, in order, with rough costs where a public price exists: domains worth registering now, whether a trademark search by a professional is worth it before a store build, and what must not be done until the name is settled (bundle ids, store listings, a public repository).

## How to write it
- Every claim carries its source as a link, and is marked `[read]` when the page itself was fetched and read or `[search result]` when only a search snippet supports it. Where a register or a store could not be queried from here, say so plainly and say what a person should check by hand, with the address.
- Absence is stated as "no record found in <where>, searched <how>", never as "available".
- This is not legal advice and the document says so once, at the top.
- Plain wording, short sections, a summary table at the top: name, what was found, the risk in a few words.
- No names of people other than public registrants and developers as their public pages show them.

## Prior art
- The registers' own search pages and RDAP are the tools; no code is written.
- `docs/research/clothing-weather.md` §2.2 already lists the what-to-wear apps found earlier; reuse that list for the store checks rather than rediscovering it.

## Commands
`git status`, `git add`, `git commit`, `ls`, `cat`, `grep`, `mkdir`. One command per Bash call. No installs.

## Done when
`docs/research/naming.md` is committed with the summary table, the five sections above and sources on every claim, and the result states in three lines: whether anything found stands in the way of "Enjoy the Weather", the three strongest app-name candidates, and what could not be checked from here. Safe to re-run from scratch.
