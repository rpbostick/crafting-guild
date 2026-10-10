# retrowright: plan

**In flight right now**

**CHAIN (2026-10-10 16:49 MDT):** automated play for testing (Patrick picked all four tools). `plan.queue`: `rw-replay` ($10, full, **gate**: record button and in-page replay; preview on :8802 for Patrick), then `rw-tas-replay` ($8) and `rw-mesen-diff` ($10), merged by the chain. At the gate: serve, ask to open, merge on his OK, restart the chain. After: report how far TheAxeMan's TAS gets on jsnes and the first jsnes/MesenCE difference (`docs/accuracy.md`).

`rw-nes-player` merged as 42125ee (Patrick played it; "Enter doesn't work" was Final Fantasy's name screen, where A confirms). Touch buttons and review leftovers wait until after the testing tools. Carried: on-screen touch buttons, plus the carried review notes: README says Node 20 but puppeteer-core 25 needs 22.12+; the e2e "battery RAM stored while playing" check cannot fail (compare stored and core battery RAM); add a Reset step to the e2e after the battery digest; regenerate the lockfile so its root spec matches package.json (`npm ci` accepts it today); decide whether the `window.__retrowright` debug handle ships in production. Untested by a person so far: sound quality, a physical gamepad, an inn save across a reload.

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
2. Automated play for testing: `rw-replay` (record in the page, replay in Node, Final Fantasy memory map), `rw-tas-replay` (TheAxeMan's TASVideos run on jsnes), `rw-mesen-diff` (jsnes against MesenCE frame by frame). Movies of commercial games stay local.
3. Later: on-screen touch controls; release 0.1.0 to the public repo and the site (`SITE_PROJECT`, `SITE_SYNC` in the conf, like toybox); then replacing parts of the core (CPU first?) with tests against jsnes; SNES and GBA cores; homebrew and rebuilt ROMs.
