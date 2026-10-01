# figurewright spike: body shoulder options, so garments follow a believable shoulder

On the extreme builds (broad, round, short and round, the 155 and 188 cm averages, the tallest and shortest), the bodies' shoulders are square: a near-flat line from the neck out to a wide arm top. Every garment fitted over them (code-generated and imported alike, since both follow the same fit) ends up with super-wide shoulders whose sleeves hang well away from the arm. Fixing the garments would not help; the bodies' shoulders need to change, and the garments follow them. This spike renders options for a person to choose from. It changes no default in `src/`.

Read first: `src/body/skeleton.ts` (`shoulderShift`, `shoulderArc`, `shoulderArcCurve`, `shoulderArcOnto`, `posedShoulders` in `src/garments/posed.ts`), `src/body/sliders.ts` (`SLIDER_ENDS.shoulders`), `src/body/measurements.ts`, and `spike/body-refs-2/REPORT.md`: the shoulder measurements from photos (median 39.5 cm, range 36.2 to 43.0, n 6) and why the broad end sits at 47 cm (deliberately past the data, for a stylised look). `docs/renders/posed-builds.png` is the current approved look; Open Peeps' easing-2 figure, at the right of that sheet, has the natural sloped shoulder the heads were drawn for.

## Build (spike/shoulders/)
Make the shoulder shape a spike-only parameter (an options object passed through, or a spike copy of the functions), so `src/` defaults and every committed render stay byte-identical. Render these options:
- **A. Slope and cap.** The shoulder line drops from the neck base to the arm top at a natural slope (measure it on easing-2 and on the photos in `spike/body-refs*/`, roughly 15 to 25°), ending in a rounded deltoid cap that joins the arm. Width unchanged.
- **B. Width back to the data.** Shoulders +1 ends at 43 cm instead of 47, and the round builds' shoulder width does not grow with the belly (check what `shoulderShift` and the build slider do today, and say). Shape unchanged.
- **C. A and B together.**
- Add a fourth option only if the measurements point to one clearly, and say why.

## The sheet (docs/renders is not touched; save under spike/shoulders/renders/)
For each of current, A, B and C, one row on the builds listed above plus the average for reference:
1. the bare body, as `posed-builds.png` draws it;
2. the same body in the code-generated zip jacket over a tee;
3. the imported zip jacket (`assets/garments/zip-jacket.json`) over the same tee.
Add 3× close-ups of the near shoulder on broad and round for each option, and easing-2 on the same scale beside them. Label each row with the option, its slope in degrees and its shoulder width in cm per build.

## Measurements (spike/shoulders/REPORT.md)
Per option and build: shoulder width (cm), slope (°), and how far the jacket's sleeve top stands out from the arm at the shoulder (cm, near and far side). Compare the widths and slopes with the photo data. Recommend one option, in a sentence, with the reason; say what else in `src/` would change if it were adopted (garment fit, the import frames' shoulder-arc frame, the render goldens that would need re-approving).

## Tests
- `src/` is unchanged in behaviour: the render golden tests (`test/renders/`) pass untouched.
- The spike's option code has a small test that option "current" reproduces today's shoulder points exactly, so the comparison starts from the real thing.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts`, `node`. Do not run `npm install`. Hold one raster at a time; run long render jobs in the foreground, split if needed.

## Done when
The options sheet and close-ups exist under `spike/shoulders/renders/`, REPORT.md has the measurements and one recommendation, `src/` is unchanged, and the tests and tsc pass. A person picks the option from the sheet before anything changes in `src/`.
