# retrowright: opposite directions cannot be held together

Track: light

A real NES pad cannot press Left and Right (or Up and Down) at once, and games are not written for it: in SMB it made Mario walk on in a frozen skid. Block it in retrowright for every game and every input (keyboard, mouse buttons, gamepads, touch, combo keys, player 2): when both of a pair are held, the one pressed last wins; releasing it gives the other back if still held. Read `src/input/` (the button latch, key bindings, combos, gamepad), the touch controls and the README's controls section first. Do not touch `patches/smb/` or `harness/smbSkate.test.ts`.

- Apply it where the pad state is built for the core each frame, so movies record what the game saw; movies already recorded replay as they are (their stored masks are not changed).
- Tests: Left then Right held gives Right; releasing Right gives Left back; the same for Up/Down; a combo key that holds Down plus another key holding Up; a gamepad's d-pad and stick together; a synthetic ROM in a Firefox script reads no frame with both bits set (add to `e2e:all`).
- One README line in the controls section.

## Prior art
RetroArch's and Mesen's "allow opposite directions" options (default off), "last input priority" (SOCD cleaning) in fight sticks.

## Commands
`npx vitest *`, `npx tsc *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The tests above pass; `npm test`, `npm run a11y` and `npm run build` pass (logs).
