# Research: the kinds of magic, where each comes from, and how games limit it

The rules synthesis (`rules/v4/synthesis.md`; read its "Magic and spells", "Spells" and "Optional modules" sections, and `docs/research/remix-vs-awod.md` and `docs/research/spells.md`) carries several kinds of casting inherited from three games: spirit summoning and binding, spells from study, innate or raw Chaos magic with corruption, priestly healing and turning, nature magic, illusion, alchemy, rituals, music magic and true names. The next review decides which kinds the game keeps, what each is called, and what each costs. The naming under discussion: **Wizardry** is book magic (studied spells, lightly limited in how many are held); **Sorcery** is innate power (probably Chaos or wild magic, fewer abilities but more flexible, perhaps with an Elementalist); **spirit magic** is the summoning of the 1979 *World of Dungeons*, which is kept; and homes are needed for cleric / healer / white magic, nature / druid magic and illusion.

Write `docs/research/magic-traditions.md`: for each kind of casting, its lineage and how games make it cost something.

## Kinds to cover (one section each)
1. Spirit summoning and binding (spirits, demons, angels, elementals; pacts; true names).
2. Book magic: studied, written spells (the "wizard").
3. Innate magic: sorcery in the blood, wild magic, raw Chaos with corruption and mutation.
4. Elemental magic (the elementalist), as its own kind or a branch of 3.
5. Priestly magic: healing, blessing, turning, miracles (cleric, healer, white mage).
6. Nature magic (druid, shaman, shapeshifting).
7. Illusion and enchantment of the mind.
8. Alchemy and made things (potions, devices, artifice).
9. Ritual magic (slow, costly, anyone can try).
10. Music and word magic (bard, skald, rune, true name).

## For each kind
- **Believed historical basis:** what real people believed and practised (for example the Solomonic grimoires and the *Ars Goetia*, Greek Magical Papyri, medieval necromancy and astral magic, theurgy, alchemy from Zosimos to Paracelsus, cunning folk, shamanism, seiðr and galdr, the fili and bard, miracle and exorcism). Two or three specific sources or practices, dated, each cited.
- **Fiction:** the novels, films and comics that set the popular image (for example Vance's *Dying Earth*, Moorcock's Elric, Le Guin's *Earthsea*, Leiber, Howard, Tolkien, Lovecraft and Clark Ashton Smith, *Doctor Strange*, *Hellblazer*, *Fullmetal Alchemist*, *Jonathan Strange & Mr Norrell*, *The Wheel of Time*). Say what each contributed.
- **Games:** where the kind enters roleplaying and video games and how its rules changed (for example OD&D and AD&D casters, *RuneQuest*'s spirit and rune magic, *Stormbringer*'s demon binding, *Warhammer Fantasy Roleplay* miscasts and corruption, *Ars Magica*'s verb-and-noun spells, *Mage*, D&D 3e's sorcerer and wild magic, *Final Fantasy*'s white and black mages, *Dungeon World*, *Dungeon Crawl Classics* spellburn and corruption, *Whitehack*'s HP-cost miracles, *Maze Rats* and *Knave*, *Into the Odd*). Dates and designers where known.
- **How it is limited and what it trades away:** the limiting resource in each cited game (slots, memorisation, spell points, HP or attribute cost, roll with a miscast table, corruption, time, materials, a patron's demands, a spirit's own will), and the usual trade-off against other kinds (breadth against flexibility, reliability against power, speed against safety).
- **For our game:** two or three sentences on what the lineage suggests for this kind in a 2d6, small-rules game: the cost that fits it best, and whether it is distinct enough to be its own system or reads as a list of spells inside another.

## Cross-cutting sections
- **A map:** one table, kinds against (historical root, defining fiction, defining game, usual limit, usual trade-off).
- **Which kinds are one system wearing different names:** where the lineages say two kinds are the same mechanism (for example priestly and nature magic as spell lists; illusion as a school of book magic; elementalism as a theme of innate magic), with the evidence.
- **Freeform against listed spells:** the history of build-your-own spell systems (*Ars Magica*, *Mage*, *Maze Rats*, *Whitehack*, *Barbarians of Lemuria*, AWoD's pick-lists and Remix's spell modifier) and how each prices range, area, duration, speed and power: the base case and what each step up costs. This feeds a uniform spell-building table for our game.
- **Glass cannons:** how games make the frail caster the highest damage dealer and what they take away in return (hit points, armour, limited uses, risk), with numbers where a source gives them.
- **Unknowns:** anything that could not be verified, marked.

## Sources
Web search and web fetch; cite every fact with a URL and the date read. Prefer primary sources, SRDs, publishers' pages, scholarly or encyclopedia articles and designers' own writing over fan wikis; where only a wiki has it, say so. The three games' texts are in `/home/patrickb/pen-paper-rpg/resources/text/` (read by absolute path). Quote no more than a sentence from any copyrighted work.

## Prior art
This task is the prior-art search.

## Commands
Web search and web fetch for research. `git add`, `git commit`. One command per Bash call.

## Leave alone
Everything except `docs/research/magic-traditions.md`.

## Done when
`docs/research/magic-traditions.md` covers the ten kinds with history, fiction, games, limits and a note for our game, has the map and the four cross-cutting sections, cites every fact, and is committed.
