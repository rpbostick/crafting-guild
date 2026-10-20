# skate-mario: SMB3's momentum on foot (fix round on this branch)

Track: full

Played on foot, the movement does not keep momentum the way SMB3 does. Fault to fix: **on foot, momentum matches SMB3's.** The branch is yours from the previous run; build on its tip.

## Facts from the disassembly (read by the orchestrator in Southbird's `PRG/prg008.asm`, `Player_GroundHControl` and the code after it, about lines 2316-2470; builders cannot fetch it)
- **In the air with no direction held, nothing changes the X speed** (`LDA Player_InAir / BNE PRG008_AC01`, a return before the friction). The friction and stopping rate run only on the ground.
- **In the air over the top speed, the speed is not cut** (same branch before the "friction stopping rate" offset): air keeps any speed it took off with.
- **In the air with a direction held**, the same `Player_XAccel*` rates as the ground apply: the normal rate toward the held direction, the skid rate when the held direction is opposite the movement (`AND Player_MoveLR`).
- **Uphill caps do not depend on steepness.** On any slope while marching uphill (`Player_UphillFlag`), the top speed is `Player_UphillSpeedVals` index 10 (`$0D`) without B and index 1 (`$16`) with B held. Replace `footUphillSteep`/`footUphillGentle` with `footUphillWalk` (13) and `footUphillRun` (22).
- `Slope_PlayerVel_Effect` (`PRG/prg000.asm`) is 3 on the 45-degree shapes and 2 on the 22.5-degree ones; these are read now. Mark them read in smb3-model.md sections 1.4, 6 and step 4, and the values above in section 1.1 and step 5, citing the labels and line numbers given here.

## Build
- `walk()` and `movement()`: on foot, in the air, apply the rules above; on the ground, unchanged.
- The uphill caps as above, as tunables.
- From the sm-foot-5 review: `footGravityHeld`'s min becomes 1.
- On the board, no change. `engine/` untouched. Update `skate.tunables.json`'s SHA-256 with the build.

## Tests
In `harness/homebrewFoot.test.ts`: a running jump with no direction held lands with its take-off speed (frame by frame, the X speed unchanged in the air); a jump at running speed holding the walking direction is not slowed to the walking top speed in the air; reversing in the air slows at the skid rate; walking up the steep and the gentle slope caps at 13 without B and 22 with B. Show the new cases failing on the branch's previous tip first (log). `harness/homebrew*.test.ts` pass.

## Prior art
SMB3's own code as cited above (values and rules only).

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `make *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. Read files outside the worktree with the Read and Grep tools.

## Done when
- On foot: momentum matches SMB3's (the cases above fail on the previous tip and pass now, logs).
- `harness/homebrew*.test.ts` pass (logs).
