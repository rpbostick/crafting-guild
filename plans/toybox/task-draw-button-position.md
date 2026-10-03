# Toybox: the Draw button can be moved, or placed in any corner

Track: light

`<draw-layer>` shows a small Draw toggle (which grows into the tool bar while drawing) fixed in the window's lower left corner (read `src/draw/`, `README.md`, `tests/draw-*.test.js`). Users want to choose where it sits.

## Behaviour
- A **corner** setting: lower left (default), lower right, upper left, upper right, chosen from a small menu on the tool bar (a "⋯" or corner icon) and via an attribute `corner="bottom-left|bottom-right|top-left|top-right"` on `<draw-layer>`.
- The button can also be **dragged** anywhere by a grip on its edge (pointer and touch), kept fully on screen and clear of the window edges; "Reset position" in the same menu snaps it back to the chosen corner. The expanded tool bar opens toward the middle of the screen from wherever the button is.
- Position and corner remembered per browser (per page key).
- **Also (from the character sheet integration):** an option to keep **Show scribbles / Print scribbles** per browser rather than per layer id: attribute `toggles-scope="browser|layer"` (default `layer`, as now); and a hook for extra fields in saved files (`toybox.onSaveFile(fn)` returning extra JSON fields, and `toybox.onOpenFile(fn)` receiving them), plus an attribute on `<toy-pages>` to hide its own Save/Open/Print buttons (`buttons="none"`) when the host page provides its own. And an option for the wash strength of registered (plug-in) backgrounds (`wash` in `registerBackground`'s options, default as now).
- CHANGELOG 0.4.1; rebuild `dist/`; `bash scripts/release.sh` writes the new release zip.

## Prior art
The dice tray's existing drag and window-state code in this library (reuse it for the draggable button). No library.

## Tests
Corner attribute and menu; drag keeps the button on screen; reset; persistence; the tool bar opens toward the screen centre; `toggles-scope="browser"`; the save/open hooks round-trip extra fields; `buttons="none"`; plug-in wash option. Firefox e2e: move the button to the upper right and draw.

## Commands
`npm ci`, `npx …`, `node …`, `bash build.sh`, `bash scripts/release.sh`, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
The Draw button can be put in any corner or dragged anywhere and remembers it, the integration options exist, release 0.4.1 is built, and the tests pass.
