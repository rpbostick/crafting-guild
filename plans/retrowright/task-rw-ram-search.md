# retrowright: RAM search, watch list and memory viewer

Track: full

Toolkit step 2 (`docs/research/toolkit.md` section 8). It builds on the core debug hooks (`setDebugHooks`, merged from rw-hooks). Read section 1.1 and the interface notes in section 6 of that document, `docs/research/emulator-ux.md`, `src/core/types.ts`, `src/ui/App.tsx` and `src/ui/QuickMenu.tsx`.

## Build
- **Search model** (`src/tools/ramSearch.ts`, no UI, runs in Node): candidates over work RAM (`$0000-$07FF`) and cartridge RAM (`$6000-$7FFF`), read with `peek`. Each step filters by a comparison: equal, not equal, greater, less, changed or unchanged, against the previous snapshot or a given value. Sizes of 1 or 2 bytes, signed or unsigned. Undo the last step and reset.
- **Watch list:** addresses with a name, a size and a format (hex, decimal, signed), kept per ROM (by SHA-256) in the browser, with the current value shown each frame.
- **Memory viewer:** a hex view of the same ranges, with values that change highlighted, and reads and writes highlighted from the access hooks while the viewer is open. Install the hooks only while it is open.
- **Panel:** a tools panel beside the screen on desktop, opened from the quick menu and a key (pick one that does not clash with the existing bindings, and add it to the controls table). Usable with the keyboard alone. Not offered in touch play for now. The game keeps running while it is open, and pausing works as it does now.

- **Carried from the rw-leftovers review (a regression the player sees):** after a mouse click on Theme or a notice's Dismiss button during play, focus stays on that button, so the arrows, Enter and Space stop reaching the game until the player clicks the picture. Give focus back to the picture after a pointer click on a control outside the stage (keyboard focus moved with Tab stays where it is). The tools panel must follow the same rule: keys typed into the panel stay there, and closing it returns focus to the picture.

## Prior art
`docs/research/toolkit.md` section 1.1: FCEUX's and BizHawk's RAM Search and RAM Watch are the models (compare to previous or to a value, a narrowing list, a watch list); no browser library does it. Write it; nothing to vendor.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `git add`, `git commit`. One command per Bash call.

## Done when
- A Node test finds Final Fantasy's map byte `$48` from a movie in at most three filter steps (skipped without the ROM, as the movie tests are).
- An e2e script does the same search in the page with the keyboard alone, adds the result to the watch list, and the watch survives a reload.
- The memory viewer highlights a write from the hooks (test with a synthetic ROM), and closing the panel removes the hooks (test).
- With a game running, a mouse click on Theme or on a notice's Dismiss button, then the arrows, moves the player (unit test, shown failing before the fix); Tab-reached controls keep their keys as now.
- `npm run a11y` passes with the panel open; screenshots on `.ws-evidence/page/index.html`.
- The tests for what changed pass, and `npm run build` passes. The README describes the tools panel.

## Carried from the rw-hooks review (suggestions; do them where the code is yours to touch)
- `src/core/jsnesDebug.ts:81`: attach wraps mapper.loadRomBank and load8kRomBank unconditionally and relies on jsnes's fromJSON and reloadROM building a new mapper each time (stated in jsnesCore.ts:177 but not checked). If a jsnes update reuses the mapper, every loadState adds another wrapper layer (hookCost.ts does 1000 loadStates). Mark the wrapped mapper (a symbol property or a WeakSet) and skip or throw when it is already wrapped, as install already does for the CPU.
- `src/core/jsnesDebug.ts:108`: romOffset throws when a slot's bytes match no PRG bank, but the EmulatorCore doc (types.ts:171) promises null for RAM. MMC5 PRG-RAM banked at $8000 or above, or any mapper that puts non-ROM bytes there, hits an exception instead of null. Either return null for an unmatched slot or state the throw in the interface doc.
- `src/core/jsnesDebug.ts:187`: The execute hook's interrupt handling has three paths (nmiImmediate, IRQ or reset taken, IRQ pending but masked) and only the reset path is pinned by a test (first PC is $8000). A synthetic ROM that enables NMI (NMI_IDLE_PROGRAM with a handler at $8100 exists in src/test/syntheticRom.ts) could assert the hook reports $8100 once per frame, and a masked-IRQ case could assert the next PC is unchanged.
- `src/core/jsnesDebug.ts:134`: The comment says load, write, push and pull are the only paths for data reads and writes. jsnes's OAM DMA ($4014) copies 256 bytes out of cpu.mem directly, so those reads are not reported to onAccess; say so here and in the DebugHooks doc so a tool watching a sprite buffer knows why it sees no reads.
- `src/core/types.ts:82`: The scanline doc lists -1, 0-239 and 241-260 but the mapping in cpuState also yields 240 (jsnes's post-render line, scanline 261 or -1). Add 240 to the doc; the test at debugHooks.test.ts:46 only bounds the value and would not catch a mapping slip.
- `src/core/jsnesDebug.ts:206`: Formatting: `cpu.write =(address, value)` is missing the space after `=`; the rest of the file is formatted.
- `src/core/debugHooks.test.ts:170`: Comparing JSON strings with toBe(true) gives no diff on failure; expect(hooked.saveState()).toEqual(plain.saveState()) tests the same thing and names the differing field.
