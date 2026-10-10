# rea-roms-test: plan

**In flight right now**

**CHAIN (2026-10-10 14:19 MDT):** `plan.queue` running: `rea-setup` ($8, light, 45m), then `emu-setup` ($8, light, 45m), each reviewed and merged by the chain. When it stops, read `runs/rea-roms-test/chain.status`. After both merge: run the installers into `$HOME/tools` from the main checkout (`bash scripts/install-ghidra.sh "$HOME/tools"`, `install-rea.sh`, `install-emulators.sh`), then show Patrick the safety report, the smoke screenshots and the bridge recommendation.

## Requirements (Patrick, 2026-10-10)
- rea-roms-test is REA's first use (ahead of the deferred Toybox eyedropper spike).
- Start with the dumps in `research-files/` (Final Fantasy NES, SNES, GBA), not homebrew. ROMs never enter git.
- Tools: Ghidra with console loaders, MesenCE, mGBA, and an emulator MCP bridge (read and checked first). Research: `emulator-research.md`.
- REA installed live from GitHub with our own automated safety checks (decision 2026-10-09, `~/research/16-rea.md`); never REA's global `setup`; per-session `--mcp-config`.
- Dispatch now on a small budget: two light tasks, about $8 each, in sequence.

## Guesses
- Tools install under `$HOME/tools` (outside every repo); builders install into `.ws-evidence/tools` in their worktree for the smoke run.
- A user-local JDK 21 (Temurin), because the machine has no Java and builders cannot use sudo.
- Headless emulator runs without Xvfb (not installed): MesenCE `--testrunner`, mGBA Qt offscreen. If that fails, ask Patrick to install `xvfb`.

## Steps
1. `rea-setup` (`task-rea-setup.md`): `scripts/check-rea.sh`, `install-rea.sh`, `install-ghidra.sh`, `checks/rea-allowlist.txt`, `tests/`. Safe to re-run (the installers are idempotent; the worktree is reused).
2. `emu-setup` (`task-emu-setup.md`): `scripts/install-emulators.sh`, `smoke-emulator.sh`, `lua/`, `docs/research/emulator-bridges.md`. Touches `README.md` and `tests/` after step 1, so it runs second. Safe to re-run.
3. Next (not written): the first REA question on a ROM, chosen with Patrick once the tools work; then trying the MCP bridge the read-through recommends.
