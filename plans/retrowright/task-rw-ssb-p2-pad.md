# retrowright: Super Skate Bros., either controller drives whoever's turn it is

Track: light

In Super Skate Bros.' 2-player game Luigi reads controller 2, as in SMB, and retrowright binds no keys for player 2 by default, so on one keyboard Luigi cannot move. In play: "we dont have controls for player 2. because we commandeered the first controller." Chosen: in Super Skate Bros. only, the player whose turn it is reads controller 1 and controller 2 together (the two pads' bits combined), so one keyboard works and a second gamepad still works. `skate-pedal` is unchanged. Read the README's Super Skate Bros. section, `patches/smb/super-skate-bros.diff` and `harness/superSkateBros.test.ts` first. Build with the untracked config in `.ws-evidence/scratch/` as before; never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository.

- Combine the pads where SMB reads the current player's joypad (`ReadJoypads` / `SavedJoypadBits` by `CurrentPlayer`), in Super Skate Bros.' code (bank 1 or the stub), with as few bytes in SMB's banks as possible; the title menu still takes Select and Start from controller 1.
- Movie test: a 2-player game where Luigi's turn is played on controller 1 and moves him; Mario on controller 2 also moves him on his turn; the attract demo still plays as before (its test passes); no lag frames.
- Rebuild the demo ROM in the test and check the name scan still passes. README line.

## Prior art
SMB hacks' "one controller for both players" option (ideas only). Build on the existing patch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The movie test passes; the Super Skate Bros. tests pass with the SMBDIS tree named; `npm test` and `npm run build` pass (logs).
