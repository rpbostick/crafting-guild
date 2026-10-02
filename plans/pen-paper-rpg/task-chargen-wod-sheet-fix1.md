# Character sheet: ruled lines, name and class fields

Track: light

Continue on this branch (the character on the World of Dungeons sheet). Changes after a preview:

## Behaviour
- **Ruled lines, fixed height, continuous.** WEAPONS, EQUIPMENT and NOTES are lined paper: thin ruled lines in the sheet's teal (light, e.g. 35% opacity) at one fixed line height, running edge to edge across the box and all the way down it, whether or not a line has text. Text sits on the lines; every line is the same height.
  - WEAPONS: lines `1)` to `8)` are each exactly one ruled line; spread them so the 8 lines fill the box evenly. A weapon never makes its line taller: the name and damage are on the line, and the notes (e.g. "Light weapon (off-hand: re-roll damage once per attack)") follow the name in small type on the same line, cut with an ellipsis when too long (full text in a `title` tooltip). Add each weapon's full notes to NOTES too, so the print keeps them.
  - EQUIPMENT and NOTES: one editable block each, with line height equal to the ruling (draw the ruling as a background on the block so wrapped and typed lines always land on a line; `background-attachment: local` so it scrolls with text on screen). Enter starts a new line, long lines wrap onto the next ruled line.
- **NAME and CLASS:** move the text right so it starts clear of the box's left notch and lines up under the "NAME" / "CLASS" label text (with a little padding), and make it larger: about the size of the attribute values, fitted so the longest rolled name with epithet still fits on one line (shrink only if it would overflow). LEVEL matches the CLASS size.
- Print: the ruled lines print; the rest of the print behaviour is unchanged.

## Prior art
CSS `repeating-linear-gradient` backgrounds for ruled lines; `text-overflow: ellipsis` for one-line weapon notes.

## Tests
Update `chargen/tests/sheet.test.js`: weapon lines are fixed height (each slot one line; notes have the one-line class); Notes includes the weapon notes; the equipment and notes blocks use the ruled line height. Rebuild both outputs (`node chargen/build.js`, `node chargen/build.js --public`) and commit them. Screenshots as before (`after-fix1-wizard.png`, `after-fix1-fighter.png`, and one with a long typed equipment list showing wrapping on the lines).

## Commands
`node --test chargen/tests/<file>.test.js`, `node chargen/build.js`, `node chargen/build.js --public`, `firefox --headless …` (as in the first task), `git add`, `git commit`. One command per Bash call.

## Done when
Weapons, Equipment and Notes show continuous evenly spaced ruled lines that text sits on, weapon lines never grow, name and class are larger and indented, both builds are rebuilt, and the tests pass.
