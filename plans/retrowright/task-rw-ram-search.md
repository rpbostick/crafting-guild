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
