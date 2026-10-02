# Character sheet: the true name inside the NAME box

Track: light

Continue on this branch (the character on the World of Dungeons sheet). `rules.roll()` now returns `trueName` (one of the names from the game's NAMES page; see `data/flavor.js` `trueNames` and the README). Show it on the sheet.

## Behaviour
- **Inside the NAME box, at its right end:** a small "TRUE NAME" label in the same style as the box's own NAME label (the sheet's small teal lettering; take the letters from the art like the other labels, or the closest match the sheet code already uses for small labels), right-aligned near the top right of the box. Under it, the true name, right-aligned, in the field font and ink but smaller than the everyday name (about 75% of its size).
- **Vertical alignment:** the true name's baseline sits on the same line as the everyday name's baseline (a little lower than the mockup showed), not higher.
- The everyday name keeps the left part of the box; if a long everyday name would run into the true name, the everyday name shrinks to fit first, then the true name.
- The true name is an editable field like the others (pre-filled, edited mark, reset, carried in Copy link). Copy as text adds a line "True name: …". Print and the blank sheet show the label; the blank sheet leaves the value empty.
- Both art styles. Not shown in Notes.

The chosen mockup is `/home/patrickb/agentic-workspace-v2/runs/pen-paper-rpg/staging/portrait/true-name-B.png` (open it); match it, with the true name lower as above.

## Prior art
The sheet's existing label and field placement code. No library.

## Tests
The NAME box holds both fields; the true name field is right-aligned with its baseline equal to the name's (compare computed box positions); edits to it round-trip through the link; Copy as text has the line; the blank sheet shows the label without a value. Rebuild both outputs and commit them. Screenshots: `after-truename-wizard.png`, and one with a long everyday name.

## Leave alone
`rules.js`, `data/`, everything outside `chargen/`.

## Commands
`node --test chargen/tests/<file>.test.js` (one or several), `node chargen/build.js`, `node chargen/build.js --public`, `node chargen/scripts/<script>.js`, `node .ws-evidence/<script>.js`, `firefox --headless …` (as before), `git add`, `git commit`. One command per Bash call.

## Done when
The true name shows right-aligned inside the NAME box under a small TRUE NAME label, baseline-aligned with the name, editable and in the link and text, both builds are rebuilt, and the tests pass.
