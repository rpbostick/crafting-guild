# retrowright: plan

**In flight right now**

**GATE (2026-10-10 23:34 MDT):** `rw-quick-menu` built ($6.35), review **merge at 87110ce** first time; preview on :8802, open for Patrick. On his OK: stop the preview, `bin/ws --project retrowright merge rw-quick-menu 87110ce2e2d144b267cca050e67334cc3c5446da`, restart the chain (`rw-library` next). Carry into rw-library: gamepad 'choose' cannot open the file picker or fullscreen (no user activation from Gamepad API: show a hint or disable those for gamepad); Quit to library keeps the previous game's slot and record choice; readStateRecord casts romId and slot unchecked; README play-bar wording; consider focus-trap (MIT) instead of the hand-written menuFocus.ts; fullscreen untested in a headed browser.

**Merged today:** `rw-replay` 5273daf; `rw-tas-replay` f6e7772 ($5.87, partial only because writes into the linked `movies/tas` were denied; I copied the .fm2 and converted movie into `~/retrowright/movies/tas/`): **TheAxeMan's 4450S TAS (257,725 frames) stays in step on jsnes for the whole movie** (jsnes power-on RAM, lead 0; FCEUX RAM pattern needs lead −1; zero-filled RAM desyncs at 1260; battle RNG at $688A lives in battery RAM and must start at 0). `rw-ux-research` eda134a (three fix rounds on citation precision; Patrick chose a last round over an override): `docs/research/emulator-ux.md`, roadmap: 1 quick menu + visible save slots, 2 library with Continue, 3 touch controls (Delta-style JSON layouts), 4 first run + storage safety + save export, 5 display and speed, 6 installable/offline + accessibility; achievements and rewind later. No cover-art database is usable (publisher art, secret keys); thumbnails from the player's own frames. Patrick queued roadmap steps 1-4: `rw-quick-menu`, `rw-library`, `rw-touch`, `rw-first-run` ($38 in all), each gated; they start after `rw-mesen-diff` (restart the chain when it reports done).

Carried: from rw-tas-replay review: dedupe BATTLE_RNG_STATE and bootAt into harness/tasStart.ts; test compare() with lead ±1; tasTrace's default --out is .ws-evidence (make it project-neutral); fceuxRomMd5 test with trailing bytes; use the memory map's exported view type. From rw-replay review: the synthetic-ROM determinism test can't fail; frame-0 Mark in a current-state recording checks a null screen; short replays can miss the 'Movie finished' notice. From rw-nes-player: README Node 20 vs puppeteer-core 22.12+; e2e 'battery RAM stored' check can't fail; Reset step in the e2e; lockfile root spec; `window.__retrowright` in production. Builders cannot write through `.worktree-links` links (denied as outside the worktree): links are read-only; outputs to keep go in `.ws-evidence/` (merge keeps them) or committed files.

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
