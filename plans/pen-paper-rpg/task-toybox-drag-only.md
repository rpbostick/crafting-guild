# Toybox: the background reacts only while it is dragged

Track: light

In `chargen-toybox/` the animated background (read `backdrop/input.js`, `backdrop/Backdrop.tsx`, `backdrop/main.tsx`, `backdrop-controls.js`, `tests/backdrop-*.test.js`) reacts to pointer movement over bare background (`isBareBackground`, `data-solid`), and a left-drag on the background already shows a grabbing cursor (`html.backdrop-dragging`). Plain hover should no longer do anything.

## Behaviour
- The effect receives pointer positions **only while the left button (or a finger) is held down after a press that started on bare background**, until release. Hover without a button pressed feeds nothing.
- While dragging: the grabbing cursor (`cursor: grabbing`) everywhere until release, no text selection, page scroll blocked only for touch drags in colour mode as now. Hovering bare background with no button shows `cursor: grab` as a hint that it can be dragged (only while "Background reacts to the mouse" is on).
- On release (or pointer cancel, or the pointer leaving the window), the effect gets its "pointer left" state, so it eases back. Pressing on content (`data-solid`) never starts a drag.
- "Background reacts to the mouse" off: no grab cursor and no drag feed. Middle-click colour mode and wheel stepping are unchanged.

## Tests
Update the backdrop input tests: hover feeds nothing; press on bare background then move feeds positions; press on the sheet then move feeds nothing; release sends "leave"; the grab/grabbing cursor classes; the setting off disables both. Firefox input script (if present): hover over background → no feed, drag → feed. Rebuild both outputs and commit them.

## Commands
`node --test chargen-toybox/tests/<file>.test.js` (one or several), `node chargen-toybox/build.js`, `node chargen-toybox/build.js --public`, `node chargen-toybox/scripts/<script>.js`, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
The background follows the pointer only during a left-drag that started on bare background, shows grab/grabbing cursors, eases back on release, both builds are rebuilt, and the tests pass.
