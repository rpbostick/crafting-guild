# retrowright: skate tuning, round 2 (brake momentum, powerslide, finer ollie, ollie momentum) and the missing checks

Track: full

This continues the work on this branch (`skate-pedal` and the Tune section). The operator played it and tuned it live. His notes, in his words: "the tuning system is pretty cool. i think we need to build some momentum into the braking and maybe a powerslide mechanic ... the ollie jump control isn't fine-tuned enough. turn it down one notch and you can jump any obstacles; also we need some momentum physics for the ollies, rather than the air control stuff like in the regular game." Run `git log --oneline main..` and read your earlier result first; keep what is there.

## Build
- **Braking with momentum:** pressing back no longer bites at full strength at once. The braking force ramps up over a short time and carries the roll, so a stop from top speed is a smooth slowdown, not a wall. New tunables: brake ramp time (frames to full strength) and the existing brake strength.
- **Powerslide:** while rolling above a speed threshold, pressing Down plus back (or Down alone; pick one, make it a tunable choice if cheap, and say which you kept) turns Mario sideways into a slide. It slows him at its own rate, between coasting and the brake, and ends when the speed drops below a floor or the buttons are released. He keeps facing the way he was going. Show it: use an existing Mario frame that reads as a slide (the skid or crouch frame) for as long as it lasts. New tunables: slide threshold speed, slide friction, slide exit speed.
- **Finer ollie height:** the pop is now set by a Y speed (and, if needed, the gravity row) with fine steps, not by choosing whole jump-table rows. The slider has at least 8 steps between the current default and the next value down, so the height can sit just right for clearing pipes. Keep today's default as one of the values.
- **Ollie momentum, no air control:** in the air after an ollie, the D-pad no longer changes the horizontal speed or the direction. Mario keeps the speed and direction he took off with until he lands. A tunable "air control" from 0 (none, the default) up to SMB's normal amount lets the operator compare.
- Every new value goes into the same tunables table and `skate-pedal.tunables.json`, with a range, a default and one plain sentence each. Rebuild the BPS and keep the movie tests passing. Add movies for the brake ramp (speed falls smoothly, no single-frame drop larger than the ramp allows), the powerslide (speed falls at the slide rate and the slide frame shows), and the ollie (horizontal speed unchanged in the air while the D-pad is pressed backwards).
- **The checks left open last run:** `e2e/tune.mjs` in Firefox, skipping without the SMB ROM. It loads the SMB ROM, applies `skate-pedal.bps` in the library, opens Tools, reads `$0057` around a tap at two push values, moves the ollie slider and confirms the jump height changes, and saves a version and checks the downloaded `.bps` with `npm run patch -- apply`. Extend `npm run a11y` to open the Tune section with that ROM. Screenshots on `.ws-evidence/page/index.html`.

## Prior art
Skate or Die 2 (`~/retrowright-test-roms/Skate or Die 2 - REFERENCE.nes`) and the THPS games are the models for braking, powerslides and committed ollies. Measure Skate or Die 2's board deceleration and air control with the RAM search (tools panel) if it helps choose defaults, and say what you measured. Build on this branch's tunables table and Tune section; nothing to vendor.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. For the SMB build tests, use the untracked config in `.ws-evidence/scratch/` that sets `RETROWRIGHT_SMB_SRC` (`~/retrowright-smb/smb1`) and `RETROWRIGHT_ASM6F` (`~/retrowright-smb/asm6f-bin/asm6f`), as before; never write those paths into the repository.

## Done when
- The brake ramps (movie), the powerslide works and shows its frame (movie and a screenshot), the ollie has no air control at the default (movie), and the ollie pop slider has at least 8 steps between today's default and the next value down (test on the tunables file).
- Every new value appears in the Tune section with its sentence, and moving it changes the running game (Firefox script for at least the brake ramp and the ollie pop).
- `e2e/tune.mjs` passes, `npm run a11y` passes with the Tune section open, and a saved version's `.bps` applies in the harness to the same SHA-256.
- The tests for what changed pass, and `npm run build` passes. The README describes the new moves and sliders.
