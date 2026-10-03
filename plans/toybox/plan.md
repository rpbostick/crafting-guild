# toybox: plan

**In flight right now** (2026-10-02): repo ~/toybox created (ba1fa6d) from pen-paper-rpg spikes/toys (16 toys + drawer), MIT, registered. Step 1 merged (4662f48: <toy-drawer>, <toy-box>). Step 2: `toybox-widgets` widgets ported (326241d, review fix-first: autosave errors swallowed); continuing with task-widgets-2.md (fixes; own dice notation, mathjs gone; own backgrounds + registerBackground plug-in, React Bits only as a site-side example since its licence forbids redistributing components (Patrick 2026-10-02); classic toybox.iife.js toys-only + toybox-all.iife.js) (from task-widgets.md; sources staged in incoming/ from pen-paper-rpg chargen-toybox at d0d43f7).

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

- Next round (after widgets-2): backgrounds react only during a left-drag that starts on bare background (grab/grabbing cursors, settle on release), as Patrick asked for every site (2026-10-02).
- Same next round: an eyedropper in the drawing tools (EyeDropper API where available, else sample the page's own rendered layers/pictures/art), plus a row of recent colours (Patrick 2026-10-02). Momentum/inertia after a fling: Patrick said yes (2026-10-02). Figurewright gets it first (`site-waves-momentum`, pure module src/shared/momentum.ts on the site); the library's round after drag-eyedropper ports the same module into `pointerFeed` for every background, including plug-ins; chargen-toybox gets it with the switch to the library.
- 2026-10-02: widgets round 2 merged (e0f3e7d): own notation (mathjs gone), own backgrounds + registerBackground, toybox.js 24 KB start / toybox.iife.js 185 KB / toybox-all.iife.js 292 KB. Running: `toybox-drag-eyedropper` (task-drag-eyedropper.md). Next: chargen-toybox switches to the library (one-command update), then release audit, public GitHub repo, /toybox/ on the site.
- 2026-10-02: drag-only + eyedropper merged (84e3201), release toybox-0.4.0.zip built in ~/toybox/release/. pen-paper-rpg `ppr-toybox-use-library` running (vendor via chargen-toybox/scripts/update-toybox.js; React Bits stays on the sheet as a registerBackground plug-in; adds the toy drawer). Momentum: figurewright reworked into local ripple-stretch + swirl after Patrick's feedback (`site-waves-momentum`); port the final module into the library after he approves its feel.
- Fix: `bash build.sh` in a clean checkout produces chunk names different from the committed dist/ (seen 2026-10-02 twice); make the build reproducible (pin esbuild, stable chunk names) or stop committing dist/ chunks and build them for releases only.
- 2026-10-02 (Patrick: yes to 1-4): running `toybox-momentum-build` (task-momentum-and-build.md: kit modules for drag dynamics on every background; dist/ becomes a build product; 0.5.0). Then release audit, public repo (one audited commit, dev history private as with reactbits-kit), /toybox/ on the site.
