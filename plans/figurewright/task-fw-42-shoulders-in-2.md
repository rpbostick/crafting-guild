# figurewright: the shoulders come in on the wide builds (resume: the band is decided)

**Resume.** Same branch (`agent/fw-shoulders-in`), second run, through c364381: `scripts/shoulder-band.ts`, the measures moved out of `test/`, the carried suggestions done. Run `git status` and `git log --oneline main..` first. Change files with Edit and Write; `cp` works inside the worktree.

## Decision on your open question
**Adopt reading (2): the drawn bideltoid equals the two-fit bideltoid around the medium, with a band of ±1.5 cm a side** (the fits' leave-one-out error). It agrees with what the eye saw: broad and round read too wide, and your measurement under (2) puts them 0.9–1.44 cm a side over. Treat (1), the population's bideltoid-over-chest ratio, as context only, for the reason you gave (its rise with chest is fat on the deltoids in the high-BMI bands, which the two-fit model puts on the upper arm). The excess comes from the arm hanging from the armpit, where the drawn shoulder grows 1 cm per cm of chest against the acromion's 0.35: that is what the hang change below corrects. The ANSUR II per-subject CSVs are not available to you; the summary is enough for this band.

## Then, as in the task below: steps 2 to 5 and the evidence
Render and measure hangs (a) and (b) at the two-fit target on broad and round; choose by the measurements; build the rule so every named build's drawn bideltoid sits within the band (slim and tall and slim come out by their 0.55); garments and poses follow; re-import, re-pin after looking, `renders:approve`; tests; the evidence page with every image path relative to `.ws-evidence/page/index.html`.

---

## figurewright: the shoulders come in on the wide builds

The last body task brought the chest out to meet the shoulders and made the caps round again, and the overhang is bounded. But broad and round kept about the same shoulder width: they still read as wide-shouldered figures over a body that is not that wide. The requirement stands: real shoulders are only as broad as the chest makes them. This task brings the shoulders themselves in on the wide builds. The last run said this means the arm hanging partly over the torso rather than from the armpit: a skeleton change. That is this task.

Read first: `src/body/skeleton.ts` (the arm's hang, `ARMPIT_T`, the armpit rule), `src/body/sliders.ts` (`shouldersFromChest`, `CHEST_OF_UPPER_ARM`), `spike/shoulders-2/REPORT.md` and `ansur-fit.ts` (biacromial and bideltoid against chest breadth), `scripts/easing-overlay.ts` (`--reference easing-shoulders`), `scripts/shoulder-overhang.ts`, `.ws-evidence`-style tables from the last run in `runs/`-kept evidence if present under `docs/`, and the 512-corner tests in `test/body/`.

### Measure first
1. For every named build: bideltoid and biacromial against chest breadth as they are now, against the ANSUR population's ratio at that chest breadth (median and the P5–P95 band). Say for each build how far outside the band it is, in cm per side. This sets how far each build's shoulders should come in; the medium stays where the art put it.
2. For each wide build, the two ways the arm can come in: (a) the acromion moves in and the arm still hangs from the armpit, which narrows the armpit opening; (b) the acromion moves in and the arm hangs partly over the torso's side, the armpit staying where it is. Render both on broad and round, bare and dressed, with the near-shoulder close-ups, and measure the overhang, the armpit gap and the overlay distances against easing-shoulders for each. Put both in the evidence before choosing.

### The rule
3. Choose by the measurements (say which and why), then build it: the acromion and the deltoid widths on every build come from the chest breadth by the ANSUR relation around the medium, within the band from 1; the arm's hang follows the chosen way; the armpit rule (no gap) and the no-spike torso hold; the cap keeps its roundness band; the overhang bound from the last task holds or tightens (state the new value).
4. Garments and posed figures follow: the shoulder-arc frame, the imported garments' fit (0.5 cm deviation bound stays), layering, every pose. Re-import `assets/garments/*.json`, re-pin after looking, `npm run renders:approve`.
5. Tests: the ratio band on the named builds; the chosen hang's rule over all 512 corners; the medium's overlay test unchanged; easing-shoulders distances on broad, round, slim and tallest re-pinned with reasons.

### Evidence
`.ws-evidence/page/index.html` with every image path relative to that page (the last page's images sat one folder up and did not load when the page was served alone): at the top, broad and round over easing-shoulders before, way (a), way (b) and the chosen result, dressed and bare, with the measurements; then the lineup bare and dressed; then the 3× near-shoulder close-ups on broad, round, slim and tallest. A person judges it before the merge.

### Prior art
Nothing outside the repo: the project's own skeleton and the tooling from the last three tasks. No second rendering or measuring path.

### Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts [args]`, `npm run renders:sheets`, `npm run renders:approve`, `node`, `cp`. No `env VAR=…` prefix, `git -C`, `git archive`, `tar`, `git stash`, `git checkout` or `git restore`; do not `ls` or `cp` outside the worktree. Do not run `npm install`. Hold one raster at a time; run long render jobs in the foreground, split if needed.

### Done when
Every named build's shoulder widths sit inside the population band for its chest, the wide builds visibly narrower at the shoulder than before, the two hangs measured and one chosen with the reason, the assets re-imported and goldens re-approved, `npx jest --runInBand` over the whole `test/` directory (in parts) and tsc pass, and the evidence page laid out as above with all images loading from it.

### Carried from the fw-accept-candidates review and run (suggestions; do them where the code is yours to touch)
- `assets/garments/README.md:8`: Says the asset format is version 2 and the reader refuses a version 1 asset; src/garments/import/asset.ts has ASSET_VERSION = 3 and refuses anything older. Pre-existing, but the branch edited this file and the line is wrong (rule 3).
- `assets/garments/README.md:52`: The metadata section lists the fields the importer accepts but not the new optional `source` string that parseMetadata now reads and writes through to the asset; an illustrator reading this would not know it exists.
- `assets/garments/README.md:6`: Names `candidates/` as the place the garments were accepted from, and docs/found-art.md line 4 says an import is a candidate in `assets/garments/candidates/`, but the directory is absent at this commit (the batch removes it when nothing waits). Say the batch creates it when an import is waiting, so a reader does not look for a missing directory (rule 4).
- `test/garment-import/seam-leaks.test.ts:19`: The first evidence run found the script-drawn zip jacket showing 112 pixels through its seams on the broad body, and the test was then scoped to found-art garments with the reason stated. That leak is real and now unguarded; worth its own task rather than leaving it only in a test comment.
- Carried twice now, do here: move `bideltoidOf`, `posedBideltoidOf` and `capRadius` out of `test/body/shoulder-measures.ts` into `scripts/` or `src/body`; strengthen `test/body/easing-shoulders.test.ts`'s 'is easing-2 as registered on the medium' (assert across and up equal the registration's, lift 0); a line in the chest slider's `SLIDER_ENDS` text about the dead zone under the `CHEST_OF_UPPER_ARM` floor.
- The script-drawn zip jacket shows 112 pixels through its seams on the broad body (bound 50); the seam test was scoped to found art. Bring the drawn garments back under it and fix the leak if the shoulder change here does not.
