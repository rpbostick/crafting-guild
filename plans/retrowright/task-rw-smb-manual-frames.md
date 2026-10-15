# retrowright: the kick-up's phases held longer

Track: light

This continues this branch (`26b219e`). In play on SKATE 25: "maybe the double the animation frames. spend a frame longer in each phase so they read better."

- Double the time each phase of the board's ollie and nollie kick-up shows: today the pop holds for 2 steps (6 frames) and the second frame 1 step (3 frames) at the kick-up step's default of 3. Make every phase twice as long (pop 12 frames, second frame 6) by changing the default and any per-frame holds, keeping the Tune slider working in steps. Say the new frame counts in the result and the README.
- Check the kick-up still ends before landing on a flat ollie at the default pop (if it does not, it carries into the landing as now; say what shows).
- Update the movie tests that count kick-up frames; run `npm test` in full and `npm run e2e:tune`.

## Prior art
The branch as it is.

## Commands
`npx vitest *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The phases are twice as long by default (movie test); `npm test` and `npm run e2e:tune` pass (logs).
