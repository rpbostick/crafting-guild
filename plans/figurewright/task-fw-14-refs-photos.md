# figurewright spike: a second pass of human reference photos (round men, standing women)

`spike/body-refs/` (read its `REPORT.md` first) mapped ANSUR II measurements, ten openly licensed Wikimedia Commons photos (traced to numbers in `data/photo-profiles.json` and `photo-traces.json`) and Open Peeps' pointing_finger and resting onto our skeleton, and set the slider ranges from them. It found gaps: **no front-view, full-length photo of a round man**, and most women's photos were **runway walks**, so their knees and lower legs were unusable. Patrick asked for a second search with another source.

Work only under `spike/body-refs-2/`; change nothing else (read `spike/body-refs/`, import from it, don't edit it).

## Decisions already made (Patrick, 2026-09-28; keep them in any prototype change)
Belly keeps pointing_finger's 9% overhang over the hips; the broad-shoulder extreme stays **47 cm** (stylised); round and pear builds' **thighs touch** near the crotch; average waist 29 cm; arms stop at 12° in front; clearance 2 cm; shoes scale with height.

## Sources
- **Unsplash** (Unsplash License) and **Pexels** (Pexels License): both allow free use including modification; neither allows selling the unaltered photos or building a competing photo service. Tracing to numbers is fine. Also Commons again with other search terms, and any **CC0 / public-domain** anthropometric photo sets you can find (e.g. research datasets whose licence allows this use; check and quote the licence).
- Wanted: **front-view, full-length, standing still** (not walking), swimwear or close-fitting clothes: **round men** (at least 3), **round women** (2+), **standing average and slim women** (3+) for knees and lower legs, and **tall and short** people if you find them. 8–15 new photos.
- Download into `.ws-evidence/refs2/` (untracked) at ≤1000 px tall. **Never commit a photo** or a render that contains one. Record URL, author and licence for each in the report.

## Do
- Trace each silhouette's half-widths at our stations with `spike/body-refs/`'s method, into `spike/body-refs-2/data/photo-profiles.json`.
- Re-run the station map with **all** photos (old + new), and say what changed: especially the belly and hip range for round bodies, the thigh gap, knee height and width, calf and ankle, and whether any slider range should move.
- Update the prototype's ranges only where the new data says so (copy `spike/body-refs/proto/` into `spike/body-refs-2/proto/`), within Patrick's decisions above.
- Renders (commit under `spike/body-refs-2/renders/`, ≤2 MB each, `@resvg/resvg-js` from `npx tsx` scripts): `human-vs-peeps.png` with the new traces **drawn more readably than last time** (one panel per build group, so the lines are not a tangle), and `builds.png` (the seven builds as in `spike/body-refs/renders/builds.png`, from the updated prototype, beside pointing_finger and resting).
- `spike/body-refs-2/REPORT.md`: sources with licences, what the new photos showed, the updated station table, any range changes, questions for Patrick, and a build step for `src/body` with a done-when.

## Commands and limits
One command per Bash call. `npx tsx spike/body-refs-2/<file>.ts`, `npx tsc --noEmit -p <tsconfig>`, `node`, `curl -L -o .ws-evidence/refs2/<file> <url>`, WebSearch, WebFetch. Do not run `npm install`. Run long scripts in the foreground. 4 GB memory cap: one photo or raster at a time. If a script is killed (exit 137), shrink it.

## Done when
The data, two renders and report are committed; no photo is in the branch; `git diff main...HEAD --stat -- ':!spike/body-refs-2'` is empty.
