# Character generator: true names from the game, a large original name pool, more backstories

Track: light

The generator in `chargen/` (read `README.md`, `rules.js`, `data/flavor.js`, `random.js` and the tests first) names a character from syllables (`names.first` + `middle` + `last`, 24/11/18 entries) plus an optional epithet (14), and gives a motivation (8) and an optional quirk (12). Make the tables much larger and include every name from the original game.

## Behaviour
- **True names come only from the PDF.** The World of Dungeons NAMES page says: "True names have power. If you tell someone your true name, they can attempt to have you raised from the dead if you meet your end before your time. Choose a true name from the list below." Source: page 3 of the 1979 text, `/home/patrickb/pen-paper-rpg/resources/text/world_of_dungeons_1979.txt` (the "names" section, around line 138 on; the PDF is `/home/patrickb/pen-paper-rpg/resources/world_of_dungeons_1979.pdf` page 3, use `pdftotext -layout -f 3 -l 3` if available, else read the text file carefully). The names are grouped by region: NORTHLANDS, IMPERIUM, REGENCY, XANATHAR & ISLANDS, URU & THE GREAT DESERT, ANKHKRA & CYTHONIS. Put them in `flavor.trueNames` by region, every name exactly as printed (accents and letters such as Þ, ð, Ā kept), with a test listing the expected count per region so none is lost. Each character gets a `trueName` from the same region as their everyday name.
- **Everyday names are a large, separate, original pool that never uses a true name.** A name is a given name plus a surname, a moniker, or both:
  - given names: at least 60 original names per region, in that region's style (the PDF names show the style), none equal to any true name;
  - surnames: at least 30 per region, original (e.g. patronymics for the Northlands, family names for the Imperium);
  - monikers: at least 120 original epithets in the current tables' voice ("the Unlucky", "Half-Ear", "of the Ninth Door", "Candle-Eater", …); keep the existing 11.
  Pick a region, then a given name from it, then a form, roughly: given + surname 45%, given + moniker 30%, given + surname + moniker 15%, given alone 10%. The region is not shown on the sheet. A test checks that no given name, surname or generated full name equals any true name (case-insensitive).
- **Motivations ×10:** at least 80 (keep the existing 8), each completing "…, who ___." in the current voice: short, concrete, a hook for play, varied (debts, oaths, revenge, faith, curiosity, family, crimes, prophecies, love, ambition, cowardice). No duplicates, nothing that names a real person or place.
- **Quirks ×10:** at least 120 (keep the existing 12), the same dream-desert tone.
- Everything original apart from the true names; no text copied from other games.
- Where the true name appears on the sheet is decided separately (another branch owns the sheet). Here: `rules.roll()` returns `trueName`, and the README documents it.

## Design
- Change `makeName` in `rules.js` and the `names` shape in `data/flavor.js` (e.g. `names.regions: { Northlands: { given: [...], surnames: [...] }, ... }`, `names.monikers`, `trueNames: { Northlands: [...], ... }`). Keep `validateData`-style checks for the flavor tables (non-empty, no duplicates, no leading/trailing spaces, no overlap with true names).
- Draw order: the true name is drawn last (after the quirk), so adding it moves nothing else. The class, attributes, skills, abilities, gear, HP and spirits of a seed must not change (they are drawn before the name). The name, motivation and quirk of a seed will change; that is accepted. Re-record `tests/snapshot.json` deliberately and say so in the commit message; the snapshot test must still guard the draw order for everything drawn before the name (assert those fields equal the old recording).
- Rebuild `chargen/dist/chargen.html` and `chargen/dist/chargen.public.html` (`node chargen/build.js`, `node chargen/build.js --public`) and commit them.

## Prior art
Fantasy name generators (e.g. donjon, Fantasy Name Generators) use region/culture tables with given + family name + epithet; the PDF's own region lists are the base. No library.

## Tests
`node:test` in `chargen/tests/`: every PDF name present in `trueNames`, per-region counts; no overlap between the everyday tables and the true names; `trueName` drawn from the same region; table sizes meet the minimums; no duplicates; the four name forms all occur over many seeds and have roughly the stated shares (wide tolerance); fields drawn before the name are unchanged for the snapshot seeds; build tests pass.

## Leave alone
`ui.js`, `index.html`, `layout.js`, `edits.js`, `assets/`, everything outside `chargen/` (another branch is changing the sheet; do not touch its files).

## Commands
`node --test chargen/tests/<file>.test.js` (one or several), `node chargen/build.js`, `node chargen/build.js --public`, `node .ws-evidence/<script>.js` for scratch checks, `git add`, `git commit`. One command per Bash call.

## Done when
Every PDF name is a true name and none is an everyday name, everyday names combine given names with surnames and/or monikers across six regions, there are at least 80 motivations and 120 quirks, earlier draws per seed are unchanged, both builds are rebuilt, and the tests pass.
