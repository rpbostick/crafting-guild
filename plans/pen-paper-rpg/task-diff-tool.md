# Diff tool: a side-by-side review page for the merged rules

`rules/v1/synthesis.md` merges three tabletop RPGs (World of Dungeons `wod`, Remix `remix`, Advanced World of Dungeons `awod`) into one document. It holds verbatim `source` blocks tagged by game and page, and `proposal` blocks with merged text, each paired with a `discussion` block by id. Read the file and `tests/synthesis.test.js` first; the block format is defined there. Build a static web page for reviewing it.

## The page (`site/`)
- Plain HTML, CSS and ES modules, no build step and no dependencies beyond what is vendored or loaded from cdnjs.cloudflare.com or cdn.jsdelivr.net (a Markdown renderer such as marked is fine). It must work served from the repo root (`python3 -m http.server`, page at `/site/`) and from GitHub Pages serving the repo root; it fetches `../rules/v1/synthesis.md` with a relative URL.
- **Side-by-side layout per section**: left, the source passages, each with a coloured tag for its game and page (three distinct colours, a legend at the top); right, the proposed text for that topic. A section or topic with a proposal is highlighted as a suggested change; a topic with no proposal shows the source text on both sides, unhighlighted.
- **Within a proposal**, show what changed against the source passages: a word-level diff of the proposal against the source text it replaces (insertions and deletions marked), with a toggle between the diff and the clean proposal.
- **Discussion** for each proposal is shown next to it (collapsible), visually distinct, with contradictions easy to spot.
- **Accept** button on each proposal (and an Undo/Reject). Decisions persist in `localStorage` (wrapped in try/catch; the page works without it). An **Export decisions** button downloads `decisions.json` (`{ "<id>": "accepted" | "rejected", ... }`), and **Import** loads one. Show counts (accepted / rejected / open) and a filter: all, open only, with contradictions.
- A **merged view** toggle: the whole document as it would read with accepted proposals applied and open ones still showing source text.
- A table of contents from the `##` headings, sticky on wide screens. Works at phone width (columns stack, no horizontal scroll). Light and dark themes via `prefers-color-scheme`.
- `[NAME? …]` placeholders are highlighted wherever they appear, and the `## Names to decide` section links to each proposal.
- Art lines `[art: …]` render as a small labelled placeholder.

## Code layout
- `site/parse.js`: a pure function `parseSynthesis(markdownText)` → `{ title, sections: [{ heading, level, items: [...] }] }` with blocks in order; no DOM. Group each proposal with the source blocks it sits among (the source blocks in the same subsection), so the page knows what to put on the left.
- `site/diff.js`: a pure word-level diff (your own small LCS, no dependency).
- `site/app.js`, `site/index.html`, `site/style.css`: rendering and state.

## Tests
`tests/site-parse.test.js` and `tests/site-diff.test.js` (`node:test`): parsing fixtures (each block kind, malformed blocks reported, grouping), parsing the real `rules/v1/synthesis.md` without errors with every proposal id matched to a discussion, and diff cases (insert, delete, replace, identical, empty). Run with `node --test tests/site-parse.test.js tests/site-diff.test.js`.

## Leave alone
`rules/`, `resources/`, `README.md`.

## Commands
`node --test …` for the tests above, `git add`, `git commit`. One command per Bash call. You cannot run a browser; keep rendering logic simple and put the logic worth testing in `parse.js` and `diff.js`.

## Done when
The page renders the real synthesis file with the side-by-side layout, accept/reject/export/import, the diff toggle, discussions and the merged view; the tests pass.
