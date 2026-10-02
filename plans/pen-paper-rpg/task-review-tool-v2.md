# Review tool: round 2 (v1 ↔ v2 compare, open items, discussion threads)

The review page in `site/` (read `site/*.js`, `scripts/build-review.js`, its tests, and `rules/v1/README.md`) shows `rules/v1/synthesis.md` side by side with the source games, with Accept/Reject per proposal and notes, stored in the published page's database (`decisions` and `notes` collections, via `site/store.js`; localStorage and memory backends for tests and offline). Round 1 is finished: its decisions and notes are exported to `rules/v1/decisions.json` and `rules/v1/review-notes.json`. Version 2 is written: `rules/v2/synthesis.md` (same format; block headers may end in `status=open`, read by `statusArg` in `scripts/synthesis-format.js`) and `rules/v2/CHANGES.md` (one line per proposal id and note target). Update the page for round 2.

## Behaviour
- **Round 2 reviews v2.** The page loads `rules/v2/synthesis.md` by default, with a version switch (v2 / v1) in the header. Round 2 decisions and notes are stored apart from round 1's (e.g. `decisions` and `notes` documents carry `round: 2`, or separate `decisions-r2`/`notes-r2` collections: pick one, keep round 1's documents untouched and readable).
- **Compare v1 ↔ v2:** for each proposal id, a "What changed" view: the v1 proposal and the v2 proposal side by side with the existing word diff, the CHANGES.md line for that id above them, and round 1's decision and notes on it (read from the exported JSON files built into the page, so it works offline). Renamed/split/merged ids follow CHANGES.md. New proposals show as all-added; removed ones as all-removed. A filter: changed only / unchanged / new / open.
- **Open items list:** a panel listing every block marked `status=open`, grouped by section, with its question (the discussion's first line) and how many replies it has; clicking jumps to it. A count in the header ("17 open").
- **Discussion areas:** every `::: discussion` block is shown as a discussion area with a reply thread under it: anyone with the page can add a reply (text, optional tag question/idea/decision), replies are stored in the database (a `notes` document with `target: {kind: "discussion", id}` and `parent` for replies), shown oldest first with time and author name (the page's `user` capability gives the viewer's name; fall back to "you" offline). An open item can be marked **Resolved** with a short resolution text, which closes it in the list (stored, reversible).
- **Accept / Reject / Revise** on v2 proposals as before (Revise = reject with a note asking for a rewrite), plus the existing notes on any source passage.
- **Export:** a button that downloads round 2's decisions, notes and replies as JSON (the same shape as `rules/v1/decisions.json` and `review-notes.json`, plus replies and resolutions), so the next version can be written from it.
- Keep the page one self-contained file (`site/dist/review.html`) with the synthesis texts, CHANGES.md and round 1's JSON inlined at build time.

## Prior art
The page's own diff, parser, model and store; no new library.

## Tests
Extend the site tests (they load the real `site/*.js` in a vm and run against the real files): v2 parses and renders; the compare view pairs ids through CHANGES.md (renamed, new, removed cases); the open list equals the `status=open` blocks; replies and resolutions round-trip through the memory and localStorage stores and never touch round 1's documents; export matches the stored data; the build is current. Rebuild and commit `site/dist/review.html`.

## Leave alone
`rules/`, `chargen*/`, everything outside `site/`, `scripts/build-review.js`, `tests/` (site tests) and `scripts/synthesis-format.js` (read-only unless a parser bug blocks you; say so).

## Commands
`node --test tests/<file>.test.js` (one or several), `node scripts/build-review.js`, `node scripts/<script>.js`, `node .ws-evidence/<script>.js`, `firefox --headless …` for screenshots (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
The page reviews v2 by default with a v1 switch, shows what changed per id with round 1's decisions and notes, lists open items, lets reviewers reply on any discussion and resolve open items, exports round 2, is rebuilt, and the tests pass.
