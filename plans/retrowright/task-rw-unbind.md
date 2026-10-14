# retrowright: unbind any key binding

Track: light

In the Controls view a binding can only be cleared by binding its key elsewhere, or by Restore default keys, which also wipes every other change. Add an Unbind control to every binding: player 1's buttons, player 2's buttons and combos. Read `src/input/keyBindings.ts` and its tests, `src/ui/ControlsPanel.tsx`, the Controls view in `src/ui/QuickMenu.tsx` and the README's controls section first. Do not touch `patches/smb/`, `harness/` or the README's SMB section: another builder is changing those.

## Build
- Each bound key or mouse button in the Controls view gets an Unbind control, reachable by keyboard and labelled for screen readers ("Unbind Z from A"). Unbinding removes that one key; the controls side panel updates. A button left with no key shows as unbound and can be bound again.
- Carried from the last review: extend the Restore default keys test in `src/ui/App.test.tsx` to bind a combo and a player 2 key first, then check both are gone and the side panel's tables for them vanish.
- One line in the README's controls section.

## Prior art
Mesen's and RetroArch's input settings (clear a binding per entry). Extend the existing bindings model.

## Commands
`npx vitest *`, `npx tsc *`, `npm run *`, `node *`, `firefox --headless *`, `git add`, `git commit`. One command per Bash call.

## Done when
- Tests show unbinding one key leaves the others, for player 1, player 2 and combos, and survives a reload.
- `npm run a11y` passes, the tests for what changed pass, and `npm run build` passes.
