# retrowright: combo shortcut keys and controller 2 as extra buttons

Track: full

An NES pad has eight inputs, so games use combos (Down+B, Down+A) for extra moves. On a keyboard, combos are awkward. This adds two ways to make them easy, both in retrowright and working with any game. Read `src/input/keyBindings.ts` and its tests, `src/input/gamepad.ts`, `src/ui/App.tsx` (key handling), the Controls view in `src/ui/QuickMenu.tsx`, the controls side panel, and the README's controls section first. Do not touch `patches/smb/` or `harness/smb*`: another builder is changing those.

## Build
- **Combo shortcut keys:** a key can be bound to a combo of game buttons for player 1, such as `C` → Down+B and `V` → Down+A. Holding the key holds every button in the combo; releasing releases them, without disturbing a button also held by its own key. Combos are stored with the bindings, shown in the Controls view (add, change, remove) and in the controls side panel, and exported with the settings. Defaults: none, but the Controls view offers two suggestions with one click: "Down+B" and "Down+A".
- **Controller 2 as extra buttons:** player 2's buttons can be bound to keyboard keys and mouse buttons like player 1's, so a game that reads pad 2 for extra moves can be played by one person. Today a second gamepad is player 2. Keep that, and add keyboard and mouse bindings for player 2 in the Controls view. Defaults for player 2: none, so nothing changes for existing players. A per-game note in the controls side panel is not needed yet.
- Bindings saved from before load unchanged (test on an old-shape value).

## Prior art
Emulator front ends offer macros or turbo/combo keys (RetroArch's input remapping, Mesen's key mappings for both ports). Extend the existing bindings model rather than adding a second one.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `git add`, `git commit`. One command per Bash call.

## Done when
- A combo key presses and releases its buttons together, and a button held by its own key stays held when the combo key is released (unit tests and a Firefox script on a synthetic ROM reading pad 1).
- Player 2's buttons bound to keys reach pad 2 in the game (Firefox script on a synthetic ROM reading pad 2).
- The Controls view adds, changes and removes combos and player 2 keys, and the side panel lists them (tests, screenshots on `.ws-evidence/page/index.html`).
- Old saved bindings load unchanged; `npm run a11y` passes; the tests for what changed pass; `npm run build` passes. The README's controls section describes combos and player 2 keys.
