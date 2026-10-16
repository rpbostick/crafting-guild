# retrowright: upgrade vitest (dev-only audit findings)

Track: light

`npm audit` reports a critical (tinypool, prototype pollution) and a moderate (@vitest/mocker, path traversal) advisory, both in vitest's tree, used only for development; the shipped app has none. Upgrade vitest (and @vitest/* and any plugin that pins it) to a version that clears them, fix what the upgrade breaks in the config or tests, and keep `harness/` and the e2e scripts working. `npm audit` should report 0.

## Prior art
vitest's migration guide for the major versions crossed.

## Commands
`npx vitest *`, `npx tsc *`, `npm run *`, `npm test`, `npm install *`, `npm audit *`, `node *`, `firefox --headless *`, `git add`, `git commit`. One command per Bash call.

## Done when
- `npm audit` reports 0 vulnerabilities (log); `npm test`, `npm run build` and `npm run e2e:all` pass (logs).
