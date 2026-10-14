# retrowright: loose board, start every life with a board

Track: full

This continues this branch (`bc0a643`). Read your earlier result and `git log --oneline main..` first; keep what is there. Build with the untracked config and the scratch tooling in `.ws-evidence/scratch/` as before; never keep SMBDIS source in `.ws-evidence/` or the repository. Only change the SMB section of the README.

In play: "lost the board one life, it doesn't come back the next. so always start with a board is needed." The has-a-board state survives losing a life, so Mario starts his next life on foot with no board.

## Fix
- Mario starts every life with the board, riding: a new game, the life after losing one, a continue after Game Over, and the start of each level (a new world or area entered through the flagpole or a castle). A pipe or vine inside a level keeps what he has. Any loose board still on screen is cleared at each of those starts.
- Find where SMB sets up a new life and a new level (`InitializeGame`, `InitializeArea`, `PlayerLoseLife`/`ContinueGame`, `GameOverMode`), and set the state there rather than patching each path separately where one place covers them.
- Measure first: write in the result which RAM the has-a-board, riding and loose-board states live in, and why they survived the life loss (cleared range or not).

## Also, from the review
- A board flying right near the right edge of the screen is gone at relative X `$F1`, though Mario runs toward it and the screen scrolls to it. Keep the board while it is within a page beyond either side of the screen, as SMB's enemies are kept, so it can be chased; it goes once it falls behind the left edge or more than a page ahead. Movie test.
- Hit before Mario has moved in an area (`Player_MovingDir` 0): say in the asm comment and README which way the board flies.
- `harness/smbSkate.test.ts:973`: compute the hit frame once before `caughtFrame`'s search.

## Prior art
SMB's own reset of `PlayerStatus` on a lost life (`PlayerLoseLife`) is the model. Build on this branch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- Movie tests, each failing on `bc0a643` and passing now (logs): lose the board, then lose a life: the next life starts riding with a board; lose the board, then finish the level: the next level starts riding; a pipe keeps the board state as it was; no lag frames.
- Every existing skate, expand and tunables test still passes; `npm run e2e:tune` and `npm run build` pass. The README says when Mario gets the board back.
