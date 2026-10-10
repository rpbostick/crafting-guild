# rea-roms-test: plan

**In flight right now**

**CHAIN (2026-10-10 15:14 MDT):** `snes-entry` ($5, light, 45m) via plan.queue. REA: Ghidra and emulators directly; findings go in `docs/rea-upstream-log.md` (project repo) and are posted upstream in batches once re-checked (#1641 comment drafted, held). GBA: mGBA (no BIOS for MesenCE).

**DONE (2026-10-10 15:09 MDT):** both steps merged. `rea-setup` cba933d, `emu-setup` 3839323 (build $5.99, review merge $0.49; partial only because MesenCE needs a GBA BIOS dump to boot GBA; mGBA boots GBA without one). Installed in `$HOME/tools`: JDK 21, Ghidra 12.1.4 with GhidraNes, gba-ghidra-loader and ghidra-snes, REA 0fa0b04 (safety check passed), MesenCE 2.2.1, mGBA 0.11-9155. Ghidra headless in `$HOME/tools`: NES 192 functions, GBA 2711, **SNES 0** (the loader finds HiROM and the 65816 but seeds no entry points: needs the reset and interrupt vectors at $00:FFE0–FFFF marked as functions, and `ghidra-list-functions.sh` should fail on zero functions). **REA refuses raw ROMs** (`target_unavailable`). Bridges: try mcp-mgba (needs a libmgba source build), borrow ideas from mesen-for-ai. Smoke page served on :8801 (`/page/index.html`). Next, with Patrick: the REA-on-ROMs decision, then the SNES entry-point fix as a light task.

## Requirements (Patrick, 2026-10-10)
- rea-roms-test is REA's first use (ahead of the deferred Toybox eyedropper spike).
- Start with the dumps in `research-files/` (Final Fantasy NES, SNES, GBA), not homebrew. ROMs never enter git.
- Tools: Ghidra with console loaders, MesenCE, mGBA, and an emulator MCP bridge (read and checked first). Research: `emulator-research.md`.
- REA installed live from GitHub with our own automated safety checks (decision 2026-10-09, `~/research/16-rea.md`); never REA's global `setup`; per-session `--mcp-config`.
- Dispatch now on a small budget: two light tasks, about $8 each, in sequence.

## Guesses
- Tools install under `$HOME/tools` (outside every repo); builders install into `.ws-evidence/tools` in their worktree for the smoke run.
- A user-local JDK 21 (Temurin), because the machine has no Java and builders cannot use sudo.
- Headless emulator runs: MesenCE `--testrunner`, mGBA Qt offscreen, or `xvfb-run -a` (Xvfb installed by Patrick 2026-10-10).

## Steps
1. `rea-setup` (`task-rea-setup.md`): `scripts/check-rea.sh`, `install-rea.sh`, `install-ghidra.sh`, `checks/rea-allowlist.txt`, `tests/`. Safe to re-run (the installers are idempotent; the worktree is reused).
2. `emu-setup` (`task-emu-setup.md`): `scripts/install-emulators.sh`, `smoke-emulator.sh`, `lua/`, `docs/research/emulator-bridges.md`. Touches `README.md` and `tests/` after step 1, so it runs second. Safe to re-run.
3. Next (not written): the first REA question on a ROM, chosen with Patrick once the tools work; then trying the MCP bridge the read-through recommends.
