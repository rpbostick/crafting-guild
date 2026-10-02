# chargen-beta: the earlier free-form layout, kept current with the generator's logic

The generator in `chargen/` now draws the character on the World of Dungeons sheet. Its earlier layout (a free-form indigo "ditto" sheet: big name, attribute boxes, Skills/Special abilities and Survival/Weapons columns, Equipment, Known spirits, editable fields, the attribute method control) is worth keeping as a second page. Create `chargen-beta/`: that earlier layout, driven by the same logic as `chargen/` today, so both pages roll the same character for the same link.

The earlier layout is at commit `d717e9a` (`git show d717e9a:chargen/index.html`, `…:chargen/ui.js`, `…:chargen/edits.js`, `…:chargen/build.js`); its published copy is the page now at `/chargen-beta/` on the site. Read today's `chargen/README.md`, `rules.js`, `edits.js`, `data/`, `random.js` and `build.js` too.

## Behaviour
- **Same logic as `chargen/`:** the same seeds, class choice, quirk flag and attribute methods (Roll 2d6, standard array random, standard array choose) give the same character as `chargen/` for the same link: regional names with surnames and monikers, the **true name**, motivations and quirks from today's tables; CON-driven hit dice and HP in the array methods; equipment written as a comma paragraph with merged counts ("Quicksilver (2)"); attacks from abilities (e.g. Magical attack) listed with the weapons; Copy as text identical to `chargen/`'s.
- **Shared code, not copies:** `chargen-beta/` uses `chargen/rules.js`, `chargen/data/`, `chargen/random.js` and the parts of `chargen/edits.js` it needs (base fields, apply/diff, link encoding, gear paragraph) directly, so a logic fix in `chargen/` reaches both pages. Only the layout and page wiring (its own `index.html`, `ui.js`) live in `chargen-beta/`. If `chargen/edits.js` mixes sheet-specific field paths with shared logic, split the shared part out in a way that leaves `chargen/` behaviour and its tests unchanged.
- **Layout as it was:** the free-form sheet, its fonts, colours and ink bleed, the editable fields with reset marks, Copy as text / Copy link, Roll with the inline confirm, the attribute method control, the print stylesheet. Add only what the new logic needs, in the same style: the true name shown small under or beside the name (labelled "true name"), and the attacks in the weapon list.
- **Links between the two pages:** a link made on either page opens the same character on the other (same parameters and edit paths where the fields exist; fields that exist only on one page are ignored by the other, with no error notice).
- A small footer line "Try the character sheet version" linking to `../chargen/` (and from `chargen/`, nothing changes).
- Build: `node chargen-beta/build.js` (and `--public`, with the same leak check as `chargen/`) writes `chargen-beta/dist/chargen-beta.html` and `chargen-beta/dist/chargen-beta.public.html`, single self-contained files.

## Prior art
The page's own earlier version at `d717e9a`, and today's `chargen/` modules. No library.

## Tests
`node:test` in `chargen-beta/tests/`: for the snapshot seeds in `chargen/tests/snapshot-cases.js`, Copy as text from `chargen-beta` equals `chargen`'s; a link with edits made for one page opens on the other; the true name and attacks render; the build is current and the public build passes its leak check. `chargen/`'s tests still pass unchanged. Rebuild and commit both `chargen-beta/dist/` files.

## Leave alone
`chargen/` behaviour and layout (only a shared-logic split if needed), everything outside `chargen/` and `chargen-beta/`.

## Commands
`node --test chargen/tests/ chargen-beta/tests/` (or file lists), `node chargen-beta/build.js`, `node chargen-beta/build.js --public`, `node chargen/build.js` and `--public` if shared code changed, `node .ws-evidence/<script>.js`, `firefox --headless …` for screenshots (absolute paths, one per call), `git show d717e9a:<path>`, `git add`, `git commit`. One command per Bash call.

## Done when
`chargen-beta/` renders the earlier layout from the shared logic, same links give the same character on both pages, both builds are committed, and all tests pass.
