# Character generator: a floating dice tray (2D by default, 3D on request)

Continue on this branch (the character on the World of Dungeons sheet, with animated backgrounds). Add a dice roller. The comparison spike is merged at `spikes/dice/` (read `COMPARISON.md`, `src/`, `tests/wod.test.js`): reuse its light 2D roller (our CSS dice + `@dice-roller/rpg-dice-roller`) and its dice-box integration.

## Behaviour
- **A floating dice tray window**, default **4 in wide × 8 in tall** (384 × 768 CSS px) at the **lower right** of the window, above the page; **draggable** by its title bar anywhere on screen (kept fully on screen), **resizable** from its corner (minimum about 280 × 420), with minimize and close buttons and a dice button in the controls to reopen it. Position, size and open/minimized state remembered per browser. Not printed.
- **Layout, top to bottom:**
  1. **Results log** (the top half): each roll with its time (`HH:MM:SS`), what was rolled (e.g. "STR 2d6+2"), the dice faces (kept and dropped shown for hit dice), the total, and for 2d6 attribute rolls the World of Dungeons band (6 or less miss, 7–9 partial, 10+ success, 12+ critical) in words. Newest at the bottom, scrolls; a Clear button.
  2. **The roller box**: where the dice tumble and land.
  3. **Buttons along the bottom:** d4, d6, d8, d10, d12, d20, d100, and a **modifier** control (a ± stepper showing e.g. "+2", reset by clicking it) applied to the next roll. **d100** is rolled as two d10: a tens die showing 00, 10, 20 … 90 and a ones die 0–9, read as 1–100 (00 + 0 = 100).
- **Links on the sheet:** clicking an attribute's value or name rolls 2d6 + that attribute; clicking a weapon's damage rolls it (with any bonus in its text); clicking HIT DICE rolls them (keep highest). Each sheet link is a button with a clear focus style and title ("Roll 2d6+2 for STR"); while drawing or editing a field, clicks edit rather than roll (the field stays editable via its text, the roll via a small die icon next to it if needed).
- **2D by default, 3D on request:** the 2D roller (our CSS dice) is the default. A **"3D dice"** switch in the settings loads Fantastic Dice (`@3d-dice/dice-box`) only when turned on and draws the 3D dice in the roller box; turning it off returns to 2D. Quick roll (no animation) is a setting too, and the default when `prefers-reduced-motion` is set.
- **Settings in their own popup** (a gear in the tray's title bar opens a dialog, not inline in the tray): 2D/3D, quick roll, dice color/theme (2D: colors and pip style; 3D: dice-box themes and color), sound on/off, throw strength and size for 3D. Remembered per browser.

## Design
- The tray's own code stays small; rpg-dice-roller loads lazily on the first roll as one inlined-but-deferred module or a separate file, whichever keeps the single-file page working (say which). dice-box's assets (worker, wasm, theme files) are **separate files** next to the page (`chargen/dist/dice-box/…`), loaded only when 3D is switched on; the single-file page must still work fully in 2D when opened from disk without them. List the files the public site has to host.
- Keep the spike's WoD band logic and tests; port them into `chargen/`.

## Prior art
`spikes/dice/` (merged): the 2D roller, the dice-box wrapper, WoD band tests. Libraries: `@dice-roller/rpg-dice-roller` (MIT), `@3d-dice/dice-box` (MIT). Draggable/resizable window: plain pointer events and CSS `resize` or a few lines of our own; no window library.

## Tests
`node:test` in `chargen/tests/`: WoD bands; d100 reading (00+0 = 100, 90+9 = 99, 10+0 = 10); modifier applied once; the log entry format with time; sheet links produce the right notation (2d6+STR, weapon damage with bonus, Nd6 keep highest); tray position/size kept on screen and remembered; 3D switch loads dice-box lazily (stubbed) and falls back to 2D if it fails; print hides the tray. Rebuild both outputs and commit them. Screenshots: the tray at its default place and size with a few rolls in the log, the settings popup, and the tray dragged and resized.

## Leave alone
`rules.js` behaviour, `data/`, everything outside `chargen/` and `spikes/dice/` (read-only).

## Commands
`npm install --prefix chargen --save-dev @dice-roller/rpg-dice-roller @3d-dice/dice-box`, `node --test chargen/tests/<file>.test.js` (one or several), `node chargen/build.js`, `node chargen/build.js --public`, `node chargen/scripts/<script>.js`, `node .ws-evidence/<script>.js`, `firefox --headless …` (as before), `git add`, `git commit`. One command per Bash call.

## Done when
A draggable, resizable 4 × 8 in dice tray sits at the lower right with a timestamped log above the roller and d4–d100 plus a modifier below; sheet attributes, weapon damage and hit dice roll into it; 2D by default with a 3D switch and a settings popup; both builds are rebuilt and the tests pass.
