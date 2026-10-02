# Research: spell lists and how their power is balanced

**Resume:** an earlier run of this task was cut off before it finished. Start with `git log` and `git status` in the worktree, keep the work already there (committed or not) if it is sound, and continue from it.

Track: light

The rules synthesis (`rules/v1/synthesis.md`, World of Dungeons family, "Remix" heroic power level by default) needs a spell list for Wizards (Wizardry as the careful study of spells). Gather openly licensed spell lists, compare them, and analyse how power is balanced across levels. Write `docs/research/spells.md`.

## Sources to find and read (use web search and web fetch; cite URLs with the date read)
- **Dungeon World** SRD (CC BY 3.0): the Wizard and Cleric spell lists, levels, the Cast a Spell move, ongoing spells, rituals.
- **Class Warfare** (Johnstone Metzger, a Dungeon World expansion): its spellcasting specialties and spells, and its licence (read it; say exactly what may be reused).
- **Old-School Essentials** SRD (OGL 1.0a; necroticgnome.com / oldschoolessentials.necroticgnome.com): arcane and divine spell lists by level, durations, ranges, saves.
- Also: World of Dungeons' own magic (`/home/patrickb/pen-paper-rpg/resources/text/` holds WoD, Remix and AWoD text; read by absolute path), and briefly Knave, Cairn, Maze Rats (spell generators), Into the Odd/Electric Bastionland (arcana), The Black Hack, Freebooters on the Frontier, where licences allow, as comparison points.

## For each source
Licence (exact terms, what can be copied vs. what must be rewritten), the list (name, level, one-line effect, duration, range, cost/limit), the casting mechanic and its limiting resource (slots, rolls with failure costs, components, quicksilver/HD), and how power grows with level.

## Analysis
- A cross-reference table: spells that appear in several systems (e.g. Magic Missile, Sleep, Charm Person, Light, Fireball) with each system's version side by side.
- **Power-level balance:** how each system keeps spells in line: per-level damage and effect budgets, durations, area, action economy, failure costs. Express damage per level in the synthesis's terms (d6-based damage, +HD scaling in the heroic default, Classic +2 as the optional) and suggest a budget per spell tier for the synthesis, with a worked example for 3 spells per tier.
- Gaps: spell kinds the WoD family needs that the lists lack (spirit work, quicksilver alchemy, utility).
- A recommendation: which list to base the synthesis's spells on, what must be rewritten for licence reasons, and how many spells per tier.

## Output
`docs/research/spells.md` with the above, a summary table at the top, and every fact sourced. Unverified facts marked.

## Prior art
This task is the prior-art search.

## Commands
Web search and web fetch for research. `git add`, `git commit`. One command per Bash call.

## Leave alone
Everything except `docs/research/spells.md`.

## Done when
The file covers the DW, Class Warfare and OSE spell lists with licences, compares them, analyses power balance with a per-tier budget for the synthesis, and is committed.
