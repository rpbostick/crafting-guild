# rea-roms-test: MesenCE and mGBA installs, headless smoke tests, MCP bridge read-through

Track: light

The emulators are the live side of the reverse engineering, beside REA and Ghidra (`scripts/install-ghidra.sh`, `scripts/install-rea.sh`, already merged). Research notes: MesenCE (nesdev-org/MesenCE, GPL-3.0, the community continuation of the archived SourMesen/Mesen2) runs NES, SNES and GBA with a debugger and Lua. mGBA (mgba-emu/mgba, MPL-2.0) has a Lua API with breakpoints, watchpoints, savestates, input, screenshots and sockets in its 0.11 development builds; 0.10.5 is the latest stable.

Install under a prefix directory given as an argument (after the merge it will be `$HOME/tools`). In this run, use `.ws-evidence/tools` in the worktree. Scripts must not contain absolute home paths or a username. Follow the style of the existing scripts and tests.

## 1. `scripts/install-emulators.sh <prefix>`
- MesenCE 2.2.1: `Mesen_2.2.1_Linux_x64.zip` from the nesdev-org/MesenCE GitHub release, into `<prefix>/mesen`. Use a checksum if the release publishes one; otherwise record the SHA-256 of the download in the script and verify against it. SDL2 is installed on the machine.
- mGBA: the newest 0.11 development AppImage for x64 from mgba.io's development downloads, into `<prefix>/mgba`. Nightlies have no published checksum: record the downloaded SHA-256 in the install log and say so. If the AppImage needs FUSE and it is missing, use `--appimage-extract`. Also note how to install 0.10.5 stable (`mGBA-0.10.5-appimage-x64.appimage` from the GitHub release) in case the nightly breaks.
- Re-running is safe: an existing install with a matching version is kept.

## 2. Headless smoke tests: `scripts/smoke-emulator.sh <mesen|mgba> <rom> <out-dir>`
Run each emulator **without a window** and drive it from a Lua script committed under `lua/`: boot the ROM, run about 600 frames, press Start a few times, read a few bytes of work RAM, save a screenshot, and exit with a status code. Find out what works without a display:
- MesenCE: its `--testrunner` mode (Lua, no UI), if it still exists in 2.2.1.
- mGBA: the Qt build with `--script` under `QT_QPA_PLATFORM=offscreen`.
- If either needs an X display, run it under `xvfb-run -a` (Xvfb is installed). Say in the README which method each emulator needed. Installing system packages is not allowed.

Run it on one ROM per system, from `research-files/` (a link into the main checkout): `research-files/NES ROMs/Final_Fantasy_USA.nes`, `research-files/SNES ROMs/Final_Fantasy_II_USA_Rev_1.sfc`, `research-files/GBA ROMs/Final_Fantasy_V_Advance_USA.gba` (MesenCE on all three, mGBA on the GBA ROM). Outputs go to `.ws-evidence/smoke/`, with screenshots on one page `.ws-evidence/page/index.html`. Never commit ROM bytes, screenshots of the games or RAM dumps.

## 3. MCP bridges: read-through and safety pass (read only, nothing runs)
Clone shallowly into `.ws-evidence/scratch/`: paulomanrique/mesen-for-ai (GPL-3.0, drives Mesen headlessly over MCP) and Canadadry/mcp-mgba (MPL-2.0, headless GBA debugger on libmgba). For each, record the commit and list what it executes, which network hosts it contacts, which files it writes outside its own folder, its install scripts and dependencies with lifecycle scripts, and the tools it exposes. Say whether each looks safe to try, what it would add over our own Lua scripts, and what a later task should do (try it, borrow ideas, or skip). Write this in `docs/research/emulator-bridges.md`. Copy no code from them.

## 4. Tests and docs
`tests/install-emulators.test.sh` with a stubbed `curl`: a wrong checksum stops the install, and a second run keeps an existing install. `bash tests/run.sh` passes and `shellcheck` is clean. `README.md` gains an "Emulators" section: how to install, how to run the smoke test, and the headless method that worked for each emulator.

## 5. Carried from the last review (small)
- `scripts/install-ghidra.sh` header: it says "the NES and GBA loaders" but also installs ghidra-snes; make it say all three.
- `scripts/ghidra-list-functions.sh`: the analysis-timeout handling has no run on record since its fix. Add a test that feeds it a canned headless log (a timeout line plus the summary passes; a `SCRIPT ERROR` fails), with `analyzeHeadless` stubbed.
- `scripts/install-rea.sh`: add a stubbed test that a failing `check-rea.sh` stops the install before `npm ci`, and writes no `last-checked`.

## Prior art
MesenCE's test runner and Lua API docs, mGBA's scripting API (mgba.io/docs/dev/scripting.html). The two MCP bridges are read here as prior art for a later step. Use the official releases; do not build the emulators from source.

## Commands
`curl *`, `sha256sum *`, `unzip *`, `tar *`, `chmod *`, `git clone --depth 1 *`, `git -C .ws-evidence/scratch/mesen-for-ai log -1`, `git -C .ws-evidence/scratch/mcp-mgba log -1`, `bash scripts/*`, `bash tests/*`, `shellcheck *`, `find *`, `file *`, `ldd *`, `timeout *`, `xvfb-run *`, `.ws-evidence/tools/mesen/Mesen *`, `.ws-evidence/tools/mgba/*`, WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call. No `sudo`, no `npm install`, no `pip`.

## Done when
- `scripts/install-emulators.sh`, `scripts/smoke-emulator.sh`, the Lua scripts under `lua/` and `tests/install-emulators.test.sh` are committed; `bash tests/run.sh` passes and `shellcheck` is clean.
- MesenCE and mGBA are installed under `.ws-evidence/tools`, with the downloaded files' SHA-256 in the install log.
- The smoke test ran headless on the NES, SNES and GBA ROMs in MesenCE and the GBA ROM in mGBA, with screenshots and RAM reads saved under `.ws-evidence/smoke/`; or the result says exactly what stopped each one, with the log.
- `docs/research/emulator-bridges.md` is committed with both bridges' commits, safety findings and a recommendation.
- `README.md` has the Emulators section.
