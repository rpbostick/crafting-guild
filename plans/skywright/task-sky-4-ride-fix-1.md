# skywright step 4, fix 1: time handling across DST (redo Fix B), and an empty ride window

You are continuing on your branch `agent/sky-ride` (commits 99ccec2 Fix A, 98b3ad2 Fix B, de4f9ff rideWindow). The review of de4f9ff found Fix B wrong. Keep Fix A and rideWindow; redo Fix B as below.

## What Open-Meteo actually does (verified 2026-09-27 against the live API)
With `timezone=auto` (or a named zone), Open-Meteo labels every time with **one fixed offset for the whole response** (`utc_offset_seconds`), even across a DST change. For Boulder on 2025-11-01/02 it returned `utc_offset_seconds: -21600` and wall times `…T00:00, T01:00, T02:00, …` with no repeated hour, and sunrise on 2025-11-02 as `07:31` (really 13:31Z, which is 06:31 local MST). With `timeformat=unixtime` the same request returns epoch seconds, exactly 3600 apart. So:
- The old reading (fixed offset → instant) gave the right **instants**; your per-time lookup shifted every hour after the change by one hour (the reviewer's two-hour gap at 01:00 → 02:00).
- But the old **labels** were wrong after a change: `2025-11-02T07:31-06:00` is the right instant with the wrong local wall time.

## Fix B, redone
- Request `timeformat=unixtime` in `buildOpenMeteoUrl` and parse epoch seconds (hourly times, `current.time`, daily `sunrise`/`sunset`; daily `time` values are the local midnights as epochs, so turn them into the local `YYYY-MM-DD` date).
- Format each instant as an ISO string in the response's IANA `timezone` with **its own real offset** at that instant, using `Intl.DateTimeFormat` (Node and Hermes). So the model's promise holds: `time` is the true local wall time with its true offset, and the strings parse to the right instants. After the fall-back change, hours read `…T01:00-06:00, T01:00-07:00, T02:00-07:00` (01:00 local occurs twice; that's correct). When the timezone is `GMT`/`UTC`, the offset is `+00:00`.
- Remove the wall-time → offset resolver from 98b3ad2 and fix the docstring at `openMeteo.ts:126` to describe the new behaviour.
- Fixtures (new, untracked in your worktree; commit them; they were recorded with `timeformat=unixtime`):
  - `test/fixtures/open-meteo-forecast-boulder-unixtime.json`: the same request as the Boulder fixture plus `timeformat=unixtime`, fetched a few minutes later, so **its values differ** from the ISO fixture. Move the model/provider/ride tests to it and rework their hand-computed expected values from it.
  - `test/fixtures/open-meteo-dst-fallback-boulder-unixtime.json`: historical forecast, Boulder, 2025-10-31 to 2025-11-03 (96 hours across the fall-back change), full hourly/daily fields.
  - `test/fixtures/open-meteo-dst-fallback-boulder-iso.json`: the same period in ISO labels (for reference; a test can show it has no repeated hour).
  - Delete `test/fixtures/open-meteo-forecast-boulder.json` if no test uses it any more.
- Tests: across the DST fixture, consecutive hourly instants are exactly 3 600 000 ms apart; the labels around 2025-11-02 01:00 are as above; 2025-11-02's sunrise is labelled `06:31-07:00` (hour and minute; check the exact seconds from the fixture); the daily dates are `2025-10-31`…`2025-11-03`.

## rideWindow
- `src/ride.ts:147`: when no hourly point overlaps the ride, throw a `RangeError` saying so (never index `hours[0]` on an empty list). Test it.
- Validate `speedKmh` (finite, ≥ 0) and `headingDeg` (finite, when given) in `rideWindow` itself with `RangeError`s naming the ride option.

## Also (from the review)
- Restore the `RIDING_SPEEDS_KMH` test in `test/comfort.test.ts`, but make it check behaviour rather than copy the literals: every activity has a finite positive speed, and `feelsLikeAtSpeedC` at each default speed in 0 °C still air is colder than at 0.
- Removing `Location.timezone` is a public API change: say so in the commit message.

## Commands
One command per Bash call. `npx jest test/comfort.test.ts test/openMeteo.test.ts test/model.test.ts test/ride.test.ts` and `npx tsc --noEmit`. Output redirection is denied: save test output under `.ws-evidence/` with the Write tool from what you saw, and say so. Do not run `npm install`.

## Done when
The four test files pass on the unixtime fixtures, the DST tests pass, the old resolver is gone, `npx tsc --noEmit` is clean.
