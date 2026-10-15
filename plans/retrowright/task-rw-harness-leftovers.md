# retrowright: harness leftovers from earlier reviews

Track: light

Small fixes carried from earlier reviews of the record-and-replay and TAS tools. Another builder is changing `patches/smb/`, `harness/smbSkate.test.ts` and the README's SMB section: do not touch them.

## Fix
- Move the duplicated `BATTLE_RNG_STATE` and `bootAt` into `harness/tasStart.ts` and import it where they are used.
- Test `compare()` with a lead of +1 and -1.
- `tasTrace`'s default `--out`: make it a path under the working folder and test it.
- `fceuxRomMd5`: a test with trailing bytes after the ROM.
- Use the memory map's view type where the code re-declares it.
- The synthetic-ROM determinism test cannot fail: give it a case that would fail (a non-deterministic core stub) or remove it, with the reason.
- A frame-0 Mark in a current-state recording: test that it records and replays.
- Short replays can miss "Movie finished": make the message reliable and test a 1-frame movie.

## Prior art
The code as it is.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `git add`, `git commit`. One command per Bash call.

## Done when
- Each item is done or answered with a reason; the tests for what changed pass and `npm test` passes (log).
