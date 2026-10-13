# retrowright: testing view (labelled test links and a controls side panel)

Track: full

The operator compares builds of a game side by side, one browser tab per build. Today each tab starts at the library and the operator has to find and add the right file. Two changes make that direct. Read `README.md`, `vite.config.ts`, `src/ui/App.tsx`, `src/ui/Library.tsx`, the settings code, and the key bindings (`src/input/keyBindings.ts`) first.

## Build
- **Test links (development server only):** when the dev server runs with the environment variable `RETROWRIGHT_TEST_ROMS` set to a folder, it serves that folder's `.nes` files read-only at `/local-roms/`. Use a small Vite plugin or middleware in `vite.config.ts`; nothing is served without the variable, and nothing reaches `npm run build`'s output. A page URL such as `/?play=local-roms/<file name>&label=<text>` then fetches that ROM and starts it straight away. If the game isn't in this browser's library yet it is added first, so saves work as usual. A label banner across the top of the page shows `<text>` the whole time, unmissable but not covering the picture. A missing file gives a clear notice with the name it looked for. ROM files are never committed.
- **Controls side panel:** a panel beside the picture listing the current key and gamepad bindings for each game button and the main hotkeys (menu, fast-forward, screenshot, tools). It reads the live bindings, so a rebinding shows at once. Turn it on or off with a new setting in the quick menu's settings ("Show controls beside the game"), remembered like the other display settings and carried in an export. It defaults to off. A test link turns it on for that tab with `&controls=1`. Not shown in touch play, which has its own on-screen buttons. It must not clash with the tools panel (F4): both may be open, the picture stays the size display settings give it where the window allows, and on a narrow window the panels go under the picture.

## Prior art
Emulator front ends show a controls overlay or legend (RetroArch's "Quick Menu → Controls", many web emulators' key legends beside the canvas). It is a small piece of UI: write it, matching the existing panels' styles. For the dev-server folder, use Vite's `configureServer` plugin hook with `sirv` or a few lines of Node, not a new server.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `git add`, `git commit`. One command per Bash call. For your e2e, make a synthetic ROM folder inside `.ws-evidence/` and point `RETROWRIGHT_TEST_ROMS` at it.

## Done when
- With `RETROWRIGHT_TEST_ROMS` set, `/?play=local-roms/<file>&label=Original` opens straight into the game with the label banner showing. Two tabs with two different files and labels each play their own game (Firefox script, screenshots).
- Without the variable, `/local-roms/` returns 404, and `npm run build`'s output has no trace of the folder (test).
- The controls panel lists the live bindings, follows a rebinding at once, is toggled by the new setting, defaults to off, survives a reload, and `&controls=1` turns it on (unit tests and a Firefox script).
- With the tools panel and the controls panel both open on a desktop window, nothing overlaps (screenshot).
- `npm run a11y` passes with the controls panel open, the tests for what changed pass, and `npm run build` passes. The README describes test links and the controls panel. Screenshots are on `.ws-evidence/page/index.html`.
