# retrowright: 1-1 stair gap, the first skate level change

Track: full

`docs/research/skate-levels.md` section 7 proposal A: widen the gap in 1-1's second pyramid (X 2368-2528) so the up-stair is a kicker and the gap a stair-set ollie. Read that document in full, the README's SMB section, `patches/smb/` (how levels stack: `--on`, `.json` `baseDiff`), `harness/smb.ts` and `harness/bot/` first. Build with the untracked config in `.ws-evidence/scratch/` as earlier SMB tasks did; never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository, and never commit SMB level data beyond the changed bytes the diff needs.

## Build
- A new patch level, `level-1-1`, stacked on `skate-pedal`, that changes only 1-1's area data: the hole widened and the down-stair moved right as section 7A sketches. Its BPS goes from the player's original ROM to the final build, like the others.
- **Settle the width with the bot:** run `npm run bot -- level-1-1 --mode board` and `--mode foot` for gap widths 3 to 6 columns (a build option or a tunable byte if cheap) and report, per width, finished or not, frames, and deaths in the gap's columns. Pick the widest gap that the board clears from the top step at speed and that on foot is still clearable (or say if none is), and build that.
- **Movie tests:** the gap's columns are empty and the stairs are where the sketch puts them (block buffer reads); a riding ollie from the top step at speed lands on the far side; no lag frames.
- **Watch link:** the bot's winning board run on the chosen width, written for the `&movie=` link, with the link printed in the result.

## Prior art
`docs/research/skate-levels.md`; SMB level editors' handling of the area object format (ideas only). Build on the existing patches.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. Run bot searches in the foreground.

## Done when
- The width table from the bot runs is in the result (logs); the chosen width's movie tests pass; the bot finishes the level on the board and on foot.
- `npm test` and `npm run build` pass. The README's SMB section describes `level-1-1` and the gap.
