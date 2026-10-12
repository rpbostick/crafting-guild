# retrowright: plan

**In flight right now**

**RUNNING (2026-10-12 12:18 MDT):** Patrick saw the `rw-touch` preview and approved; merged as 22e7390 (suite green in 20s, pushed). The chain is restarted for `rw-first-run` ($8, gate): when it stops at the gate, serve it on 8802, ask Patrick to open it, merge on his OK.

**Where we are (merged on main, pushed to rpbostick/retrowright-dev):** NES player on jsnes behind our `EmulatorCore` (42125ee); record and replay with the Node harness and the Final Fantasy memory map (5273daf); `.fm2` converter, TheAxeMan's TAS in step on jsnes for all 257,725 frames (f6e7772); jsnes against MesenCE frame by frame, the same game state at every compared frame (565b3b8); interface research `docs/research/emulator-ux.md` (eda134a); quick menu with thumbnail save slots (f8ae6c5); library with Continue and the blocked-upgrade fix (876e583); touch play with JSON layouts, the card-picture fix, remembered grid/list and sort (22e7390). Accuracy record: `docs/accuracy.md`. Local-only files: `roms/`, `movies/ff1-new-game.rwmovie.json` (`npm run movie:ff1`), `movies/tas/` (sources in `movies/TAS-SOURCES.md`).

**Next, in order:**
1. `rw-touch`: merged 22e7390.
2. `rw-first-run` (running, $8, gate): empty-library explanation, persistent storage, storage meter, export and import of saves, sound and focus hints, README Node version.
3. Interface roadmap steps 5 and 6 (not written): display and speed (integer scaling, 8:7 aspect, a home-made scanline filter, fast-forward, screenshots); installable and offline, plus an accessibility pass.
4. First public release 0.1.0: `release-audit.md`, a public `rpbostick/retrowright` repo, `SITE_PROJECT`/`SITE_SYNC` in the conf like toybox, rpbostick.github.io/retrowright/; Patrick sees the audit findings and approves. Decide what local movies (if any) may ship (none of commercial games).
5. Our own core, in stages, checked against jsnes, the TAS and MesenCE: the 6502 CPU first.
6. Later: rewind, achievements (ask RetroAchievements whether a static web client can be approved), SNES and GBA cores, homebrew and our own rebuilt ROMs.

Carried, not yet in a task: harness: dedupe BATTLE_RNG_STATE/bootAt into harness/tasStart.ts, test compare() with lead ±1, tasTrace's default --out, fceuxRomMd5 test with trailing bytes, use the memory map's view type, the synthetic-ROM determinism test can't fail, frame-0 Mark in a current-state recording, short replays can miss 'Movie finished'; MesenCE pad 2 input (emu.setInput port 1 moves pad 1); gamepad choose cannot open file pickers or fullscreen (in rw-touch? no: it was carried into rw-library and handled there; recheck); fullscreen untested in a headed browser; e2e scripts run only by hand (consider an `npm run e2e:all` gate); export one sort comparator for store and view; `addFiles` readyStore outside try (in rw-touch). From the rw-touch review: layout.test.ts:84 placed-overlap check excuses every A+B pair (only A+B with A and with B should be); e2e/touch.mjs:237 pinch check can't fail (it reads touch-action/overflow; rename or drop the pinch); e2e/firefox.mjs:485 fixed sleep(300) before the Continue label; App.tsx:293 any keydown hides touch controls (on-screen keyboards, accessibility tools): fix or add a 'Deliberate:' note.

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
