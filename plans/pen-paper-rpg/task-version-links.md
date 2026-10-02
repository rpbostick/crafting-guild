# Links between the three generator versions

Track: light

There are three versions of the character generator: `chargen/` (the World of Dungeons sheet, published at `/chargen/`), `chargen-beta/` (the earlier free-form layout, `/chargen-beta/`) and `chargen-toybox/` (the sheet with animations and toys, `/chargen-toybox/` later). The toybox already links to the other two carrying the current character (see `pointVersions` in `chargen-toybox/ui.js`). Add the same to the other two.

## Behaviour
- `chargen/`: a small footer line under the credit, screen only (not printed, so the printed page stays one line of footer): "Also: the free-form beta · the toybox", each link carrying the current character (seed, class, quirk, attribute method, and the shared edit paths) the way the toybox does, updated whenever the character or edits change.
- `chargen-beta/`: its existing "Try the character sheet version" link carries the character the same way, and a second link to the toybox.
- Public builds use the site paths (`../chargen/`, `../chargen-beta/`, `../chargen-toybox/`); local builds use paths that work from each `dist/` folder, as `chargen-beta/build.js` already does.
- Share the link-building code (put it in a small shared module in `chargen/` used by all three, or reuse the toybox's) rather than writing it three times.

## Prior art
`pointVersions` in `chargen-toybox/ui.js` and `chargen-beta/build.js`'s per-output link.

## Tests
For each page, the built footer links point at the right paths for local and public builds and carry the character; Copy link and the version links describe the same character. All three pages' existing tests still pass. Rebuild and commit all six `dist/` files that change.

## Commands
`node --test chargen/tests/<file>.test.js chargen-beta/tests/<file>.test.js chargen-toybox/tests/<file>.test.js`, `node chargen/build.js` (and `--public`), `node chargen-beta/build.js` (and `--public`), `node chargen-toybox/build.js` (and `--public`), `git add`, `git commit`. One command per Bash call.

## Leave alone
Rules, data, layout and everything else on the three pages.

## Done when
Each version links to the other two with the current character, for local and public builds, with tests.
