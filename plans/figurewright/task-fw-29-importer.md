# figurewright I2: the garment importer script and the reference sheet under assets/garments/

Import build, step I2 of 5. I1 put the segment frames, the shoulder-arc frame, rigid frames and the `GarmentAsset` parser in `src/garments/import/`. This step moves the spike's SVG reader and importer into `scripts/` (src reads no files), commits the reference sheet and the two script-drawn garments as real assets, and pins them with a test.

Read first: `spike/import/REPORT.md` ("The asset format", "Fails loud"), `spike/import/svg-read.ts`, `importer.ts`, `import-all.ts`, `make-sheets.ts`, `sheet.ts`, `reference.ts`, `parametric-art.ts`, and `src/garments/import/` as I1 left it. For the script/asset/manifest pattern, `scripts/cut-extremities.ts`, `assets/extremities/` and `test/extremities/extremities.test.ts`.

## Build
1. **`scripts/garment-import/`**: the SVG reader (`svg-read.ts`), the importer (SVG to `GarmentAsset`, through I1's frames and `isRigidBySize`), and a CLI `scripts/import-garments.ts` that reads `assets/garments/art/*.svg` and writes `assets/garments/*.json`. Paths with subpaths and relative commands go through `scripts/svg-subpaths.ts`, as in the spike.
   - The importer applies `isRigidBySize` to every part; `!rigid` and `!warp` override it.
   - Every fail-loud case from the report, naming the group and the point index: a point outside its segment, an unknown segment, a class with no role, a role with no colour, a path outside a part group, a group for another garment's id, missing or invalid metadata, **and a non-`<path>` element in the garment layer** (the spike left this one untested).
   - The output is passed through `parseGarmentAsset` before it is written, so a script bug cannot write an asset src would refuse.
   - Output is deterministic: fixed key order and numbers rounded to 1e-4 cm, so a rerun is byte-identical.
2. **`scripts/make-garment-sheet.ts`**: writes `assets/garments/reference-body.svg`, the blank sheet (layers `skin` and `guide` locked, an empty `garment` layer, sample groups, a metadata template), from src only.
3. **Assets committed:** `assets/garments/art/tee.svg` and `zip-jacket.svg` (script-drawn from the parametric fit on the reference, as the spike's `parametric-art.ts` does; move that script to `scripts/garment-import/`), and their `assets/garments/tee.json`, `zip-jacket.json`. Add `assets/garments/README.md`: how an illustrator draws a garment on the sheet (layers, group labels, flags, classes, metadata), in the report's words, with the regenerate commands.
4. **The rigid share becomes ⅔.** Set `RIGID_WIDTH_OF_HALF` (`src/garments/import/rigid.ts`) to 2/3: a part narrower than ⅔ of its segment's half-width at its origin (about 10 cm on the reference chest) is rigid by default, so pockets, logos, pulls and buttons keep their shape with no flag. Update its comment and `rigid.test.ts`; `!warp` and `!rigid` still override.
5. **Comparison sheet for the rigid rule** (`docs/renders/rigid-rule.png`, and the script that makes it under `scripts/garment-import/`). Draw three details on a parametric tee: a 10 cm chest pocket, a 5 cm logo, and the zip pull. Show them on the broad, round, slim and average bodies under three rules, one row each, labelled: **¼ share** (as merged in I1), **⅔ share** (the new default), **¼ share with `!rigid` on the pocket**. Add 3× close-ups of the pocket on the broad body for each row. The labels say the rule and which details came out rigid. A person compares the rows; keep it legible at 100%.
6. Leave `spike/import/` in place; nothing in `src/` or `scripts/garment-import/` imports from `spike/`.

## Tests (test/garment-import/)
- **No drift:** running the importer in memory on `assets/garments/art/*.svg` gives exactly the committed `assets/garments/*.json`, and `make-garment-sheet` gives exactly the committed `reference-body.svg`. A failing message says which command regenerates it.
- One test per fail-loud case, each with a small inline SVG. Save a failing run first.
- Rigid by size: a 10 cm pocket on the torso imports rigid, a sleeve imports warped, and `!warp`/`!rigid` override each.
- The committed tee round-trips on the reference to 1e-4 cm (through `src`'s frames).
- `src/` still imports nothing from `spike/`, `scripts/`, `fs` or `path`.

## Carried from the I1 review
- `test/garments/import/rigid.test.ts:96`: the "round trip" test only checks lengths. Assert the zip pull's placed points against the drawn ones, or rename it.
- `src/garments/import/frames.ts:135` `normalFeet`: when `g` is exactly 0 at a sample the same foot is pushed twice; skip it when `prevG === 0`.
- `src/garments/import/shoulder-frame.ts:148`: `toTorsoPoint` re-solves `unposeTorso` after `toTorsoCoord` already did; reuse the first solve.
- `test/garments/import/frames.test.ts:33`: also bound the neckline and "anywhere" deviations (< 2 cm), so they cannot regress silently.
- Evidence: capture each command's real exit code in its log (`echo "exit $?"` in the same command is denied; run the command, then record the code the tool reported).

## Commands
One command per Bash call: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts`, `node`. Do not run `npm install`.

## Done when
`npx tsx scripts/import-garments.ts` and `npx tsx scripts/make-garment-sheet.ts` regenerate `assets/garments/` with no diff; every fail-loud case has a test; the rigid share is ⅔ and `docs/renders/rigid-rule.png` compares the three rules; the tests and tsc pass.
