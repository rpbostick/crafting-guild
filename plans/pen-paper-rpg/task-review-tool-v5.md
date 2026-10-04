# Review page: round 3 on version 5

The review page (`site/`, built by `scripts/build-review.js` to `site/dist/review.html`, published to a claude.ai artifact with a database) reviews `rules/v3/synthesis.md` in round 2, storing that round's decisions, notes and resolutions in `decisions-r2`, `notes-r2`, `resolutions-r2` (see `site/store.js` `ROUNDS`). Round 2 is finished: its results are exported to `rules/v3/round2-decisions.json` and `rules/v3/round2-review-notes.json` (80 decisions, 41 notes). Two versions have been written since and are not on the page: `rules/v4/` and `rules/v5/` (each with `synthesis.md`, `CHANGES.md`, `README.md`). Version 5 applies the whole of round 2 and rebuilds the magic; `rules/v5/README.md` lists its open proposals under "Questions for the next review".

## Behaviour
- **Round 3 starts on version 5.** Add round 3 to `ROUNDS` with its own names (`decisions-r3`, `notes-r3`, `resolutions-r3`, its own local key, `startedOn: 'v5'`). The page loads version 5 and round 3 by default. Round 3 starts empty: no decision from an earlier round is carried into it, because version 5 already applied them.
- **Version switch:** v5 / v4 / v3 / v2 / v1. Version 4 was never reviewed; it is shown read-only with a notice saying so. Version 3 shows round 2's decisions and notes read-only, from the two exported JSON files embedded at build time (as version 1 shows round 1's). Version 2 keeps whatever it shows now, read-only.
- **What changed:** the compare view gains v4↔v5 (the default) and v3↔v4, each with its CHANGES.md line per id, beside the existing pairs. Filters for the new pairs: new, rewritten, moved or renamed, retired, discussion updated, unchanged, open items. Read the kinds from the words CHANGES.md uses; `rules/v4/CHANGES.md` and `rules/v5/CHANGES.md` are the authority, and a rename is followed so the old and new ids are paired.
- **Where a round 2 decision went:** on a version 5 proposal, show a small line with round 2's decision and note for that id (following renames through both CHANGES.md files), so the reviewer can see what they asked for beside what was written. Read-only.
- **Badges** on version 5 proposals: "new" for ids new in version 5, "rewritten" for rewritten ones, "provisional numbers" where the discussion says "provisional, awaiting the balance pass".
- **Open list:** the open proposals of version 5, in the order of the README's "Questions for the next review" where an id is listed there, then the rest.
- Export for round 3 has the same shape as round 2's and carries the version each decision was made on.
- Never rewrite or delete documents of rounds 1 and 2. The page must not write to `decisions-r2`, `notes-r2` or `resolutions-r2` at all once round 3 is the current round.

## Prior art
The page's own compare view, store and model, extended the way the version 3 change extended them (`ROUNDS`, the `PAIRS` table in `site/app.js`, the CHANGES.md reader in `site/compare.js`). The word diff stays the one the page already uses. No new dependency.

## Tests
Versions 4 and 5 parse and render; round 3's store uses its own names and starts empty; with a memory store holding round 2 fixtures, using the page in round 3 leaves every round 2 document untouched; version 3 shows the exported round 2 decisions read-only; v4↔v5 and v3↔v4 pair ids, including a renamed and a retired one; a version 5 proposal shows its round 2 decision and note through a rename; the three badges appear on the right ids; the open list follows the README order; export carries versions; the build is current. Rebuild `site/dist/review.html` and commit it. Check the built page once in headless Firefox (it loads, shows version 5, and the console has no errors) and keep a screenshot as evidence.

## Leave alone
`rules/`, `docs/`, `chargen*/`, everything outside `site/`, `scripts/build-review.js` and the site and build tests.

## Commands
`node --test tests/<file>.test.js` (one or several), `node scripts/build-review.js`, `node .ws-evidence/<script>.js`, `firefox --headless …`, `git add`, `git commit`. One command per Bash call. Run long commands in the foreground.

## Done when
The page reviews version 5 by default in an empty round 3 with its own documents, versions 4 and 3 are readable with round 2's results shown read-only, v4↔v5 and v3↔v4 compare work with renames followed, each version 5 proposal shows what round 2 said about it, rounds 1 and 2 are untouched, the page is rebuilt, and the tests pass.
