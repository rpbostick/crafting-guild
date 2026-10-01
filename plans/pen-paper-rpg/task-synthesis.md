# Synthesis: merge World of Dungeons, Remix and Advanced World of Dungeons into one tagged document

This repo is a private fan project. Version 1 of its rules is one document that merges three related games and keeps nearly all of their content, each passage tagged with the game it came from, plus proposed merged text and a discussion wherever they differ. A later step builds a side-by-side diff web page from this file, so the block format below must be followed exactly.

## Sources (on disk, untracked; read by absolute path)
| Tag | Game | PDF | Extracted text |
|---|---|---|---|
| `wod` | *World of Dungeons*, 1979 edition, John Harper (3 pages) | `/home/patrickb/pen-paper-rpg/resources/world_of_dungeons_1979.pdf` | `/home/patrickb/pen-paper-rpg/resources/text/world_of_dungeons_1979.txt` |
| `remix` | *World of Dungeons: Remix*, Tam H. (42 pages) | `/home/patrickb/pen-paper-rpg/resources/WoDuRemix.pdf` | `/home/patrickb/pen-paper-rpg/resources/text/WoDuRemix.txt` |
| `awod` | *Advanced World of Dungeons*, Norbert G. Matausch (20 pages) | `/home/patrickb/pen-paper-rpg/resources/advanced-world-of-dungeons.pdf` | `/home/patrickb/pen-paper-rpg/resources/text/advanced-world-of-dungeons.txt` |

The text files were made with `pdftotext -layout`, so multi-column pages are interleaved side by side. Untangle the columns, and check doubtful passages against the PDF with Read (it renders PDF pages; pass `pages`). Do not use any other book.

`resources/wod-chargen/docs/RULES.md` in this repo is a paraphrased WoD rules spec from an existing character generator; use it as a cross-check, not as a source.

## What to write
`rules/v1/synthesis.md`:
- `#` title, then `##` sections in an order a player reads a rulebook: core mechanic and moves/rolls, attributes, skills, classes (and races/kits where a game has them), special abilities, magic and spells, equipment and money, harm/HP/armor/combat, advancement, GM guidance and procedures, monsters, tables and generators, anything else. Use `###` subsections where a section is long (one per class, for example).
- **Every passage of every source appears once**, verbatim (fix only line breaks and hyphenation from extraction), in a `source` block in the section where it belongs. Nothing is dropped, including flavor text, examples, tables and credits (credits go in a final `## Credits` section). Where a passage covers two topics, split it at a paragraph boundary.
- Where the sources differ or overlap on a topic, add a `proposal` block with merged text for our game and a `discussion` block with the same id saying what each game does, what contradicts, which way the proposal goes and why, and the alternatives. Preserve rather than choose: where classes, skills, abilities or spells differ, the proposal keeps all of them, creating new classes or variants when two games give the same name different content. Give each new class or variant a placeholder name in the form `[NAME? <short description>]`; names are decided later.
- Where only one source covers a topic and nothing needs changing, no proposal is needed.
- A final `## Names to decide` section lists every placeholder with the proposal id it appears in.
- Art: where a source page has an illustration, note it in that page's source block as a line `[art: <source> p<N>: <what it shows>]`. Do not extract images in this step.

## Block format (a parser depends on it)
Blocks open with a line `::: <kind> <args>` and close with a line `:::`, alone, with no nesting:
```
::: source wod p1
verbatim text
:::

::: proposal id=classes-fighter
merged text, Markdown allowed
:::

::: discussion id=classes-fighter
what differs and why the proposal goes this way
:::
```
- `source` takes the tag (`wod`, `remix`, `awod`) and the PDF page as `p<N>` (the PDF's page index, 1-based).
- `proposal` and `discussion` take `id=<kebab-case>`, unique across the file, and come in pairs with the same id.
- Text outside blocks is allowed only for headings and short connecting notes.

## Tests
Add `tests/synthesis.test.js` (`node:test`, no dependencies) that reads `rules/v1/synthesis.md` and checks: every `:::` block opens with a known kind and closes; source tags and pages are valid (pages within 1–3, 1–42, 1–20); proposal ids are unique and each has exactly one discussion; every `[NAME? …]` placeholder is listed in `## Names to decide`; each source tag appears at least once. Run it with `node --test tests/synthesis.test.js`.

Coverage: write `scripts/check-coverage.js` that, given the three text files (paths as arguments), reports any source paragraph whose words do not appear in the synthesis (normalising whitespace and hyphenation). Run it as `node scripts/check-coverage.js <the three .txt paths>` and get the uncovered list to zero, or explain each remaining item in your result (extraction junk such as page numbers is fine to skip). It is not part of the test suite because the text files are not in git.

## Leave alone
`resources/` (do not edit or commit anything there), `README.md`.

## Commands
`node --test tests/synthesis.test.js`, `node scripts/check-coverage.js …`, `git add`, `git commit`. One command per Bash call.

## Done when
`rules/v1/synthesis.md` holds all three sources in the block format, with proposals, discussions and the names list; the test passes; the coverage script reports nothing uncovered (or each remainder is explained).
