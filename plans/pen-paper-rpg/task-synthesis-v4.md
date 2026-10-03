# Rules synthesis, version 4: Remix as the base, the original's spirit magic kept, AWoD by exception

`rules/v3/synthesis.md` (block format: `rules/v1/README.md`, `scripts/synthesis-format.js`; `status=open` marks; `rules/v3/README.md`, `CHANGES.md`) is the draft third version of the merge of *World of Dungeons* 1979, *World of Dungeons: Remix* and *Advanced World of Dungeons* (AWoD). Two things have happened since:

- The second review round recorded eight decisions and two notes: `rules/v3/decisions.json`, `rules/v3/review-notes.json`.
- `docs/research/remix-vs-awod.md` compares Remix with AWoD and states the direction (its section 4). Read all of it first; it is the brief for this version.

Write version 4 in `rules/v4/`: `synthesis.md`, `CHANGES.md`, `README.md`. Versions 1 to 3 stay as they are.

## The direction (report, section 4)
1. **Remix is the base text.** Where Remix has a rule it is the rule, at the Heroic power level, with the Classic value beside it where one exists. Reorder the document so a reader meets the base game first: within every section the main proposal comes from Remix's rule, and nothing in the main rules depends on an optional module.
2. **The 1979 spirit magic is a first-class magic system, not an option.** `magic-summoning` is built on the 1979 procedure (spirits with domains; an hour of ritual, a dose of quicksilver, or an item with a bound spirit; one effect within a domain), extended by AWoD's requirements and binding as version 3 proposes. The Spirit Caller is its class. Remix's Binding stays as its own ability with binding points. `magic-overview` is rewritten to say the game has two main magics, spirit magic and spells, and how a table uses both. Keep `magic-summoning` open, with its discussion updated to say this is now settled as a kept system and what is still open inside it.
3. **AWoD by exception.** Follow the table in the report's section 4:
   - Kept in the main rules: the spell pick-lists and "not always risky" casting, the alchemy formula lists and silver cost, the summoning requirements and binding, the 19 AWoD abilities already used in proposals, the Classic monster benchmarks, and AWoD's additions to the merged Monk, Paladin, Druid, Backstab/Hunter and Illusions.
   - Moved to a new top-level section near the end, "Optional modules", each as its own proposal marked `status=open` whose discussion gives the keep-or-drop question, what depends on it, and the report's recommendation:
     - `optional-chaos-magic`: raw Chaos magic and the Warp (the `magic-chaos*` proposals, the Wizardry source blocks and the Warp tables move here; the Magic-User in the main rules must work without it; say what the Muscle Wizard needs).
     - `optional-awod-classes`: the fifteen classes found only in AWoD. For each, one line: what it is, which main-rules class it is closest to, and whether it needs an optional module. Class entries that only recombine main-rules abilities may be offered as "could move to the main list".
     - `optional-awod-abilities`: the 23 AWoD abilities no proposal uses, grouped (social and urban, travel, combat, other), each with a one-line note of the nearest Remix ability if there is one.
   - Update every proposal and the conversion table that referred to moved material so the main rules read correctly without the modules, and note in each module what it adds back.

## The second round's decisions (apply as they stand)
- **Accepted, no longer open:** `advancement-xp`, `creation-steps`, `credits`, `monsters`. Remove `status=open`; text unchanged except where rule 1 to 3 above forces a cross-reference change (say so in CHANGES.md).
- **Accepted on the version 2 text, then rewritten in version 3:** `advancement-levels`, `creation-attributes`. Keep the version 3 text, keep `status=open`, and open each discussion with one line saying the version 2 text was accepted and exactly what version 3 changed, so the review can confirm or revert it.
- **Rejected, redo per the note:**
  - `setting-zeal`: the section becomes "Making your own setting: Zeal". The sample setting text goes in, with "support my heritage moves" becoming "support the heritage moves and classes (see below)". Below it, one block that gathers every class, heritage, ability and table tied to Zeal (move them here from wherever they are, including `classes-heritage`'s Zeal heritages and the homelands of the names table if they are Zeal's; check each against the source before moving) with a short explanation of how a setting supplies heritages and classes. Clean up the heritage classes and propose merges with other classes where they overlap. Remix and Tam H. stay credited here. Open.
  - `tables-names`: the opening reads "If someone learns your true name, …" and, after "before your time", adds: "The true name may also amplify other powers used on you, for good or ill." Open, with the note's wording quoted in the discussion.
- Everything else open in version 3 stays open with its proposal text unchanged, unless rules 1 to 3 move it or change a cross-reference.

## Rules that still hold
- Heroic default with "default (Classic: value)"; rules text never names a source game for a mechanic the game owns (source blocks, discussions, Zeal and Credits may).
- Every source block of version 3 appears in version 4, unchanged, exactly once; moving a block to another section is fine.
- AWoD's text is not confirmed as openly licensed (`docs/research/licences.md`): AWoD passages stay as source blocks and proposals paraphrase.
- Numbers come from the calculator (`node scripts/balance/report.js`, `node scripts/balance/v3.js`); copy tables verbatim, do not invent numbers.

## Output
- `rules/v4/synthesis.md`.
- `rules/v4/CHANGES.md`: one line per id that is new, rewritten, moved (old section → new section), renamed (old → new id) or whose status changed, with the reason (a round-2 decision, a note, or direction rule 1, 2 or 3).
- `rules/v4/README.md`: what version 4 is, how it was made, what is settled, what is open, and a short list "Questions for the next review" (the two confirmations, the three optional modules, `magic-summoning`, Zeal, names).

## Tests
- Add version 4 to the format test (`tests/synthesis.test.js`) and the coverage test (`tests/coverage.test.js`).
- New `tests/synthesis-v4.test.js`: every decision id in `rules/v3/decisions.json` and every note target in `rules/v3/review-notes.json` has a line in `rules/v4/CHANGES.md`; the four accepted ids are not open and the two listed under `unconfirmed` are; every version 3 proposal id exists in version 4 or CHANGES.md says where it went; the multiset of source blocks equals version 3's; the three `optional-*` proposals exist and are open; no proposal outside Credits, Zeal and "Optional modules" names Remix or AWoD; CHANGES.md has a line for every changed id and none for an unchanged one.
- The source texts are untracked; the coverage test skips in the worktree. Run the coverage script directly instead: `node scripts/check-coverage.js /home/patrickb/pen-paper-rpg/resources/text/<wod>.txt /home/patrickb/pen-paper-rpg/resources/text/<remix>.txt /home/patrickb/pen-paper-rpg/resources/text/<awod>.txt --synthesis rules/v4/synthesis.md` (see `tests/coverage.test.js` for the three file names) and save its output as evidence.

## Prior art
Writing work in the project's own format, done the way versions 2 and 3 were: copy the previous version and edit by hand, with CHANGES.md and a test that accounts for every decision (`rules/v2/CHANGES.md`, `tests/synthesis-v2.test.js`, `tests/synthesis-v3.test.js` are the patterns to copy). No new dependency.

## Leave alone
`rules/v1/`, `rules/v2/`, `rules/v3/`, `docs/`, `chargen*/`, `site/` (the review page gets version 4 in a later task), `scripts/balance/`.

## Commands
`node --test tests/<file>.test.js`, `node scripts/<script>.js …`, `node scripts/balance/<script>.js`, `git add`, `git commit`. One command per Bash call. Run long commands in the foreground.

## Done when
`rules/v4/` holds a version built on Remix with the original's spirit magic as a kept system, AWoD's extra material in three open optional modules, the second round's decisions and notes applied, every source block still present, and the format, coverage and version 4 tests passing.
