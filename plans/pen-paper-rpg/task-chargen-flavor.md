# Character generator: many more names, monikers, surnames and backstories

Track: light

The generator in `chargen/` (read `README.md`, `rules.js`, `data/flavor.js`, `random.js` and the tests first) names a character from syllables (`names.first` + `middle` + `last`, 24/11/18 entries) plus an optional epithet (14), and gives a motivation (8) and an optional quirk (12). Make the tables much larger and include every name from the original game.

## Behaviour
- **Every name in the World of Dungeons NAMES page is in the tables.** Source: page 3 of the 1979 text, `/home/patrickb/pen-paper-rpg/resources/text/world_of_dungeons_1979.txt` (the "names" section, around line 138 on; the PDF is `/home/patrickb/pen-paper-rpg/resources/world_of_dungeons_1979.pdf` page 3 if the text columns are jumbled: render it with `pdftotext -layout -f 3 -l 3` if that is available, else read the text file carefully). The names are grouped by region: NORTHLANDS, IMPERIUM, REGENCY, XANATHAR & ISLANDS, URU & THE GREAT DESERT, ANKHKRA & CYTHONIS. Keep the groups, copy every name exactly (including accents and special letters such as Þ, ð, Ā), and add a test that lists the expected count per group so none is lost.
- **A name is a given name plus a surname, a moniker, or both:**
  - given names: all the PDF names, plus original ones in each region's style (at least 30 more per region);
  - surnames: at least 25 per region, original, in that region's style (e.g. patronymics for the Northlands, family names for the Imperium);
  - monikers: at least 120 original epithets in the current tables' voice ("the Unlucky", "Half-Ear", "of the Ninth Door", "Candle-Eater", …); keep the existing 11.
  Pick a region, then a given name from it, then a form, roughly: given + surname 45%, given + moniker 30%, given + surname + moniker 15%, given alone 10%. The region is not shown on the sheet.
- **Motivations ×10:** at least 80 (keep the existing 8), each completing "…, who ___." in the current voice: short, concrete, a hook for play, varied (debts, oaths, revenge, faith, curiosity, family, crimes, prophecies, love, ambition, cowardice). No duplicates, nothing that names a real person or place.
- **Quirks ×10:** at least 120 (keep the existing 12), the same dream-desert tone.
- Everything original apart from the PDF names; no text copied from other games.

## Design
- Change `makeName` in `rules.js` and the `names` shape in `data/flavor.js` (e.g. `names.regions: { Northlands: { given: [...], surnames: [...] }, ... }`, `names.monikers`). Keep `validateData`-style checks for the flavor tables (non-empty, no duplicates, no leading/trailing spaces).
- Seeds: the class, attributes, skills, abilities, gear, HP and spirits of a seed must not change (they are drawn before the name). The name, motivation and quirk of a seed will change; that is accepted. Re-record `tests/snapshot.json` deliberately and say so in the commit message; the snapshot test must still guard the draw order for everything drawn before the name (assert those fields equal the old recording).
- Rebuild `chargen/dist/chargen.html` and `chargen/dist/chargen.public.html` (`node chargen/build.js`, `node chargen/build.js --public`) and commit them.

## Prior art
Fantasy name generators (e.g. donjon, Fantasy Name Generators) use region/culture tables with given + family name + epithet; the PDF's own region lists are the base. No library.

## Tests
`node:test` in `chargen/tests/`: every PDF name present, per-group counts; table sizes meet the minimums; no duplicates; the four name forms all occur over many seeds and have roughly the stated shares (wide tolerance); fields drawn before the name are unchanged for the snapshot seeds; build tests pass.

## Leave alone
`ui.js`, `index.html`, `layout.js`, `edits.js`, `assets/`, everything outside `chargen/` (another branch is changing the sheet; do not touch its files).

## Commands
`node --test chargen/tests/<file>.test.js` (one or several), `node chargen/build.js`, `node chargen/build.js --public`, `node .ws-evidence/<script>.js` for scratch checks, `git add`, `git commit`. One command per Bash call.

## Done when
Every PDF name is in the tables, names combine given names with surnames and/or monikers across six regions, there are at least 80 motivations and 120 quirks, earlier draws per seed are unchanged, both builds are rebuilt, and the tests pass.
