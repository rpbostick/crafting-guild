# Character sheet: a wider sheet, weapons with notes lines, one-line footer

Continue on this branch (the character on the World of Dungeons sheet, with ruled lines). Changes after a preview:

## The sheet becomes wider
The sheet now fills the width of a US Letter page (about 8 in wide inside the print margins) instead of keeping the PNG's narrow 0.6 aspect, and still prints on one page. Do not stretch the PNG: that distorts the lettering. Instead rebuild the frame at the new width:
- Draw the teal frame, bars, box outlines and notched corners with CSS or inline SVG in the sheet's teal (sample it from `assets/wod-sheet.png`, about `#007AA1`).
- Keep the original lettering by cropping it from `assets/wod-sheet.png` at build time or by hand into small images (the WORLD OF DUNGEONS title, the white bar headings ATTRIBUTES / SKILLS / SPECIAL ABILITIES / ARMOR & SPEED / HIT DICE / HIT POINTS, the big STR … CHA labels, the skill and ability lists, the armor-circle labels, COIN, XP and the small box labels), or by setting them in close free fonts if a crop would look worse. Say which you chose for each. Commit any cropped images under `chargen/assets/` and inline them in the build like the sheet PNG. The page must still look like the original sheet, just wider.
- Layout changes at the new width:
  - NAME box wider (it takes the extra width in the top row; CLASS and LEVEL keep about their size).
  - ATTRIBUTES box wider and left-justified, with the ATTRIBUTES heading centred over its two columns (STR/DEX/CON and INT/WIS/CHA). SKILLS and SPECIAL ABILITIES keep their size, to its right.
  - WEAPONS and EQUIPMENT boxes wider (split the full width between them, about half each).
  - ARMOR & SPEED row: a clear gap between the armor group (circles, TOTAL ARMOR) and the HIT DICE / HIT POINTS boxes.
  - NOTES box wider (full width) and a little taller than now.
- The ruled lines from the last round stay: same fixed line height, continuous, in Equipment and Notes.

## Weapons
- No line numbers.
- Each weapon slot is two lines: the weapon's name and damage on a normal ruled line, and under it one line of tiny text for its notes (as the first round showed under the Dagger). Every slot has the tiny line, including empty slots, and both lines are editable. Fit as many slots as the box holds at this size (6 or 7 is fine; say how many).
- Attacks that aren't from a weapon item become weapon entries too, after the carried weapons: for example the Wizard's "Magical attack" (damage `2d6+1`, notes "3d6+1 if well suited"), and any other ability `note` that states an attack. Say which ability notes you treated as attacks.
- Weapon notes no longer go into NOTES. NOTES keeps: motivation, ability names and text, other ability notes, known spirits, the quirk, the hit dice rolled.

## Footer
One line at the bottom of the printed page, slightly smaller type: "Built on *World of Dungeons* by John Harper, CC BY 3.0. The same seed, class and quirk setting always roll the same character." Keep both links (the game title to itch.io, "CC BY 3.0" to the licence). Check it is one line in print at Letter width.

## Prior art
Inline SVG or CSS borders for the frame; CSS `clip-path` or SVG paths for the notched corners; image sprites (`background-position` or `<img>` with `object-position`) for the cropped lettering. No library needed.

## Tests
Update `chargen/tests/sheet.test.js` and the UI tests: the weapon slots have a name/damage field and a notes field each and no numbers; the Wizard's magical attack is a weapon entry; Notes has no weapon notes; every box in the coordinate table is inside the page; the footer is the exact text; the build inlines every image (no external URLs) and the public build passes the leak check. Rebuild both outputs (`node chargen/build.js`, `node chargen/build.js --public`) and commit them. Screenshots (one per call, absolute paths): `after-fix2-wizard.png` (`?seed=abc&class=Wizard&quirk=1`), `after-fix2-fighter.png`, and `after-fix2-letter.png` at a window of 816 × 1056 to show the printed proportions. Name what you could not check in print.

## Leave alone
`rules.js` behaviour, `data/`, everything outside `chargen/`.

## Commands
`node --test chargen/tests/<file>.test.js` (one or several), `node chargen/build.js`, `node chargen/build.js --public`, `firefox --headless …` (as before), `git add`, `git commit`. One command per Bash call. For cropping images, write a small committed Node script under `chargen/scripts/` that uses only Node built-ins (PNG decode/encode with `zlib`) or does the crop in the browser canvas at build time; do not add a native image dependency.

## Done when
The sheet fills the letter width with the original look, the boxes are resized as listed, weapons are unnumbered two-line slots with attacks included, Notes has no weapon notes, the footer is one line, both builds are rebuilt, and the tests pass.
