# Balance pass on version 5's new mechanics

`rules/v5/synthesis.md` rebuilt the magic on three engines and changed hit points, and every number for a new mechanic is marked "provisional, awaiting the balance pass" (`rules/v5/README.md` lists them). The calculator in `scripts/balance/` (`dice.js`, `roll.js`, `rules.js`, `model.js`, `report.js`, `v3.js`; findings in `rules/v2/BALANCE.md`; tests `tests/balance.test.js`, `tests/balance-v3.test.js`) has no rows for them. Add the rows, check every provisional number against the targets, and write the findings.

## Targets (`docs/research/v5-brief.md` sections 3 to 8 and 10)
- A caster who pays their engine's full price deals about ×1.5 the median at-will build per round sustained over a fight, and about ×2 as a once-a-fight burst. A caster who pays nothing sits at about the median. No option exceeds ×2.
- Casters who are not meant to be glass cannons (holy or White, nature, song, shadow or glamour) stay at or under the median in damage.
- A lower tier or a free casting must stay worth using when the caster is hurt or tired.
- Limits by level (fatigue boxes, the binding cap, the device cap) should let a caster act through a typical day of three or four fights without being either empty in the first or never limited.

## What to model (Heroic and Classic, levels 1 to 10, with the calculator's existing assumptions)
1. **Hit points:** 4 + CON per level to level 6, then + CON per level; the quick break (4 + CON); Hardy; the Sickly flaw (3 + CON). Redo the version 3 hit point tables on this rule, and state plainly how many Hit Dice a character has at each level under version 5 (the text is said to disagree with itself on whether Hit Dice stop growing at level 6: list every place that states it).
2. **Sorcery:** casting dice by level; a die spent on a step against a die rolled; hit points for dice; a burned Hit Die; the 7–9 costs; the expected hit point cost per round of sustaining ×1.5.
3. **Spell lines**, shapes A, B, C and D from `magic-spell-lines`: damage per round and cost per round at each tier and level, a five-round fight, and how many fights a mage lasts.
4. **Wizardry:** the 2d6+INT roll, fatigue boxes by level (one more every level, and every two levels), added steps, rotes: expected castings before the book is full, and damage per round with the written spells of each tier.
5. **Spirit magic:** the spell-table steps a simple, mage and mighty spirit brings; the cap 2 + half Hit Dice, rounded down and rounded up; a bound spirit's one deed a day against an unbound calling's price.
6. **Made magic:** the maker's-rule price of a damaging consumable and a device against a level's expected silver; the device cap; fuel in hit points.
7. **Backstab** on its new conditions (pays every round when a condition holds) and **Tumble** if it worked as Backstab does, limited to light weapons: both against the median, at 50% and 100% of rounds.
8. **Song** (the Bard's fixed ability): the chance of each result, and what taking one foe out of a round is worth against the median, one target and a group.

## Output
- `scripts/balance/v5.js`: prints every table, on the pattern of `v3.js`, reusing `model.js` and `dice.js`; extend `rules.js` and `model.js` where a rule is new. `tests/balance-v5.test.js` on the pattern of `tests/balance-v3.test.js`: the model's functions are tested with small exact cases (a known dice mean, the cap by level, boxes by level), and every table in the report appears verbatim in the script's output.
- `rules/v5/BALANCE.md`: a summary first (what holds, what breaks, the recommended number for each provisional value), then one finding per mechanic with its table, labelled as `rules/v2/BALANCE.md` labels them (broken, strong, weak, fine, unclear), each with a recommended value and one alternative. For spell lines, say which of A to D meets the targets and with what numbers. End with one list: every provisional number in version 5, its current value, the recommended value.

## Prior art
The project's own calculator and report format; this extends them. No new dependency: exact dice distributions are already in `dice.js`.

## Leave alone
`rules/*/synthesis.md` (the next version applies the findings), `docs/`, `site/`, `chargen*/`, the existing balance tests and tables (`report.js` and `v3.js` output must not change).

## Commands
`node --test tests/<file>.test.js`, `node scripts/balance/<script>.js`, `git add`, `git commit`. One command per Bash call. Run long commands in the foreground. Commit after each of the eight mechanics.

## Done when
`node scripts/balance/v5.js` prints the tables, `rules/v5/BALANCE.md` gives a finding and a recommended number for every provisional value and for the four spell-line shapes, and the new and existing balance tests pass.
