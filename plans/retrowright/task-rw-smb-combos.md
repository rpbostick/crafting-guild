# retrowright: trick and stomp combos for coins and 1-ups

Track: full

Resume: an earlier run of this task was cut off by the usage limit. Its work is in the worktree (`git status`, `git log --oneline main..`); read it and keep what fits.

Tie tricks into SMB's stomp chain, so stringing tricks and stomps together pays out in points, coins and 1-ups. Read the README's SMB section (the tricks, their score and bail, the manual, the loose board), `patches/smb/skate-pedal.diff`, its tunables and `harness/smbSkate.test.ts` first, and SMB's stomp chain (`StompChainCounter`, `SetupFloateyNumber`, the score ladder 100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000, then 1-up). Build with the untracked config in `.ws-evidence/scratch/` as before; never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository.

## Build (a first version, tuned in play)
- **One combo:** a landed trick and a stomp are both steps of one chain. Each step pays the ladder's next score; the step after 8000 is a 1-up, as SMB's stomp chain gives.
- **Coins:** each landed trick in a combo also gives a coin (SMB's coin sound and count; 100 coins is a 1-up as usual) from the combo's second step on.
- **Keeping the combo alive across landings:** in SMB the stomp chain ends when Mario lands. On the board it carries on if he lands riding and does the next trick or stomp within the combo window (a tunable, in frames, default about 1 second). It ends on a bail, a hit, stepping off, or the window running out.
- **Bails twice as forgiving, and optional:** in play: "can we make the trick fail bailing off the board about twice as forgiving? and also add an option to turn it off." Today landing while a trick is still running bails. Make it twice as forgiving: measure today's window (how many frames before landing a trick must start to finish) and double it, by counting a landing as clean when the trick is at least a set share done (a tunable, `bailGrace`, default so the forgiving window is twice today's; the remaining frames snap to the finished board). Add a tunable choice `bails` (on/off, default on): off, a landing mid-trick always snaps the trick finished and scores it. Movie tests for both.
- **Manuals keep it alive:** landing into a manual (Down+B held) within the window keeps the combo going for as long as the manual is held; the window starts again when the manual ends. A trick landed while a stomp chain runs in the same air now scores the chain's next step (today it scores nothing).
- **On screen:** the floating score at each step as SMB shows it; nothing new on the status bar.
- Tunables: the combo window and the step at which coins start, each with its sentence.
- **Movie tests:** ollie, kickflip, land, ollie again within the window and stomp a Goomba: the second and third steps pay 200 and 400 and a coin; a landing with the window run out restarts at 100; a bail ends the combo; a long chain (RAM-set to step 10) gives the 1-up; no lag frames. Run `npm run bot -- skate-pedal --mode board` (with `--cell 8` if the default sticks) and say whether 1-1 still finishes.

## Prior art
Tony Hawk's combo system (manuals keep a combo alive; ours is the landing window), SMB's stomp chain and Koopa-shell chain. Build on the existing patch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`, `git merge *`. One command per Bash call.

## Done when
- The movie tests above pass with no lag frames; the bot finishes 1-1 on the board (logs).
- `npm test`, `npm run e2e:tune` and `npm run build` pass. The README describes combos, coins and the new tunables.
