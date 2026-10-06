# figurewright: foundArtSvg in stages

Track: light

`scripts/garment-import/found-art.ts`'s `foundArtSvg` runs about 330 lines in one body: registration, zones, cutting, the behind piece, the waist and pocket completion, the ink and the sheet, sharing mutable counters (`holes`, `dropped`) and closures. Split it into stages that read in order, with no change in output.

Read first: `scripts/garment-import/found-art.ts`, `scripts/found-art-batch.ts`, `test/garment-import/found-art.test.ts`, `found-art-batch.test.ts`, `seam-leaks.test.ts`, and `docs/found-art.md`.

## Build
1. One function per stage (`register`, `cutZones`, `behindPiece`, `complete` for the waistline and pocket, `keepInk`, `writeSheet`), each taking what it needs and returning what the next needs; the counters become a small report object passed along, not shared closure state. `foundArtSvg` becomes the sequence of calls.
2. **No change in output**: before touching anything, write the three committed found-art garments' import output (the SVG and the asset JSON) to `.ws-evidence/before/` through the evidence runner; after the split, write them again and diff: byte-identical, with the diff log saved. The batch report `docs/found-art.md` is regenerated and unchanged.
3. The two statements on one line at the old line 505 split; the hull keeps its reason in a comment (the one-line monotone chain is kept over a dependency: say so).
4. Only this file and its tests change. Do not touch `src/`, `assets/` or the goldens: another branch is working on the body.

## Prior art
Nothing new.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts [args]`, `node`, `diff`, `cp` (inside the worktree). Do not run `npm install` or `npm run renders:approve`.

## Done when
The stages exist, the three garments' outputs are byte-identical before and after (diff log saved), the found-art tests and tsc pass, and nothing outside `scripts/garment-import/found-art.ts`, `scripts/found-art-batch.ts` and their tests changed.
