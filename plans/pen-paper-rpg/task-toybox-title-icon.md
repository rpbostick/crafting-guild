# Toybox: title, heading link and browser icon

Track: light

Small changes to `chargen-toybox/` before it is republished (read `index.html`, `build.js`, `tests/build.test.js`, `tests/public-build.test.js`, `tests/pages.test.js`).

## Behaviour
- **Title** (the `<title>` and the page heading): "Dungeon Character Toybox".
- **The heading's "*World of Dungeons*" text** (in "for *World of Dungeons* by John Harper") links to `https://johnharper.itch.io/world-of-dungeons`, styled like the heading (no default blue), with a visible focus style.
- **Browser icon:** `assets/favicon.ico` (16, 32, 48), `assets/icon-32.png` and `assets/icon-180.png` (Apple touch icon) are committed. Inline them into both builds as `data:` URIs (`<link rel="icon" sizes="any" href="data:image/x-icon…">`, `<link rel="icon" type="image/png" sizes="32x32" …>`, `<link rel="apple-touch-icon" …>`), so the single-file page carries its own icon; the public build's leak check must still pass.
- Update tests that pin the old title or heading.

## Commands
`node --test chargen-toybox/tests/<file>.test.js` (one or several), `node chargen-toybox/build.js`, `node chargen-toybox/build.js --public`, `git add`, `git commit`. One command per Bash call.

## Done when
Both builds have the new title, the linked heading text and the inlined icons, and the toybox tests pass.
