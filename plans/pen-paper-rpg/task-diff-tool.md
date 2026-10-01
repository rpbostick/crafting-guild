# Review tool: side-by-side merged rules with decisions and notes

`rules/v1/synthesis.md` merges three tabletop RPGs (World of Dungeons `wod`, Remix `remix`, Advanced World of Dungeons `awod`) into one document. It holds verbatim `source` blocks tagged by game and page, and `proposal` blocks with merged text, each paired with a `discussion` block by id. Read the file and `tests/synthesis.test.js` first; the block format is defined there.

Build a review web page for it. It will be published as a private claude.ai artifact page (a single self-contained HTML file) and used from more than one computer, so decisions and notes are stored in the artifact's database, not only in the browser. It must also run locally from the repo for development.

## The page
- **Original and new text side by side**, as the main layout: for each topic, the left column shows the source passages (each with a coloured tag for its game and page; three distinct colours and a legend at the top), the right column the proposed text, aligned at the top of the topic. A topic with a proposal is highlighted as a suggested change; a topic with no proposal shows only the source text, unhighlighted.
- **Within a proposal**: a word-level diff of the proposal against the source passages it replaces (insertions and deletions marked), with a toggle between the diff and the clean proposal. The source column stays visible either way.
- **Discussion** for each proposal next to it (collapsible), visually distinct, with contradictions easy to spot.
- **Decisions**: Accept and Reject buttons on each proposal, with Undo. Counts (accepted / rejected / open) and a filter: all, open only, with notes.
- **Merged view** toggle: the whole document with accepted proposals applied and open or rejected ones showing source text.
- **Notes**:
  - A note can be attached to a proposal, to any source passage, to a section, or be a general note (a notebook page).
  - Each note has text, a tag (`question`, `idea`, `todo` or none) and a status (`open` or `done`). Notes can be edited and deleted.
  - A notes panel lists every note, filterable by tag, status and target, each linking to where it is attached. Items with notes show a small count badge.
- `[NAME? …]` placeholders are highlighted wherever they appear, and the `## Names to decide` section links to each proposal.
- Art lines `[art: …]` render as a small labelled placeholder.
- A table of contents from the `##` headings, sticky on wide screens. Works at phone width: the columns stack with the source above the proposal, and there is no horizontal scroll. Light and dark themes.

## Storage
`site/store.js`: one interface, `createStore(backend)`, with `getDecisions/setDecision`, `listNotes/addNote/updateNote/deleteNote` and `subscribe(onChange)`. Three backends:
- **claude db** (when published): `const db = await claude.use("db")`. It resolves to `null` when unavailable and may take a few seconds; render the page first and attach storage when it resolves. Documents: `decisions/<proposalId>` `{ state: "accepted"|"rejected", updatedAt }`, and `notes/<auto id>` `{ target: { kind: "proposal"|"source"|"section"|"general", id }, text, tag, status, createdAt, updatedAt }`. Use `onSnapshot` on both collections once at startup so another device's changes appear live. Read the API in `/tmp/claude-1000/bundled-skills/2.1.287/f7efe37c293e72644e5c0ecb76550e58/artifact-capabilities/0.2.66/db.d.ts` and `claude.d.ts` beside it (Read them; do not copy them into the repo). `window.claude` has only `use`; never read other members from it.
- **localStorage** (local development, or when `claude.use("db")` resolves `null`): same shape, every access in try/catch. When the page falls back, show a small notice that changes are only saved in this browser.
- **memory**: for tests.

Store **Export** (a JSON file with decisions and notes, by a download link) and **Import** (merge from such a file) in the UI, so the data can be moved into the repo.

Stable ids: the parser gives every source block an id that survives edits elsewhere in the file: the section slug plus the tag, the page and a short hash of the passage's first 80 normalised characters. Proposals use their own `id`. Sections use their slug.

## Code layout
- `site/parse.js`: pure `parseSynthesis(markdownText)` → `{ title, sections: [{ id, heading, level, topics: [{ sources: [...], proposal, discussion }] }] }`, with blocks in order and malformed blocks reported, not thrown. Group each proposal with the source blocks it sits among (the source blocks in the same subsection).
- `site/diff.js`: a pure word-level diff (your own small LCS, no dependency).
- `site/store.js`, `site/app.js`, `site/style.css`, `site/index.html` (local development: fetches `../rules/v1/synthesis.md`; serve the repo root with `python3 -m http.server` and open `/site/`).
- `scripts/build-review.js`: writes `site/dist/review.html`, one self-contained file with the CSS, the JS modules and the parsed synthesis inlined (no fetch, no external scripts, fonts or images). Commit the built file. A Markdown renderer, if needed, is your own small one (paragraphs, lists, emphasis, tables) in a module.
- Page contract for the published file: a `<title>` of two to four words; colours as CSS custom properties on `:root`, redefined for dark mode under `@media (prefers-color-scheme: dark)` with the selector `:root:not([data-theme="light"])` and again under `:root[data-theme="dark"]`; an explicit `body` background; 16 px side gutters at phone width.

## Tests
`node:test`, no dependencies: `tests/site-parse.test.js` (fixtures for each block kind, malformed blocks, grouping, stable ids that do not change when an unrelated block is edited, and the real `rules/v1/synthesis.md` parsing with no errors and every proposal matched to a discussion); `tests/site-diff.test.js` (insert, delete, replace, identical, empty); `tests/site-store.test.js` (the memory and localStorage backends, the latter with a stub: decisions, note create/edit/delete, export then import round-trip); `tests/build-review.test.js` (runs the build into a temp path and checks the output contains every proposal id and no `<script src` or `fetch(`).

## Leave alone
`rules/`, `resources/`, `README.md`.

## Commands
`node --test` with the test files above, `node scripts/build-review.js`, `git add`, `git commit`. One command per Bash call. You cannot run a browser; keep the logic worth testing in `parse.js`, `diff.js` and `store.js`.

## Done when
`site/dist/review.html` is built from the real synthesis file and shows original and new text side by side with decisions, diffs, discussions, the merged view and notes; storage works through the db backend with the localStorage fallback; the tests pass.
