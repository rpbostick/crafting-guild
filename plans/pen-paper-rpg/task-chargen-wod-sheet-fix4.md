# Character sheet: portrait box, tighter attributes, wider hit dice and hit points

Continue on this branch (the character on the letter-width World of Dungeons sheet). Layout changes chosen from mockups. The chosen mockup is `/home/patrickb/agentic-workspace-v2/runs/pen-paper-rpg/staging/portrait/mockup-chosen.png` (1764 × 2250, the same scale as the wide sheet; open it), made by `mock.py` next to it from `assets/wod-sheet.png`. Match it.

## Behaviour
- **Top band, left to right: ATTRIBUTES · SKILLS · SPECIAL ABILITIES · PORTRAIT.**
  - ATTRIBUTES: the STR … CHA names about 15% smaller; the second column (INT/WIS/CHA octagons and names) pulled left so the box is no wider than it needs to be; the ATTRIBUTES heading re-centred over the box.
  - SKILLS and SPECIAL ABILITIES keep their size, right after it, as on the original sheet.
  - **PORTRAIT**: a new box filling the rest of the band's width (close to square, about 465 × 450 px of art), white with the same notched corners and dividers as the other boxes, and a PORTRAIT heading in the white heading lettering. Build the word from letters cropped out of the sheet's own headings (P, O, R, T, A, I from SPECIAL ABILITIES, ATTRIBUTES, ARMOR & SPEED, HIT POINTS), kerned to match; the mockup's stand-in font is only a placeholder. On screen and in print the box is empty, for drawing a portrait by hand.
  - Field positions (attribute values in the octagons, the skill and ability marks) move with the art.
- **HIT DICE and HIT POINTS boxes twice as wide** (about 368 px of art each instead of 184), their headings centred over them; the armor group (circles, TOTAL ARMOR) unchanged at the left. The remaining width goes into the gap between TOTAL ARMOR and HIT DICE (much smaller than the current 2 in teal block).
- Both art styles (Color and Printer friendly) get the same layout; print still fits one Letter page.

## Design
The seam-widening model in `layout.js` cannot reorder or insert boxes, so the top band (and the armor band) are assembled from pieces instead: crop each block from the art (attribute octagon columns, attribute name lettering, SKILLS, SPECIAL ABILITIES, dividers, edges, heading lettering), place them in order, draw the new portrait box, and stretch box interiors at their middle column (as `mock.py` does for the hit dice boxes). Keep this in the same table-driven style (one description of the band's pieces and their x positions) so `toSheet()` still maps art boxes to sheet positions, and the B&W art uses the same pieces. Remove code the old seam bands no longer need.

## Prior art
`mock.py` (the mockup generator above) already does the crops and placement in Python/PIL; port its piece list and arithmetic to the sheet-art script in Node. No library needed.

## Tests
Update the layout and sheet tests: the band order, the portrait box present and inside the page, attribute names scaled, HIT DICE / HIT POINTS box widths doubled, every field's box inside its art box in both art styles, one-page print fit. Rebuild both outputs and commit them. Screenshots: `after-fix4-wizard.png`, `after-fix4-bw.png`, and one at 816 × 1056.

## Leave alone
`rules.js` behaviour, `data/`, `assets/wod-sheet.png` and `wod-sheet-bw.png`, everything outside `chargen/`.

## Commands
`node --test chargen/tests/<file>.test.js` (one or several), `node chargen/build.js`, `node chargen/build.js --public`, any committed `chargen/scripts/*.js` with `node`, `firefox --headless …` (as before), `git add`, `git commit`. One command per Bash call.

## Done when
The top band reads Attributes · Skills · Special abilities · Portrait as in the mockup, the attribute names are smaller with the second column pulled in, HIT DICE and HIT POINTS are twice as wide, both art styles match, both builds are rebuilt, and the tests pass.
