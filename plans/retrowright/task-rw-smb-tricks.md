# retrowright: kickflip and pop shove-it

Track: full

Build on the ollie kick-up branch, which is not merged yet: run `git merge agent/rw-smb-ollie-anim` first (it holds the kick-up, the nollie, fakie facing the roll, the riding stance after the kick-up, the landing crouch and the sunk-board fix), and say in the result which commit of it you built on. If that branch has uncommitted work or its builder is still running (`git log -1 agent/rw-smb-ollie-anim` older than 10 minutes is fine), merge its latest commit anyway and say so.

Add two flip tricks in the air on the board, with their board animations, and a bail when Mario lands before a trick finishes. Read the README's SMB section (the ollie and its kick-up frames, the nollie, fakie, the crouch, both board sizes, the loose board after a hit, the push frame and its CHR bank switch), `patches/smb/skate-pedal.diff`, its tunables, `patches/smb/board-drafts/`, the kick-up drafts and their tool, and `harness/smbSkate.test.ts` first. Build with the untracked config in `.ws-evidence/scratch/` as before; never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository; store only our own pixels.

## Build
- **Rename:** today's Down+B on the ground (step off carrying the board, and back on) is called "kick-flip" in the README, code labels, tunables (`kickHop`) and tests. Call it "step off / step on" everywhere (keep saved tunables files loading: the tunables file maps the old key, with a test). Its controls do not change.
- **Kickflip:** B pressed in the air while riding (after an ollie, a nollie, or rolling off a ledge) flips the board a full turn along its length under Mario's feet: deck, edge, underside, edge, deck. **Pop shove-it:** Up and B in the air spins the board half a turn flat: the board seen shorter, end-on, shorter, then whole again facing the other way (it lands the other way round; Mario's facing does not change). Mario's feet leave the deck during the trick (he rises a few pixels or tucks with big Mario's crouch frame, whichever reads better) and come back on it at the end. Frames per step are a tunable each.
- **Drafts:** 2 or 3 drafts of the frames each trick needs for both board sizes (edge, underside, the shorter and end-on views), drawn fresh in the board's style; use the ones that read best and say why; the rest stay as swappable files. A trick can start only when no trick is running; a second trick in the same air time is allowed if there is time.
- **Bail:** landing while a trick is still running knocks the board away as a hit does (the loose board, the hit sound, Mario on foot at his size, flashing), without hurting him.
- **Score:** a landed trick gives points as a stomp does (the floating score). A kickflip and a shove-it each count as one step of SMB's stomp chain for this landing (the next task chains them with stomps); here, give each landed trick the chain's first step (100) unless the chain is already running.
- **Movie tests:** B in the air plays the kickflip frames (OAM tiles or heights per frame) and the board ends as it began; Up+B plays the shove-it and the board ends turned (in fakie too); landing mid-trick bails (loose board, on foot, same size); a landed trick shows the score; B on the ground still pushes and Down+B still steps off; no lag frames. Run `npm run bot -- skate-pedal --mode board` (with `--cell 8` if the default sticks) and say whether 1-1 still finishes.
- **A comparison page** (`.ws-evidence/page/index.html`, not committed): the drafts at 1x and 3x, then strips of each trick's frames with Mario, both boards, both facings.

## Prior art
Skate games' 2D flip tricks (Skate or Die 2, Tony Hawk's Pro Skater 2 on Game Boy Color and Advance, OlliOlli's flip and shove-it frames); SMB's stomp scoring (`SetupFloateyNumber`, `StompChainCounter`). The board and kick-up drafts tools. Build on the existing patch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The movie tests above pass with no lag frames; the bot finishes 1-1 on the board (logs).
- `npm test`, `npm run e2e:tune`, `npm run a11y` and `npm run build` pass. The README describes both tricks, the bail, the score and the rename.

## Carried from the rw-gba-spike review (suggestions; do them where the code is yours to touch)
- `docs/research/smb-slopes.md:123`: Rules 3 and 15: 'The kicker build checks it in harness/smbSkate.test.ts' is written in the present tense, but the test does not exist yet. Write it as a plan ('the kicker build will add a check…') so nobody reads it as an existing guard.
- `docs/research/gba-core.md:7`: Rule 3: the doc says the npm logs are 'kept with the run's evidence', but those logs are untracked .ws-evidence files that do not ship with the doc. Consider putting the measured values and the commands that produced them inline, as the table already partly does, so the doc stands on its own after merge.
- `docs/research/gba-core.md:22`: The libretro core sizes in the Nostalgist row and the SkyEmu web build size are left unmeasured. The unknowns already say so; they could be filled in during the first build step.
