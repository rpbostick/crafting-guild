# retrowright: plan

**In flight right now**

**CHAIN (2026-10-10 21:20 MDT):** `rw-replay` merged as 5273daf (Patrick: looks good). Its FF1 movie lived only in the worktree; regenerated in the main checkout with `npm run movie:ff1` (4/4 checkpoints). `.worktree-links` now links `movies/ff1-new-game.rwmovie.json` and `movies/tas` (local-only, ignored), so builders read and keep local movies. Chain restarted: `rw-tas-replay` ($8), then `rw-mesen-diff` ($10), merged by the chain; then report `docs/accuracy.md`. Carry to the next harness task: the synthetic-ROM determinism test can't fail (that ROM draws nothing; compare memory too); a frame-0 Mark in a current-state recording checks a null screen; short replays can miss the 'Movie finished' notice (200 ms poll).

**ALSO RUNNING:** `rw-ux-research` ($6, light, research only, dispatched by hand beside the chain): which emulator interfaces players love; output `docs/research/emulator-ux.md` with a ranked list, now/later/not-for-us per area, an interface roadmap and a licence table for art and metadata sources. Review and merge it by hand (not in the queue), then talk the roadmap through with Patrick.

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
