# skate-mario: the homebrew test level skates

Track: full

Plug the skate engine (`engine/`, built with ca65 for any host) into the homebrew test level (`homebrew/`), so the box player rides a board with the skate physics: pushing, coasting, braking, the ollie, the 180 and the kickturn, getting on and off with Select, and the manual. Read `docs/research/skate-engine.md` section 2 (the interface: the RAM block, the calls, `HostSolidAt`), `engine/`, `homebrew/` and its README first. No SMB code, data or graphics in `homebrew/`.

## Build
- An adapter in `homebrew/` that fills the block from the homebrew's player state each frame, calls `SkateMove` before its collision and `SkateAfter` after, and `SkateDraw` for the board; `HostSolidAt` answers from the level's collision map. The homebrew's own walking physics stays for on foot.
- Placeholder art: a simple board drawn in two or three tiles of our own under the box player; a crouch and a push shown by simple changes to the box (for example a lower box, a foot pixel) if no art exists.
- Tunables: the engine's tunables table at a fixed address in the homebrew, the same schema as `patches/smb/skate-pedal.tunables.json`, written as `homebrew/skate.tunables.json` so retrowright's Tune panel (F3) can tune it when the file sits beside the ROM.
- **Tests:** boot the ROM in the retrowright core: hold Right with B taps and check speed rises as on SMB's board (pushes), coasting keeps speed, an ollie leaves the ground, Select steps off and on; no lag frames. Where the same inputs make sense on both hosts, compare the engine's outputs (speed per frame) with the SMB build's for the same inputs from a standstill on flat ground, and report the differences.
- `npm run homebrew:build` writes `homebrew/build/test.nes` and the tunables file beside it.

## Prior art
The engine interface; the homebrew base. Build on both.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `make *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`, `git merge *`. One command per Bash call.

## Done when
- The tests above pass (logs); the same-input comparison with the SMB build is in the result; `npm test` passes in full (logs).
