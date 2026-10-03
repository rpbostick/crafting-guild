# Review page: round 2 continues on the v3 draft

The review page (`site/`, built by `scripts/build-review.js` to `site/dist/review.html`, published to a claude.ai artifact with a database) reviews `rules/v2/synthesis.md` in round 2, storing round 2's decisions, notes and resolutions in `decisions-r2`, `notes-r2`, `resolutions-r2` (see `site/store.js` `ROUNDS`). The reviewer has **already started round 2 on v2**: 8 decisions (advancement-levels, advancement-xp, creation-attributes, creation-steps, credits, monsters, setting-zeal, tables-names, all accepted) and 2 notes (on tables-names and setting-zeal). Since then a **v3 draft** was written: `rules/v3/synthesis.md`, `rules/v3/CHANGES.md` (one line per changed or new id), `rules/v3/README.md`; it adds 23 new and rewrites 7 proposals from the balance pass and research, all `status=open`.

## Behaviour
- **Round 2 continues, now on v3:** the page loads v3 by default (version switch: v3 / v2 / v1). Round 2's stored decisions, notes and resolutions stay where they are and apply by proposal id to v3.
- **Changed since your decision:** a round-2 decision on an id whose proposal text changed between v2 and v3 (per CHANGES.md "rewritten", and by comparing the texts) is shown as "accepted on v2 — changed since" with the v2↔v3 word diff of that proposal and buttons to confirm (keep accepted on v3) or reconsider; it is not counted as decided on v3 until confirmed. In the current data that is `advancement-levels` and `creation-attributes`. Ids whose v3 change is discussion-only keep their decision, with a small "discussion updated" mark.
- **What changed v2 → v3:** the existing compare view gains v2↔v3 (default) besides v1↔v2, with CHANGES.md's line for each id; filters: new in v3, rewritten in v3, unchanged.
- **New proposals** in v3 appear with a "new" badge and in the open list.
- Export includes the version each decision was made on.
- Never rewrite or delete round 1 or existing round-2 documents; store any new fields (like `confirmedOn: "v3"`) as additions.

## Prior art
The page's own compare view, store and model.

## Tests
v3 parses and renders; round-2 decisions made on v2 carry to v3 by id; the two rewritten ids show as changed-since and need confirming; discussion-only changes keep the decision; new ids are badged; v2↔v3 compare pairs ids; existing documents are untouched (memory store fixture with the 8 decisions and 2 notes); export carries versions; build is current. Rebuild `site/dist/review.html` and commit it.

## Leave alone
`rules/`, `chargen*/`, everything outside `site/`, `scripts/build-review.js` and the site tests.

## Commands
`node --test tests/<file>.test.js` (one or several), `node scripts/build-review.js`, `node .ws-evidence/<script>.js`, `git add`, `git commit`. One command per Bash call.

## Done when
The page reviews v3 by default with round 2's existing decisions carried over, the two rewritten items flagged for confirmation, v2↔v3 compare and new-item badges, existing data untouched, rebuilt, tests passing.
