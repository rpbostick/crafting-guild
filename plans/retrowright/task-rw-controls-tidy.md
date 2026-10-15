# retrowright: controls tidy-up from the Unbind review

Track: light

Read `src/ui/ControlsPanel.tsx`, `src/ui/ControlsSidePanel.tsx`, `src/input/keyBindings.ts` and the README's controls section first. Do not touch `patches/smb/`, `harness/` or the README's SMB section.

## Fix
- The README says a player 2 button with no key shows as unbound, but the side panel hides player 2 rows with no key (`ControlsSidePanel.tsx:73`). Say where it shows (the Controls dialog), in the README.
- `ControlsPanel.tsx:51`: the `sameButtons =(` formatting slip (the project has no formatter; fix it by hand).
- A test that unbinds a hotkey (the same `unbind` path).
- `keyBindings.ts:295`: format 3 now allows a combo's `code: null`. Add a sentence in the code comment saying older builds reject such saved bindings and fall back to defaults, deliberately without a version bump.

## Prior art
The code as it is.

## Commands
`npx vitest *`, `npx tsc *`, `npm run *`, `npm test`, `git add`, `git commit`. One command per Bash call.

## Done when
- The tests for what changed pass and `npm test` passes (log).
