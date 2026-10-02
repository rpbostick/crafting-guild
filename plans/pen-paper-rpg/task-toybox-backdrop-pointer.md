# Toybox: the animated background reacts only to the bare background

Track: light

In `chargen-toybox/` (read `README.md`, `backdrop/`, `backdrop-controls.js`, `ui.js`, `index.html`, `tests/backdrop-*.test.js`), the animated background follows the pointer anywhere on the page, including over the character sheet, the controls, the dice tray and the drawing tools, because pointer movement is listened for on the window and passed to the effect. It should react only where the background itself shows.

## Behaviour
- Pointer movement, hover and drag feed the background effect **only while the pointer is over bare background**: not over the sheet (or any extra notes/drawing page), the controls bar, the dice tray, the drawing tool bar, dialogs, the portrait editor, or anything else on top of it.
- When the pointer moves from bare background onto the sheet or a tool, the effect behaves as if the pointer left (each component's own "pointer left" state: e.g. Waves settles, Threads/Balatro stop following), and picks up again when the pointer comes back onto bare background. No jump when it returns.
- Touch: the same rule for a finger.
- The middle-click colour mode and the wheel stepping already apply only over the backdrop: keep that, using the same "is this bare background?" test so the two rules agree.
- Decide "bare background" with one function (e.g. `document.elementFromPoint` / the event target is the backdrop layer or the page's own empty background, not inside any element marked as content), and mark content containers explicitly (a `data-solid` attribute or a class) so new tools are covered by adding the mark.

## Prior art
The existing backdrop input code and the figurewright hero rules it was ported from (`backdrop/vendor/site-reference/heroInput.ts`). No library.

## Tests
Unit tests for the bare-background test (sheet, controls, dice tray, drawing tool bar, an extra page, and empty background); the effect receives pointer updates only on bare background and a "leave" when crossing onto content; the Firefox input script (if present) moves over the sheet and asserts no pointer feed. Rebuild both outputs and commit them.

## Leave alone
Everything outside `chargen-toybox/`; the drawing, dice and sheet behaviour.

## Commands
`node --test chargen-toybox/tests/<file>.test.js` (one or several), `node chargen-toybox/build.js`, `node chargen-toybox/build.js --public`, `node chargen-toybox/scripts/<script>.js`, `node .ws-evidence/<script>.js`, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
The background only follows the pointer over bare background, behaves as "pointer left" over the sheet and tools, both builds are rebuilt, and the tests pass.
