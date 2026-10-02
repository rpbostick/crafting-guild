# Spike: a try-it page for drawing on the sheet, extra pages and the portrait editor

A working mockup, not production code, to try four features before they go into the character generator. Read `docs/research/drawing-and-pages.md` first (it recommends drauu, MIT, built on perfect-freehand, plus idb-keyval for storage, and lists what is still unverified in its section 7). Everything lives in `spikes/drawing/`. `spikes/drawing/base-sheet.html` is a copy of the current generator page (self-contained, the World of Dungeons sheet with the character filled in); build the mockup on a copy of it.

## Features to mock up
1. **Scribble on the sheet:** a floating tool bar (pen, highlighter, eraser, color, size, undo, redo, clear) and a **"Draw" toggle** that turns the drawing layer on (pointer draws instead of editing fields) and off (fields editable again). A separate **"Show scribbles"** toggle hides or shows them on screen and in print. Pressure from pen tablets and touch where the browser reports it. Strokes scale with the sheet.
2. **Extra notes pages:** an "Add notes page" button adds a ruled page below the sheet, styled like the sheet's NOTES box (same teal frame and ruling, Courier Prime in the sheet's ink), with a title line; pages can be removed and reordered (up/down). The scribble layer works on them too.
3. **Drawing pad pages:** "Add drawing page" adds a blank page with the same tool bar; paste an image from the clipboard (Ctrl+V) or drop one onto it, move and scale it, draw over it; copy the page out as PNG (Ctrl+C or a Copy button).
4. **Big portrait editor:** clicking the PORTRAIT box opens a full-page editor (an overlay page): paste or drop an image, move/scale/crop it into the box's shape, draw over it with the same tools; "Done" shrinks it back into the portrait box. Copy and paste work in the editor.
- **Saving:** everything (scribbles per page, notes text, drawing pages with their images, the portrait) autosaves in the browser (IndexedDB via idb-keyval) and survives a reload; **"Save character file"** downloads one file (JSON with the images embedded; report a typical size) and **"Open character file"** restores it.
- **Print:** the sheet and then each extra page, one per Letter page; scribbles printed or not per the toggle.
- Check the open items in the research's section 7 and record the answers: highlighter transparency through drauu's dump/load, clipboard PNG copy-out from `file://` and from `http://localhost` in Firefox (and Chrome if available), IndexedDB from `file://`.

## Deliverables
- `spikes/drawing/dist/index.html`, built and committed, plus sources and a one-command rebuild (`spikes/drawing/build.sh` or package scripts). Prefer inlining everything into the one page as the generator does.
- `spikes/drawing/NOTES.md`: what worked, what didn't, the section 7 answers, sizes (library and a saved character with two drawn pages and a pasted portrait), and recommendations for the real build.
- Screenshots under `.ws-evidence/`: drawing on the sheet, a notes page, a drawing page with a pasted image, the portrait editor open and the portrait shrunk into the box, and a print-size render.

## Prior art
drauu (MIT), perfect-freehand (MIT), idb-keyval (Apache-2.0), per the research doc. Do not add other libraries without saying why.

## Leave alone
Everything outside `spikes/drawing/` (the generator in `chargen/` is being changed on another branch).

## Commands
From the worktree root: `npm install --prefix spikes/drawing <packages>`, `npx --prefix spikes/drawing <tool>` (esbuild), `node <script>`, `cp` inside the worktree, `bash spikes/drawing/build.sh`, `firefox --headless …` for screenshots (absolute paths, one per call), `python3 -m http.server 8796 --bind 127.0.0.1 --directory spikes/drawing/dist` (in the background only while testing, then stop it by its PID), `git add`, `git commit`. One command per Bash call.

## Done when
The page lets you draw on the sheet with a toggle, add notes and drawing pages, edit a pasted portrait in a big editor that shrinks into the box, save and reopen it all, and print it; NOTES.md records the findings; the build is committed and reproducible.
