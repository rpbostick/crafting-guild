# Toybox: the twisty cube can actually be turned, with instructions

The twisty cube toy (`src/twisty/main.js`, `src/twisty/index.html`, `src/toys/twisty-cube.js`; cubing.js `<twisty-player>`, MPL-2.0/GPL, on its own page in an iframe) only has Scramble and Reset; dragging orbits the camera, and there is **no way to turn a layer**. A user tried it and could not rotate anything. Make it a playable puzzle and explain how.

## Behaviour
- **Turn layers by clicking or dragging on the cube**, if cubing.js supports it: check its docs and source for move input on `<twisty-player>` (e.g. an `experimentalMovePressInput` / `experimental-move-press-input` option where clicking a sticker turns that face, with a modifier or drag direction for the other way). Use it if it works well; otherwise implement drag-to-turn with the player's 3D scene (hit-test the sticker under the pointer, pick the layer and direction from the drag), or say why that is out of reach and rely on the buttons and keys below.
- **Move buttons** under the cube: U, D, L, R, F, B each with a ⟳ and ⟲ button (clockwise and counter-clockwise as seen looking at that face), plus whole-cube turns (x, y, z) and the middle slices (M, E, S) in a "More" row. Labels show the face name on hover ("U: up face").
- **Keyboard:** letter = clockwise, Shift+letter = counter-clockwise (U D L R F B, x y z, M E S), Ctrl/Cmd+Z undo; only while the toy's window is focused.
- **Undo** button; a **move counter** and an optional **timer** that starts on the first move after a scramble and stops when solved; a short "Solved!" celebration when the cube is solved after a scramble.
- **Instructions:** a "?" button opens a short panel (and it shows once automatically the first time the toy is opened, remembered per browser): how to turn layers (click/drag, buttons, keys), what U/D/L/R/F/B and the ' (prime) mean, how to orbit the view (drag on the background / outside the cube, or right-drag — whatever the player does), undo, scramble, reset. Keep it to a few lines with a small diagram of the six faces.
- The postMessage API gains `move` (`{ type: 'move', move: "R'" }`), `undo`, and reports `solved` back to the host.
- Keep the source zip and licence notices current (`dist/twisty/source.zip` must include our changed files).

## Prior art
cubing.js's own player options and its `cubing/alg` and `cubing/kpuzzle` modules (for applying moves and checking the solved state); csTimer / cubing.js "twizzle" explorer conventions for notation and keys.

## Tests
Move notation and keyboard mapping (letter / Shift+letter → move strings); undo; solved detection after scramble + inverse moves (using cubing.js's kpuzzle, not a hand-written cube model); the instructions panel shows once and then on "?"; postMessage `move`/`undo`/`solved`. Firefox e2e: open the twisty toy, press R then R' (solved again), click a move button, open the help panel. CHANGELOG 0.6.1.

## Commands
`npm ci`, `npx …`, `node …`, `bash build.sh`, `bash scripts/<script>.sh`, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
The cube can be turned by clicking/dragging (or, if impossible, by buttons and keys, explained), with undo, move counter, timer, solved celebration, and an instructions panel that explains it all; version 0.6.1; tests pass.
