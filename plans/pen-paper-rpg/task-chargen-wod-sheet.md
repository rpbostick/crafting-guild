# Character generator: the rolled character on the World of Dungeons character sheet

The generator in `chargen/` (read `README.md`, `rules.js`, `edits.js`, `ui.js`, `index.html`, `build.js` and the tests first) shows the character as a free-form sheet. Replace that sheet with the official World of Dungeons character sheet: `chargen/assets/wod-sheet.png` (1350 × 2250 px, 300 dpi, teal vector art on a transparent background) is the background, and the character's fields sit inside its boxes as editable form fields. One character = one US Letter page when printed.

Look at the PNG first. Its boxes, top to bottom: the WORLD OF DUNGEONS title; NAME, CLASS, LEVEL; ATTRIBUTES (STR, DEX, CON on the left, INT, WIS, CHA on the right, each with an empty octagon box to its left for the value), SKILLS (a list of the nine skills), SPECIAL ABILITIES (the twenty abilities in pairs); WEAPONS and EQUIPMENT side by side; ARMOR & SPEED (circles for NONE/FAST, LIGHT/NORMAL, FULL/SLOW, SHIELD, and a shield-shaped TOTAL ARMOR box), HIT DICE, HIT POINTS; a large NOTES box; COIN, NEEDED FOR NEXT LEVEL, XP.

## Behaviour
- **Page:** the sheet image scaled to fill a US Letter page (keep its aspect ratio; centred; it fits the height, about 10.2 in tall) with the credit line under it at the bottom of the page. On screen the page is shown at its printed proportions, scaled down to the window width on narrow screens. The controls (class, quirk, attribute method, Roll, Copy as text, seed, Copy link) stay above the page as they are.
- **Fields in the sheet's boxes**, all editable with the existing edit/reset machinery (pre-filled with the rolled value, edited mark, reset, Reset all, carried in Copy link and Copy as text):
  - NAME: name with epithet. CLASS: the class. LEVEL: `1`.
  - Attribute values in the octagon boxes beside STR … CHA (signed, `+1`). In the "Standard array, choose" method the box holds the `<select>`.
  - SKILLS and SPECIAL ABILITIES: the sheet already prints every name; mark the character's own with a filled dot or a hand-drawn-style circle around the word. Clicking a skill or ability name toggles its mark (an edit, carried in the link).
  - WEAPONS: numbered lines `1)` to `8)`. Slot 1 is the starting weapon (name and damage; its notes go small after the name or wrap). Slots 2 to 8 are empty fields to type in. A second starting weapon, if a kit has one, takes slot 2.
  - EQUIPMENT: one editable text block, word wrap and Enter for new lines, pre-filled with the gear one item or group per line.
  - ARMOR & SPEED: fill the circle for the armor type (none, light, full) and SHIELD when the character has one; TOTAL ARMOR shows the armor value. Clicking a circle toggles it.
  - HIT DICE: e.g. `1d6`; HIT POINTS: the HP. The "(rolled 3)" detail goes in Notes.
  - NOTES: one editable text block (word wrap, Enter for new lines) holding, in order: motivation ("Exiled for an honest mistake"), each special ability's name and text, ability notes (e.g. the magical attack line), known spirits, the quirk, the hit dice rolled.
  - COIN: the silver left. NEEDED FOR NEXT LEVEL: `1,000` (the XP table's level 2). XP: `0`.
- Text sizes fit the boxes; long text wraps inside its box and never spills over the art (shrink a little or clip with a scroll on screen; in print, the box keeps its size).
- **Footer**, at the bottom of the printed page under the sheet, only: "Built on *World of Dungeons* by John Harper, licensed under CC BY 3.0 (character sheet from the original game). The same seed, class and quirk setting always roll the same character." with the two existing links. Drop the rest of the current footer.
- **Print:** exactly one page; no controls, edit marks or reset buttons; the art and filled values print; `@page { size: letter; margin: 0.3in }` or similar.
- Dark mode: the page stays white paper with teal art in both themes (it is a printed sheet); the surroundings follow the theme.
- Accessibility: every field keeps its accessible label; skill/ability/armor toggles are buttons with `aria-pressed`.

## Design
- `build.js` inlines the PNG as a `data:` URI so `dist/chargen.html` and the public build stay single files. Keep the public build's leak check passing.
- Position fields with percentages of the sheet box (an absolutely positioned layer over the image), from one table of box coordinates measured on the PNG, so the layout is easy to adjust. Write the table with comments naming each box.
- `rules.js` stays unchanged in behaviour. New field paths (`weapons.2.name` … for typed slots, `notes`, `skills.mark.<Skill>`, `abil.mark.<key>`, `armor.mark.<type>`, `shield`, `xp`, `xpNext`, `level`) go through `edits.js`; Copy as text lists the same information as today plus the typed weapons, marks and notes.

## Prior art
Overlaying HTML form fields on a scanned or exported form image with absolute percentage positions is the standard approach (fillable-PDF-style web forms); no library needed. `pdf-lib` (MIT) can fill PDF forms, but the sheet has no form fields and a print-from-browser page is what the generator already does.

## Tests
`node:test` in `chargen/tests/`: the sheet renders every field in the box table; marks for the rolled skills/abilities/armor; toggling a mark is an edit that round-trips through the link; weapon slots 2 to 8 accept typed text that round-trips; Notes holds the listed items; the footer text is exactly the two sentences; the build inlines the PNG (no external image URL) and the public build still passes its leak check. Existing tests keep passing (update UI expectations that change with the layout, and say which).
Screenshots for the reviewer, one per call, absolute paths: `firefox --headless --window-size=1000,1400 --screenshot <worktree>/.ws-evidence/after-<name>.png "file://<worktree>/chargen/dist/chargen.html?seed=abc&class=Wizard"` for: the Wizard; `class=Fighter` with seed `abc`; the Wizard with `attrs=pick` and an `arr=`; and a print check: `firefox --headless --print` is not available, so add a `?print=1` test hook only if you need one, or screenshot with the window sized to letter proportions (816 × 1056) and state what you checked.

## Leave alone
`rules.js` behaviour, `data/`, `assets/wod-sheet.png`, everything outside `chargen/`.

## Commands
`node --test chargen/tests/<file>.test.js` (one or several files), `node chargen/build.js`, `node chargen/build.js --public`, `firefox --headless …` as above, `git add`, `git commit`. One command per Bash call.

## Done when
The generated character appears inside the World of Dungeons sheet on one printable letter page, every field is editable and carried in links, the footer is the two sentences at the page bottom, both builds are rebuilt and committed, and all tests pass.
