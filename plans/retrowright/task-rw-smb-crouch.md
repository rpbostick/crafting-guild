# retrowright: big Mario crouches on the ollie

Track: full

On the board, the ollie should look like a skater's: a crouch before the pop, and a crouch held in the air. Read the README's SMB section (the ollie, its delay, the powerslide's crouch frame for big Mario, the board sizes), `patches/smb/skate-pedal.diff`, its tunables, `harness/smbSkate.test.ts` and `harness/bot/` first. Build with the untracked config in `.ws-evidence/scratch/` as before; never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository.

## Build (on the board only, big Mario only; on foot stays SMB's jump; small Mario keeps his jump picture)
- **Crouch into the ollie:** pressing A on the board shows big Mario's crouch frame (SMB's duck picture) through the ollie delay, then he pops.
- **Stay crouched while A is held:** after the pop he stays crouched in the air while A stays held; letting go of A stands him up.
- **Crouch in the air:** riding in the air standing (A let go, or after rolling off a ledge), pressing Down or pressing A crouches him again; letting go of both stands him up.
- **Crouched is smaller**, as SMB's duck is: while crouched in the air, big Mario's collision box is the ducking one, so he can pass under things a standing big Mario would hit and does not bump blocks above. Make sure standing up again inside a gap behaves as SMB's own duck release does (no getting stuck in blocks); test it.
- The board stays drawn under his feet in the crouch, at the right height for the crouch picture.
- **Movie tests:** the crouch frame shows during the ollie delay; it stays while A is held in the air and goes when A is released; Down in the air crouches; the crouched collision box is the duck one (Mario passes under a block row a standing big Mario would hit, set up by a RAM edit if 1-1 has no such place); small Mario's ollie is unchanged; no lag frames. Run `npm run bot -- skate-pedal --mode board` and say whether 1-1 still finishes.
- **Hide the board while climbing:** while Mario climbs a vine or slides down the flagpole (`Player_State` 3, and the flagpole's slide), the board is not drawn; it shows again when he lets go, still riding. Test with the vine and flagpole set-ups the climbing tests use.
- **A comparison page** (`.ws-evidence/page/index.html`, not committed): big Mario crouching before the pop, crouched in the air, standing in the air, both facings and fakie, on the 24-pixel board.

## Carried from the last review
- `runBot` stores `report.movie` and `report.stuck` relative to the working folder too (not only the printed text); update `bot.test.ts`'s expectation.

## Prior art
SMB's ducking (`PlayerCrouch`/`CrouchingFlag`, the duck bounding box in `BoundBoxCtrlData`), and skateboarding games' ollie animation (crouch, pop, tuck). Build on the existing patch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The movie tests above pass with no lag frames, and the bot finishes 1-1 on the board (logs).
- `npm test`, `npm run e2e:tune`, `npm run a11y` and `npm run build` pass. The README's SMB section describes the crouch.
