# retrowright: compare jsnes with MesenCE frame by frame

Track: full

retrowright has an input-movie format (`src/movie/`), a Node harness (`harness/`, `npm run replay`), a Final Fantasy memory map (`src/games/ff1/`), an `.fm2` converter and `docs/accuracy.md` (how far a TASVideos run gets on jsnes). Read the README and those first.

When parts of jsnes are replaced by our own code, we need a reference: the same inputs into a trusted emulator and into ours, memory compared frame by frame, so the first differing frame points at the bug. MesenCE 2.2.1 (GPL-3.0, highly accurate) is installed at `$HOME/tools/mesen/Mesen` and runs headless with `--testrunner` and a Lua script (see the rea-roms-test notes below). Use it as an external program only; copy none of its code.

## Steps
1. **Drive MesenCE from a movie.** `tools/mesen/replay.lua` (committed; Lua runs inside MesenCE) plus `harness/mesen.ts` (Node): convert a `.rwmovie.json` into a simple per-frame input list MesenCE's Lua can read, run MesenCE with `--testrunner` on the ROM and the script, apply the pads at the start of each frame, and dump work RAM ($0000–$07FF) and cartridge RAM ($6000–$7FFF) every frame (or every N frames, with a flag) to a binary file, plus a frame hash of the picture if MesenCE's Lua API exposes one. Find MesenCE's Lua API for input, memory reads and frame callbacks in its documentation; measure, don't assume, at which point in a frame inputs are latched.
2. **Run jsnes the same way** in the harness, dumping the same memory ranges per frame.
3. **Compare.** `npm run diff -- <rom> <movie> [--every N] [--until F]`: runs both, aligns the start (measure the offset as the previous task did for FCEUX; both emulators may run a different number of frames before the game's first input read), and reports the first frame where memory differs, the addresses that differ, and their values on both sides, named through the Final Fantasy memory map where it covers them. Save a screenshot from each emulator at that frame (MesenCE's Lua can save one; ours from the harness).
4. **Run it** on `movies/ff1-new-game.rwmovie.json` and on the converted TAS movie from the previous task (both local, in `movies/`, git-ignored), with `roms/Final_Fantasy_USA.nes` (a link into the main checkout). Add the results to `docs/accuracy.md`: for each movie, the first frame where jsnes and MesenCE differ and what differs. Note whether MesenCE keeps the TAS in step further than jsnes does.
5. **Tests:** unit tests for the input-list conversion and the memory comparison (synthetic dumps), and a test that runs the diff on a synthetic ROM and skips when MesenCE is not installed (`$HOME/tools/mesen/Mesen` missing), so the suite passes without it.

MesenCE headless notes (from the rea-roms-test setup): `Mesen --testrunner <rom> <script.lua>` runs without a window; MesenCE keeps its settings in a home folder (`$XDG_CONFIG_HOME/MesenCE`), so point `XDG_CONFIG_HOME` at a temporary directory per run to avoid touching the user's settings and to keep runs independent. If `--testrunner` refuses to start without a display, use `xvfb-run -a` (installed).

## Prior art
MesenCE's Lua scripting documentation and test-runner mode; the rea-roms-test smoke scripts that already drive MesenCE headless with Lua (`/home/patrickb/rea-roms-test/scripts/smoke-emulator.sh`, `lua/`), which you may read for the invocation; the differential-testing practice emulator developers use against Mesen trace logs.

## Commands
`npm run *`, `npm test`, `npx vitest *`, `npx tsc *`, `npx tsx *`, `node *`, `xvfb-run *`, `timeout *`, WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call.

## Done when
- `tools/mesen/replay.lua`, `harness/mesen.ts` and `npm run diff` are committed with tests; `npm test` passes with and without MesenCE installed.
- The diff ran on both movies; `docs/accuracy.md` has, for each, the first differing frame, the differing addresses (named where the memory map covers them) and screenshots from both emulators in `.ws-evidence/`.
- The start offset between MesenCE and jsnes is measured and recorded.
- No MesenCE code is copied; it runs as an external program with a temporary settings folder.
