# retrowright: plan

**In flight right now**

**GATE (2026-10-10 16:17 MDT):** `rw-nes-player` built ($6.37, 23 min), review fix-first (Reset wiped battery RAM), fix round 0be980a ($0.30), re-review **merge at 0be980a**. Preview on :8802 (`ws --project retrowright serve stop rw-nes-player` after); Patrick is playing Final Fantasy. On his OK: `bin/ws --project retrowright merge rw-nes-player 0be980a85a67b283ba4828b73ae9e9149ae53029`. The review's lockfile note is a false alarm (`npm ci --dry-run` accepts it). Carry forward to the next task: on-screen touch buttons (left out); README says Node 20 but puppeteer-core 25 needs 22.12+; the e2e "battery RAM stored while playing" check cannot fail (compare stored and core battery RAM instead); add a Reset step to the e2e after the battery digest; regenerate the lockfile so the root spec matches package.json; `window.__retrowright` debug handle ships in production (decide whether to keep it).

## Requirements (Patrick, 2026-10-10)
- A browser-based retro game emulator, run from a static demo page like the other demos (rpbostick.github.io/retrowright/), React.
- NES first: Final Fantasy and the other NES titles in `roms/` (local, git-ignored, copied from rea-roms-test's research files).
- Both, in stages: a proven core first (jsnes, chosen without a comparison spike), then parts replaced by our own code over time, each checked against the core.
- Games: the user loads their own ROM (kept in the browser, never uploaded). Later: our own rebuilt ROMs (from the rea-roms-test work) and homebrew ROMs.
- Repo: private `rpbostick/retrowright-dev` now; a public `rpbostick/retrowright` at the first release, through `release-audit.md` and Patrick's approval. MIT, crediting jsnes (Apache-2.0).

## Guesses
- Vite + React + TypeScript, Vitest, an `e2e/` Firefox script like toybox's; `base: './'` for the sub-path.
- Python only if a tool needs it later (none planned now).

## Steps
1. `rw-nes-player` (`task-rw-nes-player.md`, full, $12, 2h, gate): the NES player on jsnes. Patrick plays Final Fantasy on the preview before the merge.
2. Later: on-screen touch controls; release 0.1.0 to the public repo and the site (`SITE_PROJECT`, `SITE_SYNC` in the conf, like toybox); then replacing parts of the core (CPU first?) with tests against jsnes; SNES and GBA cores; homebrew and rebuilt ROMs.
