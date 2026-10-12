# retrowright: review leftovers from rw-display and rw-offline

Track: light

Small fixes the last two reviews carried forward. Read `src/ui/App.tsx` (the keydown handler near line 805), `README.md`, `e2e/a11y.mjs`, `e2e/staticServer.mjs` and the e2e scripts first.

## Build
- **Enter on controls outside the stage:** the rule "a control reached by Tab keeps Enter, Space and the arrows" applies only to targets inside the stage. Enter on a notice's Dismiss button or the Theme button is still prevented and sent to the game as Start. Make any focused button, link or form control outside the picture keep its keys (exclude only `document.body` and the picture itself), and make README.md (around line 78) say exactly what the code does. Add a unit test: with a game running, Enter on a notice's Dismiss button dismisses it and does not press Start.
- **Accessibility walk:** add the confirm view ("Save over a slot?") to `MENU_VIEWS` in `e2e/a11y.mjs`, and audit the empty library in the dark theme as well as the light one. Fix whatever it finds. Make the README's description of the check match what the script covers.
- **One static server for e2e:** the display, backup, firefox, touch and movie e2e scripts each carry their own `createServer` copy. Switch them to `e2e/staticServer.mjs`.
- **Re-run the display check:** run `e2e/display.mjs` against the current "auto" default (integer on desktop) and fix the script if its expectations no longer hold.

## Prior art
Not applicable: these are fixes to existing code, and `e2e/staticServer.mjs` already exists for reuse.

## Commands
`npx vitest *`, `npx tsc *`, `npm run *`, `node *`, `firefox --headless *`, `git add`, `git commit`. Run vitest on the files you touch, not the whole suite. One command per Bash call.

## Done when
- With a game running, Enter on a notice's Dismiss button and on the Theme button activates the button and does not reach the game (unit test, shown failing before the fix); the README says the same.
- `node e2e/a11y.mjs` passes, and its log shows the confirm view and the dark-theme empty library were audited.
- The five e2e scripts use `e2e/staticServer.mjs`, and each still passes when run (logs in `.ws-evidence/`).
- `node e2e/display.mjs` passes against the auto default.
- The tests for what changed pass, and `npm run build` passes.
