# Analysis after the third review: thief abilities, the Remix-only abilities, class roles, sword prices, the Bard's song

The third review of `rules/v5/synthesis.md` is exported in `rules/v5/round3-decisions.json` and `rules/v5/round3-review-notes.json`. Several notes ask for an investigation before the next version is written. Write `docs/research/round3-analysis.md` answering them. Use the labels and citation habits of `docs/research/spells.md` (confirmed, secondary, inferred, unverified, not read). Source texts are on disk, untracked, in the main checkout: `/home/patrickb/pen-paper-rpg/resources/text/` holds `world_of_dungeons_1979.txt`, `WoDuRemix.txt`, `advanced-world-of-dungeons.txt`, `ose-classic-fantasy-rules-tome.txt` (Old-School Essentials, the open-content restatement of 1981 D&D) and `osr-nsr-spells.txt`; read them with grep, cat, head and tail by absolute path.

## Sections

1. **The classic thief abilities.** The notes: "I want an investigation into the classic Thief abilities and how they come out in WoDu 1979 and Remix, as well as how they are handled in D&D. I want a level 1 Thief to readily have access to the classic abilities"; and, on the skill list: "The original nine skills that are on the sheet should not lose ability. Stealth was all the Thief skills before in WoD, right? If so, those should go back in there. Lock picking and trap disarming succeeds on normal locks / traps (not masterwork) if they have adequate time, safety, and tools. Under pressure, they may only try again if the circumstances surrounding the failure change. The GM may also decide that a 6- failure damages the mechanism, and it will take 10x the normal time and maybe additional tools to repair it or completely disassemble it before it may be attempted again."
   - A table: each classic ability (open locks, find and remove traps, pick pockets, move silently, hide in shadows, climb sheer surfaces, hear noise, back-stab, read languages, scroll use) against how OSE, the 1979 game, Remix, AWoD and version 5 give it to a level 1 thief (skill, ability, class feature, or not at all), with the chance of success at level 1 in each.
   - Answer the question in the note from the 1979 text: what did Stealth cover there, and what did Tinker add?
   - Web: how original D&D (Greyhawk, 1975), B/X and AD&D first edition present the thief's abilities, briefly, with sources.
   - A recommendation: the wording of Stealth and Tinker and the Thief's level 1 entry so that a level 1 Thief has all the classic abilities, including the note's rule for locks and traps. Two options if there is a real choice.

2. **The abilities found only in Remix** (the section "Abilities found only in Remix" of `rules/v5/synthesis.md`). The note: "Have these be categorized by theme, make suggestion as to which ones can be combined, and have the whole group of them analyzed with a balancing rationale. Flag any that seem to remove agency from the GM or players for removal. Flag any that are duplicated or superfluous for removal. Consider combining several weaker or niche ones together. I would like a much smaller list of more versatile and more interesting abilities. If any of our base classes are dependent on these, that should be noted as well."
   - A table of every one: theme, one-line effect, which main-list classes list it, verdict (keep, merge into a named new ability, remove) and the reason (duplicates X, takes a decision away from the GM or a player, too narrow, fine).
   - The proposed shorter list: each merged ability written out in one or two sentences, with what it absorbed, and a balancing note (how it compares with Slay, Tough, Lucky as benchmarks; use `rules/v2/BALANCE.md` for numbers, do not invent any).
   - Do the same, more briefly, for the abilities in `optional-awod-abilities`, since the optional section is to hold what the main list drops.

3. **What each class is for.** The note on the Acrobat: "What enables the Acrobat to keep up with others in combat, as well as other parts of the game? What will they play like, and why would anyone want to play one?" Tumble is coming back: it works as Backstab does, only with light weapons and light thrown weapons, and needs Athletics; the Acrobat gets Athletics and Tumble and chooses one more of Evasion, Reflexes, Balance, Instinct.
   - For every main-list class in version 5, three lines: what it does in a fight, what it does outside one, and why a player picks it over its nearest neighbour. Flag every class where one of the three is weak or missing, and suggest the smallest change that fixes it.
   - One evocative sentence for each class and for each class the main list dropped (the notes ask for "a single sentence evocative descriptor" for every class and suggested class).
   - Names: a one-word name for the ability now called Worth a Dozen (the note mentions AD&D second edition's Hordebreaker as the kind of name wanted; give five candidates), and a new name for the first-tier spell Open Latch once it also locks.

4. **Sword prices.** The note: "Swords historically were much harder to make than other weapons in their class. Look to the historical numbers, but swords should likely cost between 1.5x and 2x (or more) of other weapons in their class", with examples by class (a short sword against a hand axe; an arming sword against a battle axe or mace; a great sword against polearms and great axes). `docs/research/prices.md` has the sources and the current list. Find historical sword prices against axes, maces, spears and polearms of the same period (web, citing each), and propose prices for swords in each weapon class of version 5's price list, keeping 1 silver = 1 English penny.

5. **The Bard's song.** The note: "Does this capture everything that Edward can do? What about using it against groups as a song would do? How about party buffs and minor healing?" List what the bard Edward does in Final Fantasy IV across its versions (web, cited), set it beside version 5's Song, Hide, Salve and Far Song, and propose how Song works on a group, a song that helps allies, and minor healing, each inside the spell table's steps where possible. Another note asks for an ability, Voice, that lets Song be sung without an instrument, with a small bonus to a related skill or ability so it is a fair choice against the harp: propose it. Use the series for the shape of the abilities only; no names or text from it in proposed rules wording.

6. **Alchemy by scavenging.** The note proposes making things without silver: a base of one day per formula, and each step, and each 10s saved, adds two hours; with a limit on how much can be scavenged in an area a month. Its worked example is in `round3-review-notes.json` (target `magic-alchemy`). Check the example's arithmetic against the maker's rule in version 5, and propose the simplest rule that gives the same results, with the monthly limit, and the Alchemist's Workshop upgrades the second note on `magic-alchemy` describes.

## Prior art
A research report in the project's own format, like the others in `docs/research/`. No code.

## Commands
Web search and web fetch for research. `grep`, `cat`, `head`, `tail` on the files named above. `git add`, `git commit`. One command per Bash call.

## Leave alone
Everything except `docs/research/round3-analysis.md`.

## Done when
`docs/research/round3-analysis.md` has the six sections, each ending in a recommendation the next version can apply, cites every fact from outside the project, and is committed.
