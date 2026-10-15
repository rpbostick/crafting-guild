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

## Carried from the rw-level-spike review (suggestions; do them where the code is yours to touch)
- `docs/research/skate-levels.md:205`: In proposal B, the bridge (X 1328-1440) overlaps the row-3 brick row (X 1280-1392) and the hole (X 1376-1408). At X 1376-1392 that puts three long objects open at once, which is exactly the parser limit the doc gives at line 61. The cost and risk notes should say so, because moving or lengthening any of these objects, or adding one, would break the drawing there.
- `docs/research/skate-levels.md:14`: Rule 3: the 30-byte figure for 1-1's enemy data is not in either saved probe log. probe-level-addrs.log gives only the address $9F01. Either back the figure with the probe output or mark it as read from the source.
- `docs/research/skate-levels.md:92`: Rule 4 (the precheck FLAG is a false alarm): the doc does say this is jsnes's file, but writing the path as `node_modules/jsnes/src/mappers/mapper0.js` would make it resolvable and stop the precheck flagging it.
