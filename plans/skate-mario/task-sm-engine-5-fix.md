# skate-mario: RAM block, the move half (finish)

Track: light

This continues this branch (`2c336a5`). Scope, narrowed by the orchestrator: this step is the **move half** only (the engine's movement routines read and write only the block). The after half (`SkateBoardFrame`: drawing, the loose board, tricks, landing, getting on and off in the air, and SMB's pose, sound, score, CHR and OAM side into the adapter) is the next step. Make the README and `docs/research/skate-engine.md` say so plainly, and take the review's suggestions:

- patches/smb/skate-pedal.diff:349: The comment names SkateIoPop, which does not exist; the routine that turns io_pop into SMB's Y speed is SkatePopHost.
- docs/research/skate-engine.md:133: Section 2.2.1 is placed after section 2.3 (line 116) and before 2.4; move it under 2.2 or renumber it.
- harness/smbRamCompare.test.ts:30: Rule 15: the committed test checks the stack floor over the RAM movies only; the README's claim that no byte below $01E0 but the block differs over the 200 fall cases, the bank-room count and the NMI cycle count rest on scratch probes in .ws-evidence/scratch/ and a one-off smb:ram --falls run. A fall-case stack check in the suite (or the smb:ram CLI reporting the lowest stack byte written) would make the claim self-checking.
- docs/research/skate-engine.md:219: The busiest vine-movie frame is at 29,195 of 29,780 cycles and the bot's 1-1 movie lags once (frame 972) on both builds, so about 160 cycles remain; worth stating here as a constraint on moving the after half, since a copying adapter already cost 364 and lagged.

Never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository. Run `npm test` (with `.env.local` naming the ROM folder, the SMBDIS tree and asm6f).

## Prior art
The branch as it is.

## Commands
`npx vitest *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The docs state the move half is behind the block and the after half is next; the suggestions are taken or answered; `npm test` passes (log).
