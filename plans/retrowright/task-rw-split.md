# retrowright: make the emulator game-agnostic, and gather the skate project into one folder

Track: full

Resume: an earlier run of this task was cut off by the usage limit. Its work is in the worktree (`git status`, `git log --oneline main..`); read it and keep what fits.

retrowright (the browser emulator) is going public on its own. The Super Mario Bros. skate project (the patches, Super Skate Bros., the SMB tests, tools and research) will move to its own private repository. This task prepares the split inside this repo: the app stops bundling or naming any game-specific data, and everything skate- or SMB-specific moves under one top-level folder `skate/` that builds and tests on its own against retrowright. After it merges, that folder is extracted with its history into the new repository. Read the README in full, `docs/`, `src/` (Tune, the console and its game tables, the `?game=` link, the library), `harness/`, `tools/`, `e2e/`, `patches/`, `package.json` and `vite.config.ts` first.

## The app becomes game-agnostic
- **Tune** keeps its panel and format but bundles no tunables file. It finds one at run time: (a) a "Load tunables…" button in the Tune panel (a JSON file, kept per game by its SHA-256 in the browser, exported with the settings), and (b) the local ROM folder: a `<rom file name>.tunables.json` or any `*.tunables.json` whose target SHA-256 matches, served beside the ROM by the dev server as ROMs are. The panel and F3 are offered when a tunables file is known for the game.
- **The console** keeps its generic commands. Game-specific commands come from a declarative **game profile** JSON (named RAM values with sizes and formats, and named commands as sequences of RAM writes with optional waits, plus the tunables' names), found the same two ways as tunables. Port the SMB skate commands (warp, board, big, small, fire, star, lives, time) into such a profile under `skate/`; anything that cannot be expressed declaratively stays out of the app and is listed in the result.
- **`?game=<id>`** becomes generic: it reads a `games.json` in the local ROM folder (id, label, ROM file name, tunables and profile files) instead of naming Super Skate Bros. in code.
- No SMB, Super Skate Bros. or skate names, SHA-256s, file names or RAM addresses remain in `src/`, `public/`, the README or the built `dist/` (a test scans `src/` and `dist/` for them). Final Fantasy: its memory map and the accuracy and TAS tooling are emulator test tooling; keep them in retrowright if they hold no game bytes (the audit found none), and say so.

## The skate project in `skate/`
- Move under `skate/`, keeping each file's history (`git mv`): `patches/`, the SMB and Super Skate Bros. harness files and tests, the bot's SMB objective (the generic search can stay in `harness/bot/` if it is game-agnostic; say what you split), `tools/` drafts tools for the board, push, ollie and tricks, the SMB e2e scripts (`e2e/smbExpand.mjs`, `e2e/ssbDemo.mjs`, and an SMB version of the tune check), the skate and SMB docs from `docs/research/`, the SMB game profile and tunables, and the README's SMB and Super Skate Bros. sections (as `skate/README.md`).
- `skate/package.json` depends on retrowright by `"retrowright": "file:.."` for now (after the split it becomes `file:../retrowright`), and imports what it needs from retrowright's exported modules (the core, the harness, the patch library, the movie format); add an `exports` map to retrowright's `package.json` for those. `npm --prefix skate test` runs the skate tests; retrowright's `npm test` no longer runs them. retrowright's own `e2e:tune` uses a synthetic ROM and a synthetic tunables file.
- The `.ws-evidence/` default output folder in e2e scripts and CLIs becomes a git-ignored neutral folder (`.out/`), as the audit asked.
- `LICENSE`: MIT, "Copyright (c) 2026 Patrick Bostick". Keep `NOTICE` and `THIRD_PARTY_LICENSES` consistent with it.

## Checks
- `npm test`, `npm run build` and `npm run e2e:all` pass for retrowright, with no skate files present (run them once with `skate/` moved aside, say how).
- `npm --prefix skate test` passes with the SMBDIS tree and ROM named, as the SMB tests do today: every skate, expand, tunables, Super Skate Bros., fuzz (quick count) and bot test; `npm run smb -- demo` (from `skate/`) still builds the ROM.
- In the app, a skate build in the local ROM folder with its tunables and profile beside it gets the Tune panel and the console commands as before (Firefox script).

## Prior art
VS Code's and RetroArch's per-game settings found by content hash; libretro's per-core option files; git's own `filter-repo --subdirectory-filter` for the later extraction (not run here).

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `npm --prefix skate *`, `npm install *`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git mv *`, `git add`, `git commit`, `git merge *`. One command per Bash call.

## Done when
- The checks above pass (logs); the name scan of `src/` and `dist/` finds nothing; the result lists every moved path and anything left behind with the reason.
