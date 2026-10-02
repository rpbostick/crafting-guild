# toybox: plan

**In flight right now** (2026-10-02): repo ~/toybox created (ba1fa6d) from pen-paper-rpg spikes/toys (16 toys + drawer), MIT, registered. Step 1 running: `toybox-standalone` (task-standalone.md).

## Requirements (Patrick, 2026-10-02)
- Standalone library, public repo rpbostick/toybox (release audit first), served from rpbostick.github.io/toybox/ for a script tag.
- One script tag + custom elements: <toy-drawer>, <dice-tray>, <toy-background>, drawing layer, note/drawing pages (saved and printed). npm package too. Bookmarklet: future project.
- Contents: all 16 toys + drawer; dice tray (from pen-paper-rpg chargen-toybox/dice); animated backgrounds (chargen-toybox/backdrop); drawing layer and note/drawing pages (chargen-toybox/draw).
- Dice tray: must be resizable (check it really is), roll multiple dice at once (a pool such as 2d6+1d8 before rolling, and the notation box), and dice with any number of sides (dN input).
- chargen-toybox in pen-paper-rpg consumes the library; updating it must be one command (e.g. npm script that pulls a tagged release/dist into chargen-toybox).

## Steps
1. Make the repo standalone (paths from spikes/toys, e2e/bidi.js copied in), custom-element build dist/toybox.js, demo page, tests.
2. Extract dice tray, backgrounds, drawing layer + pages from chargen-toybox after `ppr-toybox-backdrop-pointer` merges; add dice pool, dN, resize fix.
3. chargen-toybox switches to the library with an update command.
4. Release audit, GitHub public repo, /toybox/ on the site.
