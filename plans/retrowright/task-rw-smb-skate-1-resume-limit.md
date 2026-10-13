# Resume after the usage limit

An earlier run of this task stopped at the usage limit with nothing committed. Its work is in this worktree: changes to `harness/smb.ts` and `harness/smbCli.ts` (stacked patches) and early `skate-all` and `skate-brake` patch files, none of them checked. Run `git status` and `git diff` first, keep what is sound, and finish the task below. Commit as you go.

## retrowright: SMB skate feel, step 1 (coasting, pushing, foot brake, ollie)

Track: full

The first skate-feel patches for Super Mario Bros. Each behaviour is its own patch, so the operator can compare them one tab at a time. All of them build on top of the existing `run-speed` patch (`patches/smb/run-speed.diff`), which the operator chose to keep. Read `docs/research/toolkit.md` section 4 ("SMB's physics, and what a skateboard needs") in full, `harness/smb.ts`, `harness/smb.test.ts`, `patches/smb/`, and the README's SMB section first. The SMBDIS source is at `~/retrowright-smb/smb1` (pass it as `RETROWRIGHT_SMB_SRC`, never write the path into the repository), and asm6f is at `~/retrowright-smb/asm6f-bin/asm6f` (pass it as `RETROWRIGHT_ASM6F`). The ROM is `roms/Super Mario Bros. (World).zip`.

### Build
- **Stacked patches:** let `npm run smb -- patch <name> --on <base>` build the untouched tree plus `<base>.diff` plus `<name>.diff`, and write a BPS from the original ROM to the result. Each skate diff contains only its own change; the BPS covers both.
- **`skate-coast`:** when the D-pad is released on the ground, Mario keeps rolling and slows gradually (much lower friction from `FrictionData` / `ImposeFriction`), instead of stopping within a few frames.
- **`skate-push`:** speed comes in pushes. Each fresh press of B adds a pulse of speed up to the running cap, instead of holding B to stay at run speed. Holding B does not keep adding speed. Between pushes Mario coasts as in `skate-coast` (this patch includes coasting, since pushing makes no sense without it).
- **`skate-brake`:** releasing the D-pad does not slow Mario more than coasting does. Pressing the opposite direction brakes firmly, like a foot drag. It includes coasting.
- **`skate-ollie`:** a jump with a fixed pop. It uses one row of the jump tables whatever the speed at take-off, keeps the full horizontal speed in the air, and lifts off a few frames (start with 3) after A is pressed. It includes coasting.
- **`skate-all`:** all four together, as one patch on `run-speed`.
- Keep each change as small as SMBDIS allows. Where a change needs new code, put it in free ROM space and say where. Name every RAM address and routine you use with SMBDIS's labels in the diff's comments.
- **Movie tests**, one per patch, skipping without the ROM or source like the run-speed test, each checking its behaviour with RAM checkpoints. Coasting: `Player_X_Speed` (`$57`) still above zero at least 30 frames after release, where on the original it reaches zero sooner. Pushing: speed rises in steps on B presses and doesn't rise while B is held. Brake: speed drops faster pressing back than coasting. Ollie: the same Y-speed pop at walking and running take-off, and lift-off N frames after the press.

### Prior art
`docs/research/toolkit.md` section 4 names the tables and routines (`FrictionData`, `MaxRightXSpdData`, `JumpMForceData`, `PlayerPhysicsSub`, `X_Physics`, `ImposeFriction`) and the skate behaviours. Bojidarist/smb1dg keeps SMB changes as source patches, which is the model for the diffs. There are no published skate mods of SMB1 to reuse; check romhacking.net's SMB1 hacks briefly for physics hacks with documented changes (read for ideas only; never copy unlicensed code).

### Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `sha256sum *`, `diff *`, `git add`, `git commit`, WebSearch, WebFetch. One command per Bash call.

### Done when
- `npm run smb -- check` still passes, and `npm run smb -- patch <name> --on run-speed` builds each of the five patches (logs).
- Each patch's movie test passes on its patched ROM, and fails on `run-speed` alone at the checkpoint that names its behaviour (logs for both).
- No SMB code, graphics or ROM bytes are committed: only the diffs (with `-U0` context), the BPS files, their `.json`, the harness changes and tests.
- The tests for what changed pass, and `npm run build` passes. The README lists each skate patch with one sentence on what it changes.
