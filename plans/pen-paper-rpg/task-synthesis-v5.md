# Rules synthesis, version 5: the magic rebuilt on three engines, the full second round applied, the trimming done

`rules/v4/synthesis.md` (block format: `rules/v1/README.md`, `scripts/synthesis-format.js`; `status=open` marks; `rules/v4/README.md`, `CHANGES.md`) is the fourth version of the merge of *World of Dungeons* 1979, *World of Dungeons: Remix* and *Advanced World of Dungeons* (AWoD). It was made from only the first eight decisions of the second review round. Since then:

- The second round was completed on the version 3 page: 80 decisions (69 accepted, 11 rejected) and 41 notes, in `rules/v3/round2-decisions.json` and `rules/v3/round2-review-notes.json`. Their ids are version 3 ids; `rules/v4/CHANGES.md` says where each went in version 4.
- `docs/research/round2-analysis.md` summarises that round (section 1 lists every rejection and every "accepted with a change" with its instruction).
- `docs/research/v5-brief.md` records the decisions taken afterwards on the magic and on trimming. **Read all of it first; it is the brief for this version.** Where it and a round 2 note disagree, the brief wins, because it is later.
- Background to read as needed: `docs/research/magic-traditions.md`, `docs/research/ose-and-levelless-spells.md`, `docs/research/spells.md`, `rules/v2/BALANCE.md`.

Write version 5 in `rules/v5/`: `synthesis.md`, `CHANGES.md`, `README.md`. Versions 1 to 4 stay as they are. Start by copying `rules/v4/synthesis.md` and edit by hand.

## What to do

1. **Apply the whole second round.** For every decision in `round2-decisions.json`: an accepted proposal with no note loses `status=open`; an accepted proposal with a note is changed as the note says (or, where the note asks for more talk and the brief settles it, as the brief says); a rejected proposal is rewritten as its note directs and stays open. `round2-analysis.md` section 1 lists the instructions; the JSON files are the authority. The eight decisions version 4 already applied need no second change.
2. **Rebuild the Magic section on the brief's three engines** (brief sections 1 to 7):
   - `magic-overview` says the game has three ways to cast and how a table uses them.
   - One proposal for the uniform spell table (extend `spells-tiers`): the base effect, the steps, and what each engine pays per step. Add the note on ranges in combat that also covers weapons.
   - One proposal each for Wizardry (the casting roll, the spell book's fatigue boxes, rotes, learning spells), Sorcery (branches, casting dice, hit points, burned Hit Dice, a miss table per branch), spirit magic (`magic-summoning` on the 1979 procedure with vessels and the cap) and made magic (the maker's rule, Alchemy, Gadgetry, devices and fuel).
   - The spell list rewritten to be consistent with the table.
   - Raw Chaos magic leaves the optional modules and becomes the chaos branch of Sorcery, with the Warp as its miss table. Update `optional-chaos-magic` to say what moved and what, if anything, is left.
   - Rename the abilities as the brief says and retire the mechanisms it lists. A retired ability's source blocks stay in the document (see "Rules that still hold"); its proposal says it is retired and what replaces it.
3. **Do the trimming** (brief section 8): the class list, the nine skills, the removed abilities, hit points. Rebuild the caster classes on the engines: a wizard class, sorcerer classes by branch (the Cleric and Paladin on holy, the Druid on nature, the Skald on song, a chaos sorcerer), the Spirit Caller, the Illusionist. Add the Alchemist and the Magitek Engineer to the main list. Every class entry must use only skills and abilities that still exist.
4. **Apply the Old-School Essentials points** (brief section 9): Tinker and Stealth, a sentence on retries in each skill, Backstab's conditions. Use OSE's skill names and mechanics in our own words; copy no OSE sentence.
5. **Everything the brief marks "Open"** becomes a `status=open` proposal whose discussion gives two or three options and a recommendation. Where a number is needed that the calculator cannot yet give (casting dice by level, what a hit point buys, fatigue boxes by level, the cap's rounding), give a provisional value and say in the discussion "provisional, awaiting the balance pass", with the target from brief section 7.

## Rules that still hold
- Heroic default with "default (Classic: value)"; rules text never names a source game for a mechanic the game owns (source blocks, discussions, Zeal, Credits and the optional modules may).
- Every source block of version 4 appears in version 5, unchanged, exactly once; moving a block to another section is fine.
- AWoD's text is not confirmed as openly licensed (`docs/research/licences.md`): AWoD passages stay as source blocks and proposals paraphrase. The same holds for the d200 spell list: ideas only, none of its wording.
- Existing numbers come from the calculator (`node scripts/balance/report.js`, `node scripts/balance/v3.js`); copy tables verbatim. New mechanics get provisional numbers as in step 5; do not change `scripts/balance/`.
- Shorter is better: the second round asked several times for fewer words. A proposal states the rule; reasoning belongs in the discussion.
- Rules text and discussions give reasons, never who decided or when.

## Output
- `rules/v5/synthesis.md`.
- `rules/v5/CHANGES.md`: one line per id that is new, rewritten, moved, renamed, retired or whose status changed, with the reason (a round 2 decision or note, or a section of the brief).
- `rules/v5/README.md`: what version 5 is, how it was made, what is settled, what is open, and "Questions for the next review": every open proposal in one line each, the provisional numbers together in one list for the balance pass.

## Tests
- Add version 5 to the format test (`tests/synthesis.test.js`) and the coverage test (`tests/coverage.test.js`).
- New `tests/synthesis-v5.test.js`, on the pattern of `tests/synthesis-v4.test.js`: every decision id in `rules/v3/round2-decisions.json` and every note target in `rules/v3/round2-review-notes.json` is accounted for (unchanged-and-settled, or a line in `rules/v5/CHANGES.md`, following renames through `rules/v4/CHANGES.md`); every rejected id is still open; every version 4 proposal id exists in version 5 or CHANGES.md says where it went; the multiset of source blocks equals version 4's; no main-list class entry names a removed class, a removed ability (Tumble, Gambit, Expert) or a skill outside the nine; no proposal outside Credits, Zeal and "Optional modules" names Remix or AWoD; the Magic section has open or settled proposals for the spell table, Wizardry, Sorcery, spirit magic and made magic.
- The source texts are untracked; the coverage test skips in the worktree. Run the coverage script directly: `node scripts/check-coverage.js /home/patrickb/pen-paper-rpg/resources/text/<wod>.txt /home/patrickb/pen-paper-rpg/resources/text/<remix>.txt /home/patrickb/pen-paper-rpg/resources/text/<awod>.txt --synthesis rules/v5/synthesis.md` (see `tests/coverage.test.js` for the three file names) and save its output as evidence.

## Prior art
Writing work in the project's own format, done the way versions 2 to 4 were: copy the previous version and edit by hand, with CHANGES.md and a test that accounts for every decision (`rules/v4/CHANGES.md` and `tests/synthesis-v4.test.js` are the patterns to copy). The designs borrowed from are named in the brief and its background reports (OSE for skills, book magic and item prices; the level-less dice list for one-currency pricing, thresholds and locked capacity; the 1979 game for summoning). No new dependency.

## Leave alone
`rules/v1/` to `rules/v4/`, `docs/`, `chargen*/`, `site/` (the review page gets version 5 in a later task), `scripts/balance/`.

## Commands
`node --test tests/<file>.test.js`, `node scripts/<script>.js …`, `node scripts/balance/<script>.js`, `git add`, `git commit`. One command per Bash call. Run long commands in the foreground. Commit as you finish each of the five steps, so a run that stops can be resumed.

## Done when
`rules/v5/` holds a version in which the whole second round is applied, the magic runs on Wizardry, Sorcery and spirit magic with one spell table and one maker's rule, the classes, skills and abilities are trimmed as the brief says, every open point of the brief is an open proposal with options, every source block is still present, and the format, coverage and version 5 tests pass.
