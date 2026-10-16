# retrowright: vitest upgrade, the Node version

Track: light

This continues this branch (`273476b`). vitest 5.0.5 declares engines node `^22.12.0 || ^24.0.0 || >=26.0.0`, but the README says the app, its build and `npm test` need Node.js 20 or later. The build also loads vitest, because `vite.config.ts` imports `defineConfig` from `vitest/config`.
- Keep the build independent of vitest: move the test settings to a `vitest.config.ts` (or `test` block typed another way) so `vite.config.ts` imports only from `vite`, and say in the result whether `npm run build` then works on Node 20 (check what the installed vite declares in its engines).
- Correct the README's requirement: the build's minimum, and Node.js 22.12 or later for the tests. Add `"engines"` to `package.json` to match.
- Run `npm test`, `npm run build` and `npm run e2e:all`.

## Prior art
vitest's and vite's config docs.

## Commands
`npx vitest *`, `npx tsc *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The README and `engines` state the right versions; `npm test`, `npm run build` and `npm run e2e:all` pass (logs).
