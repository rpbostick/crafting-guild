# retrowright: replay a TASVideos Final Fantasy run on jsnes

Track: full

retrowright has an input-movie format (`src/movie/`, `.rwmovie.json`), a Node harness (`npm run replay -- <rom> <movie>`, `harness/`) and a Final Fantasy memory map (`src/games/ff1/`). Read the README and those modules first.

TASVideos hosts tool-assisted runs of NES Final Fantasy recorded in FCEUX: TheAxeMan's "Console Verification" run (submission 4450S, FCEUX 2.2.2, from a clean start with no resets or power cycles, about 1:11:28), and later runs listed on the game's user-files page (tasvideos.org/UserFiles/Game/202). A TAS is frame-exact input; replaying it on a different emulator goes off course at the first frame where the two emulators differ in a way the game notices. That makes it a strong accuracy test of the core.

## Steps
1. **Get the movie.** Download the `.fm2` for 4450S (or the published movie it became) from TASVideos into `movies/tas/` (git-ignored: keep it local; record its URL, date and SHA-256 in `movies/tas/SOURCES.md`, which is committed). Check which ROM it expects (its header has the ROM checksum) against `roms/Final_Fantasy_USA.nes` (a link into the main checkout) and report a mismatch.
2. **Convert.** `src/movie/fm2.ts`: parse `.fm2` (text header, then `|commands|RLDUTSBA|RLDUTSBA|port2|` lines, one per frame; commands include soft reset and power) and convert to our format, with unit tests on small hand-written `.fm2` snippets. A CLI: `npm run fm2 -- <in.fm2> <out.rwmovie.json>`.
3. **Align the start.** FCEUX and jsnes may not agree on what "frame 0" is after power-on (how many frames before the first input is read, the initial RAM contents). Measure it: try offsets of a few frames and initial RAM fills (zeros, FCEUX's default pattern) and pick the one that keeps the run in step longest. Record what you found.
4. **Replay and find where it goes off course.** Replay on jsnes with checkpoints from the memory map every N frames (map, position, party HP, gold, battle state). Define "in step" by game milestones, not raw RAM: for example, the party reaches Coneria, the first battle starts and ends, the Garland fight, the bridge, Pravoka. Report the last milestone reached and the first frame where the run clearly diverges, with screenshots on both sides (`.ws-evidence/`) and what the game was doing.
5. **Explain if you can.** If the divergence looks like a known jsnes inaccuracy (an RNG seed taken from a timing-dependent value, a mapper detail, sprite-0 hit, DMC timing), say which, with evidence. Do not change jsnes or our core in this task.

## Prior art
FCEUX's `.fm2` format documentation (fceux.com/web/help/fm2.html) and TASVideos' movie documentation; TASVideos' "Console Verification" practice (replaying a TAS on real hardware), whose notes on start-up alignment apply here. Our harness and movie format from the previous task.

## Commands
`curl *`, `sha256sum *`, `npm run *`, `npm test`, `npx vitest *`, `npx tsc *`, `npx tsx *`, `node *`, WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call.

## Done when
- `src/movie/fm2.ts` and its CLI are committed with unit tests; `npm test` passes.
- The TAS `.fm2` is downloaded locally (not committed), its source recorded in `movies/tas/SOURCES.md`, and its ROM checksum compared with ours.
- The start alignment that keeps the run in step longest is measured and recorded.
- `.ws-evidence/tas-report.md` says how far the run gets on jsnes (the last milestone reached, the frame where it diverges, screenshots either side) and the likely cause where one can be shown.
- `docs/accuracy.md` is started with this result, so later core changes can be compared against it.
