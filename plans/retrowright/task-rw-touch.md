# retrowright: touch controls

Track: full

Read `README.md`, `docs/research/emulator-ux.md` (section 3's touch controls and skins, section 5, and roadmap step 3), `src/input/` (the button latch takes a `"touch"` source already), the quick menu and the library first. retrowright cannot be played on a phone without a keyboard or pad today. Delta's skins are the much-praised model: a layout described as data, per device and orientation, with button frames, enlarged touch edges and where the game screen sits.

## Build
- **Layouts as JSON data** (`src/touch/layouts/`): our own format modelled on the documented `.deltaskin` ideas (do not copy any Delta skin or its images): for each orientation (portrait, landscape), the screen rectangle and each control's frame, its button(s), and an extended touch edge. Draw the controls ourselves (SVG or CSS), clean and readable in light and dark themes. Built-in layouts for portrait and landscape on phones; tablets get the same, scaled.
- **Controls:** a D-pad that accepts diagonals and sliding between directions without lifting the finger; A and B, with an A+B area between them; Start and Select; the quick-menu button. Multi-touch, so moving and pressing A at once works. Optional light vibration on press where `navigator.vibrate` exists, off by default; a pressed state that shows.
- **When they appear:** automatically on touch devices (first touch), hidden when a gamepad or keyboard is used, and a toggle in the quick menu. The game screen moves to the layout's screen rectangle; in landscape the controls sit beside the picture.
- **Page behaviour on phones:** no page scroll, zoom or text selection while playing (`touch-action`, `user-select`), the safe-area insets respected (notches), and the orientation change handled without losing the game.
- **Size and opacity** sliders in the quick menu (moving buttons freely is for later).

## Also (carried from the library review and the operator's choices)
- Remember the library's grid/list view and sort order per browser (next to the theme), surviving a reload.
- Adding a single file starts that game at once; adding several files only adds them to the library.
- `updateGameIn` in `src/storage/gameStore.ts` throws inside `get.onsuccess` on a malformed record, so callers see a bare AbortError: reject with the real error.
- The library view's 'played' sort repeats `libraryOrder` from the store: export one comparator and use it in both.
- The e2e duplicate check and the 'Add works again in the same page' check pass a literal `true`; record the real notice text or card count under each check's name.
- `addFiles` in `src/ui/App.tsx` awaits `readyStore()` outside its try block, so a throw there becomes an unhandled rejection with no notice: move it inside the try, as `playGame` does.

- **A card must load what its picture shows** (found by the operator: Final Fantasy II's card showed a save-slot picture but clicking it started from power-on). `saveSummary` pictures the newest of the slots and the resume state, while a click only checks `resumeAt`. Make them agree: clicking a card opens a short choice whose first, focused item continues from the pictured save: "Continue" for a resume state, or "Load slot N" (with its time) when the newest picture is a slot. Also offer Continue (if a resume state exists and is not the pictured one), "Load a save state…" (the slot grid) and "Start from power-on". The big Continue card at the top follows the same rule. Test it: a game with only a slot loads that slot from its card; one whose newest save is the resume state continues it.

## Prior art
`docs/research/emulator-ux.md`: Delta's `.deltaskin` format (documented by the community: per-orientation layouts, button frames, extended edges, screen rectangle), Lemuroid's limits (only move and resize), and the research's warning not to bundle community skins. Pointer Events for multi-touch. No new dependency unless clearly needed.

## Commands
`npm install *`, `npm ci *`, `npm run *`, `npm test`, `npx vite *`, `npx vitest *`, `npx tsc *`, `npx tsx *`, `node *`, `firefox --headless *`, WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call.

## Done when
- In headless Firefox with touch emulation (or synthetic Pointer Events of type touch) at phone sizes in portrait and landscape, Final Fantasy (from `roms/`) is played from power-on through the story, the menu and naming into the game using touch alone (a touch e2e script, screenshots at each step).
- The layout JSON is validated by a unit test (every button present, frames inside the screen, no overlapping touch areas except the A+B area), and D-pad diagonals and slides are unit-tested.
- Touch controls hide when a gamepad or keyboard is used and come back on touch.
- No page scroll or zoom while playing on a phone-sized viewport (checked in the script).
- The tests covering the change pass and `npm run build` passes (the merge gate runs the whole `npm test`); screenshots of both orientations, light and dark, on `.ws-evidence/page/index.html`.
- README describes touch play.
