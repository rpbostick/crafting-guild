# Review page: round 4 on version 6

The review page (`site/`, built by `scripts/build-review.js` to `site/dist/review.html`, published to a claude.ai artifact with a database) reviews `rules/v5/synthesis.md` in round 3, storing that round's decisions, notes and resolutions in `decisions-r3`, `notes-r3`, `resolutions-r3` (see `site/store.js` `ROUNDS`). Round 3 is finished: its results are exported to `rules/v5/round3-decisions.json` and `rules/v5/round3-review-notes.json` (84 decisions, 36 notes). Version 6 is written: `rules/v6/` (`synthesis.md`, `CHANGES.md`, `README.md`, `CHECKS.md`). It applies round 3 and three checks (balance, consistency, flavour); its README lists the open proposals under "Questions for the next review" and marks the ones carried forward undecided.

The last change of this kind is the pattern to follow: `git log --oneline -- site/` shows the commits that added round 3 on version 5 (versions, pairs, round 2 shown read-only, badges, README order).

## Behaviour
- **Round 4 starts on version 6.** Add round 4 to `ROUNDS` (`decisions-r4`, `notes-r4`, `resolutions-r4`, its own local key, `startedOn: 'v6'`). The page loads version 6 and round 4 by default, and round 4 starts empty.
- **Version switch:** v6 / v5 / v4 / v3 / v2 / v1. Version 5 shows round 3's decisions and notes read-only, from the two exported JSON files embedded at build time, as version 3 shows round 2's.
- **What changed:** the compare view gains v5↔v6 as the default pair, with `rules/v6/CHANGES.md`'s line per id and the same filters the v4↔v5 pair has; renames are followed.
- **Where a round 3 decision went:** on a version 6 proposal, show round 3's decision and note for that id (following renames through `rules/v6/CHANGES.md`), read-only, as round 2's are shown on version 5.
- **Badges** on version 6 proposals: "new", "rewritten", "carried forward" for the open proposals the README marks as carried forward undecided, and "provisional numbers" where the text still says a number is provisional.
- **The checks:** a view (a tab or a panel beside "What changed") that shows `rules/v6/CHECKS.md` rendered, with each proposal id in it linking to that proposal. On a proposal that CHECKS.md names, a small "checked" mark that opens its finding.
- **Open list:** version 6's open proposals in the README's order.
- **Export** for round 4 in the same shape as the earlier rounds'.
- **A committed export script** for any round: `node scripts/export-round.js <round> <dump-dir> <out-dir>` reads a directory of database documents saved as JSON files (`<dump-dir>/decisions-r<N>/<id>.json` with `state`, `madeOn`, `updatedAt`; `<dump-dir>/notes-r<N>/<id>.json` with `target`, `text`, `tag`, `status`, `author`, `createdAt`, `parent`) and writes `round<N>-decisions.json` and `round<N>-review-notes.json` in exactly the shape of `rules/v5/round3-*.json` (notes ordered by `createdAt`; a note with a `parent` goes under `replies`). Given a dump made from the round 3 fixtures it must reproduce the committed round 3 files byte for byte apart from the `exported` date, which is an argument (`--date YYYY-MM-DD`).
- Never rewrite or delete documents of rounds 1 to 3. The page must not write to an earlier round's collections once round 4 is current.

## Prior art
The page's own compare view, store and model, extended as the round 3 change extended them. The Markdown renderer the page already has (`site/markdown.js`) renders CHECKS.md. No new dependency.

## Tests
Version 6 parses and renders; round 4's store uses its own names and starts empty; with a memory store holding round 3 fixtures, using the page in round 4 leaves every earlier document untouched; version 5 shows the exported round 3 decisions read-only; v5↔v6 pairs ids including a renamed and a retired one; a version 6 proposal shows its round 3 decision and note through a rename; the four badges appear on the right ids; the checks view renders and its ids link; the open list follows the README order; export carries versions; the export script reproduces the round 3 files from a dump built in the test; the build is current. Rebuild `site/dist/review.html` and commit it. Check the built page once in headless Firefox (use `--no-remote --profile <a new directory under .ws-evidence>`; it loads, shows version 6, and the console has no errors) and keep a screenshot as evidence.

## Leave alone
`rules/`, `docs/`, `chargen*/`, `spikes/`, everything outside `site/`, `scripts/build-review.js`, `scripts/export-round.js` and the site, build and export tests.

## Commands
`node --test tests/<file>.test.js` (one or several), `node scripts/build-review.js`, `node scripts/export-round.js …`, `node .ws-evidence/<script>.js`, `firefox --headless …`, `git add`, `git commit`. One command per Bash call. Run long commands in the foreground.

## Done when
The page reviews version 6 by default in an empty round 4 with its own documents, version 5 is readable with round 3's results shown read-only, v5↔v6 compare works with renames followed, each version 6 proposal shows what round 3 said about it, the checks report is readable on the page with links, the export script reproduces round 3's files, earlier rounds are untouched, the page is rebuilt, and the tests pass.
