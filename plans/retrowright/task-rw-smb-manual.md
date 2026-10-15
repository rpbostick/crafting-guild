# retrowright: Select only to get off, a manual on Down+B, fakie faces backwards again

Track: full

Three changes from play. Read the README's SMB section (step off / step on, the air mount, fakie, the nollie, the kick-up and its tilted tiles, the tricks), `patches/smb/skate-pedal.diff`, its tunables, `patches/smb/ollie-drafts/` and `harness/smbSkate.test.ts` first. Build with the untracked config in `.ws-evidence/scratch/` as before; never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository; store only our own pixels.

In play: "i want to get rid of down+b to get rid of the board though. i think select is fine. then we can keep down+b for other tricks or just riding. it's too easy to get off the board when you don't mean to." Down+B is to become a manual. On fakie: "Can't tell when I'm in fakie", so Mario faces backwards in fakie again.

## Build
- **Select only:** Down+B no longer steps off or on, on the ground or in the air. Select does both, everywhere it does now. Carrying the board without riding stays possible only through what still causes it (stepping off to climb). Remove the step tunable if nothing uses it (keep old saved tunables files loading). Update the tests and the vine movie if they press Down+B to get on or off.
- **Manual:** on the ground riding, holding Down and B together puts Mario on the board's back wheels, nose up (reuse the kick-up's tilted tiles or draw a frame, whichever reads better; say which), in the riding stance leaning back. He rolls on, coasting, while held; letting go puts the nose down. In fakie it is the nose manual (the front wheels, tail up). Down+B must not powerslide, push or step off. A manual has no time limit for now; tunable: the speed it keeps (friction while in a manual), with its sentence.
- **Fakie faces backwards again:** rolling fakie, Mario's sprite faces against his roll, as before the last change, and the board is drawn as it was then. The nollie's kick-up stays as built (the end leading the roll strikes down). Check the push frame, brake, powerslide, the 180, the kickturn and both tricks in fakie read right.
- **Movie tests:** Down+B on the ground and in the air does not step off or on; Select still does; Down+B held on the ground shows the manual (OAM: board tilted nose up, Mario's stance) and ends on release, in fakie the nose manual; no powerslide or push during it; fakie draws Mario facing against the roll; no lag frames. Run `npm run bot -- skate-pedal --mode board` and say whether 1-1 still finishes.
- **A comparison page** (`.ws-evidence/page/index.html`, not committed): the manual and nose manual, small and big, both facings; fakie riding, pushing and the nollie.

## Prior art
Tony Hawk's manuals (Up-Down to start, balance); here a held button with no balance meter yet. Build on the existing patch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`, `git merge *`. One command per Bash call.

## Done when
- The movie tests above pass with no lag frames; the bot finishes 1-1 on the board (logs).
- `npm test`, `npm run e2e:tune`, `npm run a11y` and `npm run build` pass. The README describes Select as the only way off, the manual, and fakie's look.
