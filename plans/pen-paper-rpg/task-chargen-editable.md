# Character generator: every generated field is editable

The generator in `chargen/` (read `chargen/README.md`, `rules.js`, `ui.js`, `build.js` and the tests first) rolls a character from a seed and shows it as a sheet. Make every field on the sheet editable by the player, pre-filled with the rolled value.

## Behaviour
- **Every generated field is editable in place:** the name (including the epithet), the class line and motivation, each attribute value, skills, special abilities (name and text), hit points, hit dice, armor, speed, each weapon (name, notes, damage), equipment, coin left, each spirit (name, look, domains), and the quirk. The rolled text fills each field by default.
- Editing is **free text**: changing CON does not recompute HP. Deliberate: the player decides; a recalculation would overwrite their edits.
- An edited field is marked subtly (for example a small dot or an underline in the accent colour) and has a way to **reset it to the rolled value**. A **Reset all edits** control appears when anything is edited.
- **Copy as text** uses the edited values.
- **Copy link** carries the edits: the link holds the seed, class choice, quirk flag and only the changed fields (compact, URL-safe encoding), so opening it shows the same edited character. A link with no edits is the same as today's link.
- **Roll a character** with unsaved edits asks for confirmation first (a simple inline confirm, not `window.confirm`), then rolls fresh with no edits.
- Keyboard and screen-reader friendly: each editable field has an accessible label; Enter in a single-line field ends editing; the print stylesheet prints the edited values without edit marks or controls.

## Design
- Keep `rules.js` pure and unchanged in behaviour: a rolled character is the base; edits are a separate map `{ fieldPath: text }` applied on top in the UI layer (for example `chargen/edits.js`, pure: apply, encode, decode, diff against the rolled character). Field paths are stable names (`name`, `attrs.STR`, `weapons.0.damage`, `spirits.1.look`, …).
- Encode/decode must round-trip any Unicode text and reject a malformed link without breaking the page (show the rolled character and a short notice).

## Prior art
Native browser editing (`contenteditable="plaintext-only"` or styled `<input>`/`<textarea>` elements) covers in-place editing; no editor library is needed for plain-text fields. For the link encoding, `URLSearchParams` plus `TextEncoder` and base64url (built-ins) are enough; consider `lz-string` (MIT) only if links with many edits get long (over about 2,000 characters), and say which you chose and why.

## Also (from the previous review)
- `chargen/NOTES.md`: remove the "Owner: …" line with the personal details and timezone.
- `chargen/package.json`: make the test script portable (`node --test` with a directory or default discovery, not a shell glob), and check it runs.

## Tests
`node:test`, in `chargen/tests/`: `edits.test.js` (apply, reset one, reset all, diff, encode/decode round trip including non-ASCII text, malformed input rejected); UI tests through the existing stub-window approach: editing a field changes `asText`, the edited mark appears and reset removes it, a link with edits reproduces them, re-roll with edits asks first; the existing snapshot and build tests still pass with no edits. Rebuild `chargen/dist/chargen.html` with `node chargen/build.js` and commit it.

## Leave alone
`chargen/rules.js` behaviour (its tests and the snapshot must pass unchanged), `chargen/data/`, everything outside `chargen/`.

## Commands
`node --test chargen/tests/<file>.test.js` (one or several files), `node chargen/build.js`, `git add`, `git commit`. One command per Bash call.

## Done when
Every generated field can be edited in place and reset, edits flow into Copy as text and Copy link, re-rolling over edits asks first, the dist file is rebuilt, and all tests pass.
