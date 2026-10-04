# Version 5 additions: spell lines with a White Mage and a Black Mage, the Summoner, the Bard

`rules/v5/synthesis.md` (block format: `rules/v1/README.md`, `scripts/synthesis-format.js`; `rules/v5/README.md`, `CHANGES.md`) is the fifth version of the rules, about to be reviewed. `docs/research/v5-brief.md` section 10 records additions decided after it was written. **Read section 10 first; it is the brief for this task**, and read sections 2, 4 and 5 for the rules it builds on. Edit version 5 in place; do not create a version 6.

## What to do
1. **Spell lines** (new proposal in the Magic section, after `magic-sorcery-branches`, `status=open`): what a line is, how a line and each tier is bought or found and learned, the level from which each tier can be learned. Its discussion gives the four tier shapes A to D from the brief as options, each with the same worked example (a mage at level 5 and level 8 casting each tier of one line: dice, average, cost), and recommends A. The proposal text itself states shape A, marked "provisional, awaiting the balance pass".
2. **The white and black branches** in `magic-sorcery-branches`: black as a new branch with its miss table; white as the holy branch under another name. For each, a table of lines (name, what the three tiers do, range, any built-in step). The Final Fantasy series' spell names are not ours to use: propose our own names for every line and tier, and say in the discussion which familiar effect each stands for.
3. **Two classes** on the main list, each its own `status=open` proposal: `classes-white-mage`, `classes-black-mage`, as the brief describes. Add them to `classes-overview`. Say in each discussion how it differs from the Cleric and from the Sorcerer.
4. **The Summoner:** rename the Spirit Caller to Summoner everywhere in proposals (source blocks and older discussion paragraphs stay as they are); the engine is still called spirit magic. Add four great spirits to the samples in `magic-summoning` (fire, ice, lightning, earth), with our own names. Record the rename in `classes-ability-renames` or the class's discussion, wherever class renames are recorded.
5. **The Bard:** rewrite `classes-bard`'s Bard entry as the brief describes (the Skald's entry stays). New ability proposals for Song, Hide, Salve and Far Song; Pacify's proposal says it folds into Song for the Bard and what the Skald's Pacify now is. Add the harp to the weapons. Add Sickly as an optional flaw where character creation or hit points are described.
6. **An optional module** under "Optional modules" (`status=open`), with a keep-or-drop question: the restoring draught and anything else from section 10's "optional module" line.
7. **Bookkeeping:** `rules/v5/CHANGES.md` gets a line for every new, rewritten or renamed id, in the words it already uses. `rules/v5/README.md`: add the new open proposals to "Questions for the next review" and the new provisional numbers to the balance list, and remove the "Not covered" line that says the review page does not show version 5 (it does now).
8. **Rebuild the review page:** `node scripts/build-review.js`, and commit `site/dist/review.html`.

## Rules that still hold
- Heroic default with "default (Classic: value)"; rules text never names a source game or the Final Fantasy series for a mechanic the game owns (discussions may name what an idea is modelled on).
- Every source block stays, unchanged, exactly once. No new source blocks: these additions have no source text.
- Every class entry uses only the nine skills and abilities that exist. New numbers are provisional and say so.
- Short proposals; reasoning goes in the discussion. Reasons, never who decided or when.

## Tests
- Extend `tests/synthesis-v5.test.js`: the two mage classes, the spell-lines proposal and the optional module exist and are open; no proposal outside discussions contains "Spirit Caller"; the Bard's entry names Song and none of Turn or Tinker; the names Fira, Firaga, Cura, Curaga appear in no proposal; CHANGES.md has a line for each new id. Update any existing assertion the additions change (the class count, the list of open ids) and say which in the result.
- Run `tests/synthesis-v5.test.js`, `tests/synthesis.test.js`, and the site and build tests (`tests/site-app.test.js`, `tests/site-compare.test.js`, `tests/build-review.test.js`), since the page embeds version 5 and its README order.
- Coverage: run `node scripts/check-coverage.js /home/patrickb/pen-paper-rpg/resources/text/<wod>.txt /home/patrickb/pen-paper-rpg/resources/text/<remix>.txt /home/patrickb/pen-paper-rpg/resources/text/<awod>.txt --synthesis rules/v5/synthesis.md` (file names in `tests/coverage.test.js`) and keep the output as evidence.

## Prior art
Writing work in the project's own format, added to an existing version the way earlier fix rounds were. The designs are modelled on the Final Fantasy series' tiered spells, one-deed summons and frail bard, for their shape only: no names or text from it. No new dependency.

## Leave alone
`rules/v1/` to `rules/v4/`, `docs/`, `chargen*/`, `scripts/balance/`, and `site/` apart from the rebuilt `site/dist/review.html` (change site code only if a test proves the page cannot show the additions, and say so).

## Commands
`node --test tests/<file>.test.js`, `node scripts/<script>.js …`, `git add`, `git commit`. One command per Bash call. Run long commands in the foreground. Commit after each numbered step.

## Done when
Version 5 has open proposals for spell lines (with the four tier shapes as options), the white and black branches with named lines, the White Mage and the Black Mage, the Summoner under its new name with four great spirits, the reshaped Bard with Song, Hide, Salve and Far Song, the harp, the Sickly flaw and the optional module; CHANGES.md and the README account for all of it; the review page is rebuilt; and the listed tests pass.
