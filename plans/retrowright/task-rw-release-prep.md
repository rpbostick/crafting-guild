# retrowright: release prep for 0.1.0 (the emulator only)

Track: full

retrowright is going public as the browser emulator alone: a public repo with a fresh history and the app on GitHub Pages. The skate project has moved to its own repository. Finish what the audit left, so the release runs clean. Read the README, `docs/`, `AGENTS.md` if present, `package.json`, `LICENSE`, `NOTICE`, `THIRD_PARTY_LICENSES`, `vite.config.ts` and `harness/` first.

## Do
- **Secret scan:** run a real scanner once over the tree and over `dist/` (gitleaks if it runs, or secretlint with `@secretlint/secretlint-rule-preset-recommend` installed as a dev dependency; licence noted). Fix anything found. Add `npm run scan:secrets`.
- **Game names:** `harness/gameNames.ts` names the skate project, its ROM and build SHA-256s and RAM labels so a test can scan for them. Replace it with a generic scan hook that reads its patterns from an untracked local file or an environment variable (for the skate project to use), so the public repo names no game project. Keep the test.
- **docs/research/toolkit.md:** sections 1-3 are general toolkit prior art; section 4 is about the SMB remake. Remove section 4 (it lives on in the skate project's own research), and check every other file under `docs/` for SMB- or skate-specific planning text; remove or generalise it. Research files that read as dated planning notes with task lists become present-tense design notes or are removed; say which.
- **README:** a user's README for the emulator: what it is, how to run it, how to add ROMs (the user's own), the features (library, save states, movies, instant replay, display, controls, touch, Tune, developer tools), how to build and test, the licence. No SMB or skate sections, no development history. Under 200 lines; move internals to `docs/design.md`.
- **docs/design.md:** the layers (core, player, input, storage, movies, patches, tune, console, harness) and why they are shaped so, in the present tense.
- **AGENTS.md:** a dozen lines: commands (`npm test`, `npm run build`, `npm run e2e:all`, `npm run licenses`), no ROMs or game bytes or commercial screenshots in the repo, tests skip without ROMs, where the exported modules are.
- **e2e:opposites flake:** it failed once in five on the split branch (a game read of Left with Right held). Find out whether the browser input path can briefly report both directions, fix it or the test, and run it 20 times (log the count).
- **Pages:** check the build works under a sub-path (`/retrowright/`): `vite.config.ts` base from an environment variable, the service worker scope and the manifest; `npm run build:pages` with that base, and a Firefox script that serves `dist/` under `/retrowright/` and loads the library and a synthetic ROM.

## Prior art
gitleaks and secretlint; GitHub Pages with Vite (`base`); the workspace's release audit.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `npm install *`, `npx --yes *`, `npm view *`, `node *`, `firefox --headless *`, `git grep *`, `grep *`, `git add`, `git commit`, `git merge *`. One command per Bash call.

## Done when
- The secret scan runs clean (log); no file in the tree names the skate project or SMB beyond generic mentions the result lists; the README is under 200 lines and design.md and AGENTS.md exist.
- e2e:opposites passes 20 of 20 (log); `npm run build:pages` and its Firefox script pass; `npm test`, `npm run e2e:all` and `npm run build` pass (logs).
