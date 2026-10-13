# retrowright: second control set (WASD and the mouse)

Track: full

Players without a gamepad want a second way to play: WASD for the D-pad and the mouse buttons for A and B, so one hand steers and the other acts. Read `src/input/keyBindings.ts` (bindings are already a list of codes per action), its tests, `src/ui/App.tsx` (the key handlers and the stage), the Controls view in `src/ui/QuickMenu.tsx`, the controls side panel, and the README's controls table first.

## Build
- **Defaults:** W, A, S and D (`KeyW`, `KeyA`, `KeyS`, `KeyD`) join the arrows for Up, Left, Down and Right. Saved bindings from before gain them where they are free, the way Tab and F2 were added; a key someone has already bound elsewhere stays theirs. Check nothing else uses W, A, S or D by default.
- **Mouse buttons:** a left click on the picture is A, a right click is B, held as long as the button is held (hold right to run in Mario). Give them codes such as `Mouse0` and `Mouse2` in the same bindings, so they show and can be rebound like keys. They act only while the pointer is over the picture; elsewhere the mouse works as normal. The browser's context menu is suppressed over the picture only. A click that gives focus back to the picture (the rule from rw-ram-search) must not also count as a press. Releasing the button outside the picture, or the window losing focus, releases A or B.
- **Controls view:** each button shows a primary and a secondary binding, both rebindable, and a mouse button can be bound by clicking while the view waits for input. Reset to defaults restores both sets.
- **Controls side panel and README:** list both sets.

## Prior art
Emulators commonly allow two bindings per button (RetroArch, Mesen, FCEUX's "Input" dialog), and browser games commonly use WASD with the mouse. The existing bindings model already holds a list per action: extend it, don't replace it.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `git add`, `git commit`. One command per Bash call.

## Done when
- With defaults, W/A/S/D move as the arrows do, a held left click on the picture is A, and a held right click is B with no context menu (unit tests and a Firefox script on a synthetic ROM reading the pressed buttons).
- Clicks outside the picture, and the click that returns focus to it, press nothing (tests).
- Old saved bindings gain WASD where free and keep a user's own use of those keys (test on an old-shape value).
- The Controls view rebinds the secondary of a button, including to a mouse button, and the side panel shows both sets (tests, screenshots).
- `npm run a11y` passes, the tests for what changed pass, and `npm run build` passes. The README's controls table lists both sets.
