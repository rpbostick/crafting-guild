# Research: licences of the source games and the Into the Odd engine

This repo is a private fan project merging tabletop RPG rules for a homebrew game. It will later become a public game that has to respect every licence. This report says, per source, what may be used freely, under what conditions, and what must be rewritten. It is research only, no code.

## Sources (on disk, untracked; read them by absolute path)
- *World of Dungeons* 1979 edition, John Harper: `/home/patrickb/pen-paper-rpg/resources/world_of_dungeons_1979.pdf` (text: `resources/text/world_of_dungeons_1979.txt` under the same directory).
- *World of Dungeons: Remix*, Tam H. (hedonic.ink): `/home/patrickb/pen-paper-rpg/resources/WoDuRemix.pdf`. Its credits page states CC-BY 4.0 and cites WoD as CC-BY, plus other CC sources (Dungeon World text CC-BY 3.0, spoutinglore, Sage Kobold). List every credited source and its licence.
- *Advanced World of Dungeons*, Norbert G. Matausch, April 2015: `/home/patrickb/pen-paper-rpg/resources/advanced-world-of-dungeons.pdf`. The PDF says "All illustrations creative commons, by Ivan Bilibin (exception page 12 … jungodingbats)" and "Cover art: unknown comic book artist", but has no licence line for the text. The game is believed to be CC-BY (2015, Norbert Matausch); a 2018 Dungeon World community thread says "Norbert has confirmed it is CC licensed" (https://dungeonworld.gplusarchive.online/2018/08/22/ive-been-looking-at-dungeon-world-and-world-of-dungeons-feeling-just-about-ready-to-run-a-game/). Find a primary statement of the variant (CC-BY or other) from the author: his blog analogkonsole.wordpress.com, itch.io (matausch.itch.io), DriveThruRPG, social posts, archived pages on the Wayback Machine. Say clearly whether CC-BY is confirmed or only probable. It is also based on the "Streets of Marienburg" WoD hack; find that hack's licence.
- *Electric Bastionland*, Chris McDowall (Bastionland Press), © 2020, all rights reserved: `/home/patrickb/pen-paper-rpg/resources/Electric_Bastionland_v2.pdf`.
- *The Painted Wastelands* (Agamemnon Press): no PDF yet; research its licence and any third-party or compatibility licence online.

## Questions per source
- Licence of the text, with version, and the exact attribution it requires. Licence of the art (each artist where credited), including whether the Bilibin illustrations are public domain, and what to do about art with no known licence (the AWoD cover, the jungodingbats illustration, any uncredited Remix art).
- What can be copied verbatim, what can be adapted, and what must be rewritten for a public release. Note game mechanics vs expression (rules mechanics are generally not copyrightable; text, tables, names and art are), with sources for that general point.
- Trademark or name issues (using "World of Dungeons" or "Electric Bastionland" in a title or as "compatible with").

## The Into the Odd / Electric Bastionland engine
How do games built on it (Cairn, Mausritter, Maze Rats is not one but check, Into the Odd Remastered, others) handle licensing? Is there a published licence or permission from Chris McDowall for derivative or compatible games (for example a third-party licence or a blog post)? What did Cairn (CC-BY-SA 4.0) take, and on what basis? What can a new game take from Electric Bastionland: the core engine (attributes, saves, damage), the Failed Careers concept, specific careers, oddities, spells?

## Output
`docs/research/licences.md` in this repo:
1. A summary table: source, text licence, art licence, attribution required, free to use / adapt / must rewrite.
2. One section per source with the evidence.
3. The engine section.
4. A draft attribution block the public game would carry.
5. Open questions to settle before release (for example: ask Norbert Matausch about the variant, replace the AWoD cover).

Cite every licence claim with its source URL and the date read (from `date`). Mark anything inferred as inferred.

## Commands
Use WebSearch and WebFetch for the research and Read for the PDFs. Commit the report with `git add` and `git commit`. One command per Bash call. No other commands are needed.

## Done when
The report answers each question above for all five sources and the engine, with cited sources, and states plainly what is confirmed and what is not.
