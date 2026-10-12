# retrowright: research spike, SNES and GBA cores

Track: light

A research spike: the output is one document, `docs/research/cores.md`, plus any small probe scripts under `.ws-evidence/`. No change to `src/`.

retrowright plays NES on jsnes behind `EmulatorCore` (`src/core/types.ts`). It must also play SNES and GBA games in the browser, on desktop and phones, and serve as a toolkit for reverse-engineering ROMs: record and replay (`harness/`), memory maps, and later a memory viewer, RAM search, tile viewers, CPU trace and breakpoints. Read `README.md`, `src/core/types.ts`, `harness/replay.ts` and `docs/accuracy.md` first.

## Rules for candidates
- **Licence:** permissive only: MIT, BSD, ISC, zlib, Apache-2.0 or MPL-2.0. GPL, LGPL and non-commercial licences (snes9x's, for example) are out. Check the licence from the repository's own LICENSE file and the headers of the source files you would use, not a summary site; note any bundled parts under other licences.
- **No GPL code as a source:** a GPL emulator's code must not be read to write ours. Hardware documentation (fullsnes, the SNESdev wiki, GBATEK, the NESdev wiki) and permissive projects are the sources.
- **BIOS:** GBA games need a BIOS; say whether each GBA candidate has a built-in replacement (HLE) so players need no BIOS dump.

## Research
Search thoroughly before judging; list every candidate found, not only the good ones. Leads to verify, not conclusions: mGBA (MPL-2.0? its wasm builds), ares (ISC? SNES and GBA; any wasm build), gbajs/gbajs2, IodineGBA, LakeSnes and other JS or wasm SNES emulators, libretro cores and the EmulatorJS and Nostalgist.js front ends (check each core's and front end's licence separately), any Rust emulators with wasm builds. For each candidate:
- licence (verified as above), language, wasm or JS, maintained or not, download size;
- accuracy: which test ROM suites it passes (for example the SNES and GBA test ROM collections) and how it compares with MesenCE;
- speed: whether it runs at full speed on a mid-range phone (published numbers, or a quick probe in headless Firefox here if one is cheap);
- what `EmulatorCore` needs and whether it offers it: frame stepping, input per frame, save states, battery saves, audio, reading and writing memory, and hooks for CPU trace and breakpoints (the toolkit);
- whether it can run in Node for `harness/` (record, replay, memory dumps).

## Prior art
This task is the prior-art search for the SNES and GBA build tasks. Also read how retrowright wrapped jsnes (`src/core/`) and what `docs/accuracy.md` checks, so the recommendation says how each core would be checked the same way.

## Commands
WebSearch, WebFetch, `git clone *` (into `.ws-evidence/` only, to read LICENSE files and headers), `npm install *` (into `.ws-evidence/` only, for a probe), `node *`, `npx tsx *`, `firefox --headless *`, `git add`, `git commit`. One command per Bash call.

## Done when
- `docs/research/cores.md` has a table of every candidate with the columns above, the licence of each verified from its own files (the file named), and sources linked.
- It recommends one SNES and one GBA core (or one core for both), says why, names what retrowright would have to add (for example missing trace hooks), and lists the risks; if no permissive SNES core is good enough, it says so plainly and sets out the options (for example writing a core from hardware documentation, checked against MesenCE).
- It sketches the build tasks that follow: their order, sizes and done-whens.
- Committed on the branch.
