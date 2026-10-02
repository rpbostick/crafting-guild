# Rules synthesis v2: a logic, consistency and balance pass

`rules/v2/synthesis.md` (block format; `README.md`, `CHANGES.md`) is version 2 of the World of Dungeons-family merge. The heroic power level (numbers that grow with Hit Dice) is the default, Classic (flat numbers) the option. Before the second review round, check it for logic, consistency and balance, and write the findings as a report the reviewer can act on. Do not edit v2.

Read the research that bears on balance: `docs/research/spells.md` (spell power budgets per tier, the heroic damage concern in its §4.3), `docs/research/group-combat-and-tiers.md` (scale and tier drafts), `docs/research/prices.md` (historical prices), and the source texts in `/home/patrickb/pen-paper-rpg/resources/text/` (read by absolute path).

## What to check
- **Consistency:** terms used the same way everywhere (attributes, skills, abilities, Surprise, advantage/+1 forward, HD, harm, armour, ranges, durations, currency); every ability a class grants exists and is described once; every cross-reference resolves; the power level conversion table lists every value that differs and matches the text; no rule contradicts another (quote both); naming collisions.
- **Logic:** each rule can be applied without asking the GM to invent missing pieces (when, how often, what it costs, what happens on 7–9 and 6−); edge cases at level 1 and level 10.
- **Balance, computed, not guessed:** write a small committed calculator (`scripts/balance/*.js`, Node, with tests) that models: the 2d6+attribute success odds; expected damage per round for each class at levels 1, 3, 5 and 10 (weapons, Slay/Backstab/Volley/magic, heroic and Classic modes); hit points by level (the 3 HP start and HD rules); armour and harm; quicksilver and spell damage; and compares classes against each other and against monsters by HD. Flag any ability or class more than ~1.5× or less than ~0.67× its peers at the same level, any level where one mode breaks (e.g. heroic magic outscaling Slay, as the spells research found), and any "encounter-breaking" ability the notes asked about (Scout, Lucky, Illusions).
- **Economy:** the equipment prices against `docs/research/prices.md`'s anchor and the starting money: what a starting character can afford, and where the list contradicts the research.

## Output
- `rules/v2/BALANCE.md`: a summary of the top findings first, then sections (consistency, logic, balance, economy), each finding with the proposal ids it touches, the evidence (quotes, numbers from the calculator, with the command that produced them), and a suggested fix in one or two sentences, phrased so it can become a v3 proposal. Mark each finding severity (breaks play / unbalanced / unclear / polish).
- The calculator and its tests; its outputs saved as tables in BALANCE.md.

## Prior art
Use web search and web fetch where you compare with published balance work (e.g. Dungeon World's damage dice by class, OSE's attack matrices, the "Same Page Tool", Angry GM or The Alexandrian posts on expected damage), citing URLs.

## Tests
`node --test tests/balance.test.js` (or `scripts/balance/*.test.js` found by the root `node --test`): the calculator's odds and expected values against hand-checked cases (2d6+0 hits on 7+ 58.3%, d6 averages 3.5, keep-highest of 2d6, etc.).

## Leave alone
`rules/v1/`, `rules/v2/synthesis.md` and `CHANGES.md`, `site/`, `chargen*/`.

## Commands
`node --test <files>`, `node scripts/balance/<script>.js`, `node .ws-evidence/<script>.js`, `git add`, `git commit`. One command per Bash call.

## Done when
BALANCE.md lists sourced and computed findings with severities and suggested fixes, the calculator is committed with passing tests, and nothing in v2 was edited.
