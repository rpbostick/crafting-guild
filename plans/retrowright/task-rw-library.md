# retrowright: a game library with Continue

Track: full

Read `README.md`, `docs/research/emulator-ux.md` (section 2, section 3's save states, and roadmap step 2), `src/ui/Library.tsx`, `src/storage/gameStore.ts`, and the quick menu (`src/ui/`, built in the previous task) first. Today the start page is a file picker and a Recent list of eight names. Players love OpenEmu's library that "just works" (drop a file, it appears with a picture) and ES-DE's favourites.

## Build
- **Library page** (the start page): game cards in a grid (a list view as an option), each with a thumbnail, the title, and when it was last played. The thumbnail is **the player's own picture**: the last frame shown when they left the game, or their latest save state's thumbnail; a neutral placeholder with the system name before the first play. Never fetch or bundle cover art from any database (see the research's licence table).
- **Titles** come from the file name, tidied (drop region and revision tags in brackets or parentheses into a small subtitle), and can be renamed by the player.
- **Favourites** (a star on each card, a Favourites filter), **search** (appears once there are more than about a dozen games), and sort by last played or by title.
- **Continue:** the newest game gets a large Continue card at the top. Whenever the tab is hidden or the page closes, the running game saves a **resume state** (separate from the eight slots, with its thumbnail). Continue loads the game and the resume state, so the player is back on the same frame with one click. Opening a game from its card offers Continue (if a resume state exists) or Start from power-on.
- **Add games:** a clear Add button and drag-and-drop anywhere on the library page; several files at once; a duplicate (same SHA-256) is recognised, not added twice.
- **Remove** a game (and, with a second confirmation, its saves).
- Storage stays per browser (IndexedDB), and everything degrades sensibly when storage is unavailable. Migrate the existing Recent list and its saves into the library without losing anything.
- Keyboard, gamepad and mouse navigation of the grid with visible focus; cards are real buttons with labels; light and dark themes; readable at phone width.

## Prior art
`docs/research/emulator-ux.md`: OpenEmu (drop-in library), ES-DE (favourites, collections), LaunchBox's grid/list views; the licence table rules out libretro-thumbnails, ScreenScraper, IGDB and TheGamesDB art. CSS grid for the layout; no new dependency unless clearly needed.

## Commands
`npm install *`, `npm ci *`, `npm run *`, `npm test`, `npx vite *`, `npx vitest *`, `npx tsc *`, `npx tsx *`, `node *`, `firefox --headless *`, WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call.

## Done when
- Closing the tab mid-game and reopening the page resumes the same frame with one click on Continue (the Firefox script shows it with Final Fantasy from `roms/`: the screen hash after Continue equals the one before the close).
- Cards show the player's own thumbnails, favourites and search work, titles can be renamed, and duplicates are recognised (unit tests on the store; Firefox screenshots).
- The old Recent list and its saves migrate into the library (a unit test with a fake IndexedDB holding the old format).
- No network request for art or metadata is made (the Firefox script records requests and finds none beyond the page's own files).
- `npm test` and `npm run build` pass; screenshots of the library (empty, a few games, light and dark, phone width) on `.ws-evidence/page/index.html`.
- README describes the library and Continue.
