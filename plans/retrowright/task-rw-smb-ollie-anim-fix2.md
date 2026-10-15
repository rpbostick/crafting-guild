# retrowright: ollie branch, correct the free-byte count

Track: light

This continues this branch (`8807470`). The review found one wrong statement; fix it and nothing else of substance:

- README.md:102 (rule 3): States "its pop and the kick-up's step 2 of the 5 after SkateAreaStart: 4 bytes are free there", but the branch also put the landing crouch's height and length in that filler: patches/smb/skate-pedal.diff lines 2403-2405 say those took 2 more and "this 1 is left (1 more is before the tunables)", and the filler there is one .db $ff. So 2 bytes are free, not 4, and the sentence should name the landing crouch's two. The README room test checks only bank 0's bytes and the new PRG banks, so this count is unchecked.

## Suggestions (carry forward, do not block)

Count the `.db $ff` filler bytes left in each place from the built ROM (or the diff), correct every README sentence and diff comment that states them, and if a test counts free bytes, make it check these. Then run `npm test` in full.

## Prior art
The branch as it is.

## Commands
`npx vitest *`, `npx tsx *`, `npm run *`, `npm test`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The README and comments state the free bytes as the build has them; `npm test` passes (log).
