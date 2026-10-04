# Spike: three quick looks for a four-page short edition of the rules

Track: light

The project is writing a role-playing game by merging three earlier games; the current text is `rules/v5/synthesis.md` (long, in a review format: `rules/v1/README.md` explains the blocks; read the `proposal` blocks, not the `source` blocks). The game needs a short edition in the manner of the original *World of Dungeons* (1979): a few printed pages holding the basics of nearly everything, usable on its own by people who know the game and as a reference at the table. The original is three US-letter pages in landscape (`/home/patrickb/pen-paper-rpg/resources/text/world_of_dungeons_1979.txt` is its text; its first page is two character sheets side by side and the rest is dense columns). Ours will be four pages, two sheets printed both sides:

1. the character sheet;
2. rules summary and character creation;
3. classes and abilities;
4. magic, equipment and the GM's page.

This spike is only about the look. Make three fast drafts of the same content so they can be compared side by side; the chosen one is finished in a later task, after the rules settle, so do not polish the wording.

## Build, in `spikes/mini-rpg/`
- `content.html`: pages 2 and 3 only, written once, condensed by hand from version 5's proposals (Heroic values; classes as one or two lines each; abilities as one line each; cut what does not fit and list what was cut in the README). Plain semantic HTML with classes, no inline styles. Each page is a fixed-size US-letter box; try landscape first, as the original is, and say in the README if portrait would hold more.
- Three stylesheets applied to that same content, each producing its own page:
  - `look-1979.css` → `look-1979.html`: in the original's manner. Dense columns, small capitals for headings, one accent colour on an off-white ground, boxed tables, rules between columns. No artwork or scans copied from the original; it must still read well printed in black and white.
  - `look-modern.css` → `look-modern.html`: plain and modern. Black on white, clear tables, generous enough to scan fast at the table.
  - `look-chargen.css` → `look-chargen.html`: matching the character generator (`chargen/`: read its stylesheet, `chargen/layout.js` and `chargen/dist/` for its colours, type and sheet style), so the short rules and the sheet read as one set.
- `index.html`: links to the three, each with a screenshot thumbnail.
- `@page` rules and `@media print` so each prints as exactly two letter pages with no browser margins surprises; on screen, show the pages as sheets on a grey ground.
- Fonts: system font stacks only for now. Name in the README the openly licensed typeface each look would use when finished.
- Screenshots of each look's two pages with headless Firefox, saved in `spikes/mini-rpg/shots/`, and look at them yourself: no text may overflow a page or a column, and nothing may be smaller than about 7.5 pt in print.
- `README.md`: what each look is, how much of pages 2 and 3 fitted in each (words and smallest type size), what was cut, and which look holds the most without becoming hard to read.

## Prior art
`docs/research/drawing-and-pages.md` compared page tools: with fixed-size pages, plain CSS (`@page`, CSS columns, `@media print`) is enough and Paged.js is more than needed. Reuse the character generator's own stylesheet values for the third look. No new dependency, no build step: three static pages.

## Leave alone
Everything outside `spikes/mini-rpg/`.

## Commands
`firefox --headless --screenshot <file> --window-size=<w>,<h> <file-url>`, `ls`, `cat`, `grep`, `git add`, `git commit`. One command per Bash call.

## Done when
`spikes/mini-rpg/index.html` opens three looks of the same two pages, each fits its two letter pages without overflow in the screenshots, and the README says how much each held.
