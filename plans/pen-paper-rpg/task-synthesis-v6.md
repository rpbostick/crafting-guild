# Rules synthesis, version 6: the third round applied, then a consistency check, a balance check and a flavour check

`rules/v5/synthesis.md` (block format: `rules/v1/README.md`, `scripts/synthesis-format.js`; `rules/v5/README.md`, `CHANGES.md`) is the fifth version of the rules. Since it was written:

- The third review round is exported: `rules/v5/round3-decisions.json` (80 decisions: 65 accepted, 15 rejected) and `rules/v5/round3-review-notes.json` (36 notes). 31 open proposals were not decided.
- `rules/v5/BALANCE.md` (with `node scripts/balance/v5.js`) gives a finding and a recommended number for every provisional value and for the four spell-line shapes.
- `docs/research/round3-analysis.md` answers the investigations the notes asked for: the classic thief abilities, the abilities found only in one source game, what each class is for, sword prices, the Bard's song, alchemy by scavenging.
- `docs/research/v5-brief.md` is still the design brief for the magic and the trimming. A round 3 note that disagrees with it wins, because it is later.

Write version 6 in `rules/v6/`: `synthesis.md`, `CHANGES.md`, `README.md`, `CHECKS.md`. Versions 1 to 5 stay as they are. Start by copying `rules/v5/synthesis.md` and edit by hand. Work in the four passes below, in order, committing after each.

## Pass 1: apply the third round
- **Accepted, no note:** settled; remove `status=open`.
- **Accepted, with a note:** change as the note says. If the change is small and exact (a price, a word, a capital letter), make it and settle the proposal. If it asks for new rules or a discussion, write them, keep the proposal open, and open its discussion with one line saying what was accepted and what is new.
- **Rejected:** rewrite as the note directs; open. All fifteen have a note.
- **Notes on a discussion, a section or a source block** apply to the proposal they concern (for example the note on the Assassin's source block: the Assassin gets Backstab fixed and chooses one more).
- **The 31 undecided open proposals are carried forward open, unchanged, unless they are no longer needed.** One is no longer needed when a round 3 note or another pass of this task replaces or removes what it proposes; then say so in CHANGES.md with the id that replaces it. Do not settle an undecided proposal.
- Where a note asks for an investigation, apply the recommendation of the matching section of `round3-analysis.md` as an open proposal, with the report's options in the discussion. This covers: Stealth, Tinker and the Thief's level 1 entry; the shorter ability list (the merged abilities replace the long section; what is dropped goes to the optional section with the report's reason); Tumble and the Acrobat; the Bard's Song on groups, helping allies and minor healing, and Voice; sword prices; alchemy by scavenging, quicksilver as a formula, and the workshop; the new names (give the report's candidates as `[NAME? …]` choices where the note asks for more names).
- Notes that need care, in plain terms: Binding returns as an ability beside Summon (Summon calls a spirit and commands only bound ones; Binding binds a called spirit under the Summoner's rules; the Summoner starts with both and one choice; say what a caster with Summon alone can do); the Illusionist is a sorcerer of the Glamour branch only, whose powers come to contain and surpass the wizard's illusion list; the Paladin's holy Sorcery moves to a later level choice (option 2 of its discussion); the Magitek Engineer becomes the Artificer, with a copy under its old name in the Zeal section only if Zeal names it, and its machine knowledge becomes an ability named Mechanic; "Make your own class" points to the optional section, which holds the expanded version and a list of suggested classes (the ones the main list dropped); finesse weapons use DEX to hit and Backstab needs a finesse or light weapon; a range band, Intimate, closer than Close; the Standard Array's −1 becomes 0; the character sheet gets blank lines for extra skills and abilities; Hardy is not mentioned under hit points.

## Pass 2: the balance check
- Replace every provisional number with the value `rules/v5/BALANCE.md` recommends, cite the finding in the discussion, and drop the words "provisional, awaiting the balance pass" there. Copy tables verbatim from `node scripts/balance/v5.js`; do not invent a number. Where the report says a mechanic is broken or cannot meet its target, write the report's fix as the proposal and keep it open.
- `magic-spell-lines`: state the shape the report finds meets the targets, with its numbers, and keep the four shapes as options; the choice is still the reviewer's.
- Anything the report did not cover stays provisional and is listed in the README.

## Pass 3: the consistency check
Read the whole document as one rulebook and make it agree with itself. Fix what has one right answer; where there is a real choice, write an open proposal. Record every finding in `CHECKS.md` (what, where, fixed or opened). At least:
- **One name for one thing.** Every skill, ability, class, branch, spell, spell line, spirit, range band and named rule is spelled and capitalised the same way everywhere in proposals (the notes: "Names of things that are named in the book should be capitalized consistently. Skills, abilities, powers, etc."; "White branch, capital W"). Choose the convention, state it in the README, apply it.
- **Every reference resolves.** Each ability, skill, spell, weapon property or rule that a class, ability or spell names is defined in a proposal, and "see X" points at a section that exists. No proposal names a retired mechanic (binding points, Power, the old Sorcery ability, Spirit Caller, Magic-User unless kept, Magitek Engineer outside Zeal, removed classes and skills).
- **One number for one rule.** Hit Dice by level and whether they stop growing (a note says the text disagrees with itself; BALANCE.md lists the places), hit points, the caps, spell damage, prices, ranges and durations say the same thing wherever they appear, in Heroic and in Classic.
- **Every class entry is complete and playable at level 1:** its skills are among the nine, its abilities exist, its fixed and chosen abilities do not duplicate each other, and the class overview's list and counts match the entries.
- **Older discussion paragraphs:** a discussion that still describes a superseded design is cut down to one line saying what replaced it, so a reader is not led to dead rules.
- **Options and counts in discussions** match the proposal they sit under.

## Pass 4: the flavour check
The game should read as one game with its own voice, and every choice a player makes should promise something to do.
- **Our own words.** A proposal that is still one source game's sentences lightly edited is rewritten in the game's own voice, keeping the rule (the note on the introduction: "Since this is a new game, we want to rewrite this so we aren't just taking from Remix"). Source blocks are untouched.
- **One evocative sentence for every class** on the main list and every suggested class in the optional section, from `round3-analysis.md` section 3, placed at the head of its entry.
- **Every class has a reason to be played:** apply the report's smallest fix for each class it flags.
- **Names** of abilities, spells, spell lines and spirits fit one world: no placeholder that reads as a label, no name taken from another game's product identity (the mage spell lines and the great spirits were named in a hurry; review them), jokes only where the surrounding text is light.
- **Tone:** rules are short and direct; examples are concrete; the same kind of entry (a class, an ability, a spell) follows the same pattern throughout.
- Record what was changed and what was left for the reviewer in `CHECKS.md`.

## Rules that still hold
- Heroic default with "default (Classic: value)"; rules text never names a source game or another game's series for a mechanic the game owns (source blocks, discussions, Zeal, Credits and the optional modules may).
- Every source block of version 5 appears in version 6, unchanged, exactly once.
- AWoD's text, the d200 spell list and Old-School Essentials: ideas and mechanics in our own words; no copied sentences.
- Reasons, never who decided or when. Shorter is better.

## Output
- `rules/v6/synthesis.md`.
- `rules/v6/CHANGES.md`: one line per id that is new, rewritten, moved, renamed, retired, settled or dropped as no longer needed, with the reason (a round 3 decision or note, BALANCE.md, round3-analysis.md, or the pass that found it), in the words earlier CHANGES.md files use.
- `rules/v6/CHECKS.md`: the findings of passes 2, 3 and 4.
- `rules/v6/README.md`: what version 6 is, the naming convention, what is settled, what is open, and "Questions for the next review": every open proposal in one line, the carried-forward ones marked as such.

## Tests
- Add version 6 to the format test (`tests/synthesis.test.js`) and the coverage test (`tests/coverage.test.js`).
- New `tests/synthesis-v6.test.js`, on the pattern of `tests/synthesis-v5.test.js`: every round 3 decision id and note target is accounted for in CHANGES.md or is settled unchanged; every rejected id is open; each of the 31 undecided ids is open in version 6 or CHANGES.md says what replaced it; the multiset of source blocks equals version 5's; and the consistency rules as checks that will keep holding: every ability and skill a class entry names has a proposal or a definition line; no proposal contains a retired name (the list above); each named thing in a list the test builds from the document (skills, abilities, classes, branches) never appears in a proposal in a different capitalisation; the class overview's list equals the set of class entries; no proposal contains "provisional, awaiting the balance pass" unless the README lists it.
- Coverage: `node scripts/check-coverage.js /home/patrickb/pen-paper-rpg/resources/text/<wod>.txt /home/patrickb/pen-paper-rpg/resources/text/<remix>.txt /home/patrickb/pen-paper-rpg/resources/text/<awod>.txt --synthesis rules/v6/synthesis.md` (file names in `tests/coverage.test.js`); keep the output as evidence.

## Prior art
Writing work in the project's own format, done the way versions 2 to 5 were (`rules/v5/CHANGES.md`, `tests/synthesis-v5.test.js`). The consistency rules become tests in the suite so the next version cannot drift. No new dependency.

## Leave alone
`rules/v1/` to `rules/v5/`, `docs/`, `chargen*/`, `site/` (the review page gets version 6 in a later task), `scripts/balance/`.

## Commands
`node --test tests/<file>.test.js`, `node scripts/<script>.js …`, `node scripts/balance/<script>.js`, `node .ws-evidence/<script>.js`, `git add`, `git commit`. One command per Bash call. Run long commands in the foreground.

## Done when
`rules/v6/` holds a version with the third round applied, the undecided proposals carried forward or accounted for, the balance report's numbers in place, the document agreeing with itself on names, references and numbers, every class with its sentence and its reason to be played, `CHECKS.md` listing what each check found, every source block present, and the format, coverage and version 6 tests passing.
