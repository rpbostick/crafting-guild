# Fix round 1 for `task-sm-split-smbskate.md`

The review of this branch at 375e7cb found blocking issues. Fix each one, with a test where the finding is about behaviour, commit, and re-run the covering test files through ws-run. Do nothing else; suggestions are carried to a later task.

## Blocking findings
- `README.md:63` (rule 3): The paragraph says it was 'Measured in World 1-1 at those values (`harness/smbSkatePatches.test.ts`)', but only the B taps, brake, 180, kickturn, direction taps and title-screen claims are tested in that file. The push frame and the arrows' push rhythm are in smbSkateRiding. The two boards, the climb and the swim are split across smbSkateLives and smbSkateCrouch, and the crouch is in smbSkateCrouch. The vine movie is in smbSkateLanding, the kick-up and nollie in smbSkateKickUp, and the manual in smbSkateManual. The pointer is now false for most of the paragraph. Fix: point it at the harness/smbSkate*.test.ts files, or name each file next to its claims.
- `README.md:65` (rule 3): 'The loose board, in the same file:' now refers to smbSkatePatches.test.ts, which has none of the loose-board, lives, pipe, hit-sweep, mushroom or Select-in-the-air tests. Those are in smbSkateLooseBoard, smbSkateLives, smbSkateHit/Hit5/Hit9, smbSkateOnFoot and smbSkateMount. Fix: name those files instead of 'the same file'.

## Commands
`npm test`, `npx vitest *`, `npx tsc *`, `npx tsx *`, `node *`, `grep *`, `diff *`, `git add`, `git commit`, `git mv *`. One command per Bash call. The worktree's git-ignored `.env.local` sets the ROM variables, so the SMB tests run here.

## The original task (for context)
## skate-mario: split smbSkate.test.ts so the suite spreads across workers

Track: light

`harness/smbSkate.test.ts` takes about 213 s in one vitest worker, which is the whole suite's wall time on its own; under load its slow cases hit the 30 s limit (it timed out on main on 2026-10-20). Split it into several files by its top-level `describe` groups (for example `smbSkatePedal*.test.ts`, by feature), each a few tens of seconds, so vitest runs them in parallel. Shared setup moves into a helper module (`harness/smbSkate.ts` or similar) and is built once per file.

### Rules
- Every test keeps its name and its assertions; none removed or loosened. The total count of tests is the same before and after (log both).
- Slow cases that stay above 10 s alone get an explicit timeout with a comment on why.

### Prior art
Vitest runs files in parallel and tests within a file in sequence; splitting by file is its documented way to spread work. The harness's existing split SMB files (`smbExpand`, `smbRamCompare`, `smbFallFuzz`) as the pattern.

### Commands
`npm test`, `npx vitest *`, `npx tsc *`, `npx tsx *`, `node *`, `grep *`, `diff *`, `git add`, `git commit`, `git mv *`. One command per Bash call. The worktree's git-ignored `.env.local` sets the ROM variables, so the SMB tests run here.

### Done when
- `npm test` passes twice in a row (both logs), with the suite's wall time and test count before and after in the result; the longest file is under 60 s.
