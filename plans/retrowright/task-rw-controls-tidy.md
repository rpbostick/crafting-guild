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

## Carried from the rw-e2e-all review (suggestions; do them where the code is yours to touch)
- `e2e/outcome.test.ts:14`: Rule 2 (precheck FLAG): runs.tsv has no failing run for the new test. The test does exercise the real `outcome()` and can fail. A recorded red run, for example with the `!lines.some(PASS)` guard removed, would show that the whole-script skip case can fail, since that path never ran end to end here.
- `e2e/all.mjs:45`: If `spawn` emits 'error', the promise rejects and the write stream for that check's log is never ended. The run aborts with an unhandled rejection instead of printing a FAIL line for that check. It is unlikely, since `npm` is on PATH whenever this runs through `npm run`, but resolving to a failed status would keep the per-check reporting consistent.
- `.ws-evidence/after-e2e-all-final.log:7`: Evidence formatting: the 'Logs:' line records an absolute home-directory path. It is untracked evidence, so it can be cleaned at merge.
