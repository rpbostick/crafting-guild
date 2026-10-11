# retrowright: first run and save safety

Track: full

Read `README.md`, `docs/research/emulator-ux.md` (sections 4 and 5, and roadmap step 4) and the library (`src/ui/`, `src/storage/`) first. Two gaps: a newcomer with no games gets no explanation, and saves live only in this browser's storage, which the browser may clear.

## Build
- **Empty library:** two plain sentences on what to do ("Load a `.nes` file from your computer. It stays in this browser and is never uploaded."), a large drop zone and Add button, and a short "Where do games come from?" explanation (your own cartridge dumps; free homebrew, with links to the NESdev wiki's homebrew list or the NES Open DB rather than to any ROM site). No ROM is bundled.
- **Keep saves safe:** after the first save, call `navigator.storage.persist()` and show whether the browser granted it; a storage meter (`navigator.storage.estimate()`) in the library's settings; a gentle warning when the browser did not grant persistence, explaining that saves could be cleared and suggesting an export.
- **Export and import:** export everything (games' saves, save states with thumbnails, resume states, settings and key bindings; ROMs optional, off by default) as one file the player downloads; import it in another browser to get the same saves (matched to games by ROM SHA-256; saves for games not yet added wait until the ROM is added). Per-game export from a card's menu too. Version the file format and reject a newer one with a clear message.
- **Sound hint:** while audio is blocked, show "Click or press a key to start sound" once, near the picture.
- **Focus and gamepad hints** (research section 5): show "Paused: click to resume" when the window loses focus; in Controls, "Press any button on your controller" until a pad appears.
- **Docs:** README's "Node.js 20 or later" is wrong for the e2e scripts (puppeteer-core 25 needs Node 22.12+): fix it.

## Prior art
`docs/research/emulator-ux.md`: ES-DE's no-games dialog, the Internet Archive's one-click start; the Storage API (`persist`, `estimate`) and Safari's storage eviction notes from the research's browser table. The `.rwmovie.json` versioning in `src/movie/format.ts` as a model for the export file's version field. No new dependency unless clearly needed (a zip library only if one file is not enough; say why).

## Commands
`npm install *`, `npm ci *`, `npm run *`, `npm test`, `npx vite *`, `npx vitest *`, `npx tsc *`, `npx tsx *`, `node *`, `firefox --headless *`, WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call.

## Done when
- A fresh browser profile sees the empty-library explanation (Firefox screenshot).
- Saves exported from one browser profile load in another: the Firefox script exports from one profile, imports into a fresh one, adds Final Fantasy from `roms/`, and its battery save and a save-state thumbnail are there.
- Persistence is requested after the first save and its result shown; the storage meter shows a number (unit tests with a stubbed Storage API).
- Importing a file of a newer format version is refused with a message (unit test).
- The tests covering the change pass and `npm run build` passes (the merge gate runs the whole `npm test`); screenshots on `.ws-evidence/page/index.html`.
- README: the Node version fixed; export and import described.
