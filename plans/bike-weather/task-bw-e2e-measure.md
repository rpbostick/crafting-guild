# Bike Weather: an end-to-end check of the endpoint, with measured D1 rows

Track: light

`docs/research/abuse-limits.md` estimates about 121 rows written per upload at the cap (section 3 and the option-A cost cell) and lists the D1 rows as an unknown: they were read from the schema, not measured. The endpoint also has no test that drives it from mint to upload to refusal through the real fetch handler; the existing tests call the modules.

## What to build (in `server/`)

1. **An end-to-end test** (Vitest, the existing pool): through the Worker's `fetch` handler and a migrated test D1, mint a token, upload a valid batch, retry it (stored 0), send without a token (401), send a 31st rating (429), send a third contributor key (429), and check the day row's counts. Keep it independent of the unit tests' fixtures where they make the flow unrealistic.
2. **Measure the rows.** In the same test (or a small `npm run bench` section), capture `meta.rows_read` and `meta.rows_written` from each D1 result for: a fresh token mint, a one-rating upload, a 30-rating upload at the cap, and a retry of that batch. Print them as a table in the test's output.
3. **Record the numbers** in `server/bench/RESULTS.md` (a new "Ingest rows" section with the table, the seed state and the date run) and replace the estimates in `docs/research/abuse-limits.md` section 3, the option-A cost cell and point 5 of the recommendation with the measured figures (keep the estimate only where it is still an estimate, and mark it). Remove the matching item from the report's "Unknowns" list.
4. **Assert a bound** so a regression fails the suite: one upload at 30 ratings writes no more than 140 rows and reads no more than 10, with the measured figure in the assertion's message.

## Prior art
D1's `meta.rows_read`/`meta.rows_written` in the D1 result (Workers D1 docs); `@cloudflare/vitest-pool-workers` for the handler test; the existing `server/bench/` measurement style.

## Commands
`npm --prefix server test`, `npm --prefix server run typecheck`, `npm --prefix server run bench`, `npx vitest *`, `npx tsc *`, `node *`, `git add`, `git commit`. One command per Bash call.

## Leave alone
The caps' values, the token design, the client, and the release builder.

## Done when
- The end-to-end test passes through the fetch handler and covers mint, upload, retry, 401 and both 429 paths.
- The measured rows table is in `server/bench/RESULTS.md` and the estimates in `abuse-limits.md` are replaced with it (marked measured).
- The bound assertion is in the suite and names the measured figure.
- `npm --prefix server test` and `npm --prefix server run typecheck` pass.
