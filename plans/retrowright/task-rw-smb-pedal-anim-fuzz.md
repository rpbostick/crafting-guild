# retrowright: stress-test falling off the board, 100+ times

Track: full

This continues this branch (`e3b442a`). The rolling-after-falling bug is fixed; the player does not want to test it by hand: "can you have them try to repeat the test like 100 times?" Prove it with a randomized test. Never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository.

## Build
- A seeded random test (`harness/smbFallFuzz.test.ts`, or a script `npm run fuzz:falls` plus a short test the suite runs with fewer cases) that makes Mario leave the board at least 100 different ways in World 1-1, then checks him on foot. Vary, from a seed: small or big; speed from slow to top speed; facing and fakie; on the ground or in the air; how he leaves (an enemy hit, a bail mid-kickflip or shove-it, Select on the ground, Select in the air, grabbing a vine or flagpole by RAM set-up); and what is held on the pad from the fall onward (nothing, Left, Right, Left+Right, Down, B, A, random changes every few frames).
- After each fall, check for 3 seconds: Mario is on foot (`SkateFoot`/riding state as the code defines it), his speed never exceeds SMB's on-foot caps, with the pad released he slows to a stop as SMB's Mario does (compare with the original game's deceleration from the same speed), he is never in the floor, and no lag frames. Any failing case prints its seed and inputs and saves a movie of it to `.ws-evidence/fuzz/`.
- Run 1,000 cases once (log the count and time), and keep a quick case count in the suite (say 50) with a fixed seed.
- Fix anything it finds, each with its own test.

## Prior art
The sweep test already on this branch; property-based testing (fast-check's model) for the seeded cases.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. Run long fuzz runs in the foreground.

## Done when
- 1,000 seeded falls pass (log with the count, the seed and any fixed failures); the suite's quick run passes.
- `npm test`, `npm run e2e:tune` and `npm run build` pass in full (logs).
