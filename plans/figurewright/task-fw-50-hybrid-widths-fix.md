# figurewright: correct the stated reason for the library bodies' source, and tidy what the review found

Track: light

A review of this branch found the points below. The choice of source stands; what is wrong is the reason written for it. Fix every point under "Must fix". Fix those under "Also" unless one is wrong, and say so in the result if it is. No rendered figure, golden, sheet or baseline changes in this round: if a fix would change one, stop and report it.

## Must fix
- `README.md` line 60: "They draw the fewest of the scorecard's faults in easing over the nine builds: 44, against 45 for the base outlines read under either style transform" does not match the committed code. The documented `--source proportions|slimming --report` gives 44 for both outline sources, with armLength clamped on 8 builds (.ws-evidence/candidates-final-strict.log, candidates/strict/proportions-present.json). The 45 is from candidates-final-open.log, run with the arm's share-of-height rule opened, which is not in the branch. Fix: state the real discriminator (the outline sources take armLength under 0.28 of height on 8 of 9 builds, so the write fails; clamped they tie at 44), or say the 45 is with that rule opened.

- `scripts/library-bodies.ts` line 42: The CHOSEN comment makes the same claim ("the stored widths draw the fewest of the scorecard's faults ... (44, against 45 for either outline source)"). Under the rules this file enforces, the outline sources score 44 clamped and fail the write on 8 builds. Correct it together with the README bullet.

## Also
- `README.md` line 62: "`-- --source proportions|slimming` ... pick another candidate" reads as if the write works. Without `--report` both outline sources throw "fields outside validateBody's rules" (armLength on 8 builds). Any successful non-CHOSEN write also makes the suite's regeneration test fail until CHOSEN changes. Say both; the script header already says the first.
- `src/body/measurements.ts` line 331: The wrist-range comment names shortest and short and round as the bodies under the old 4.0 cm floor. Athletic / broad's field (3.999) is under it too. The block comment above MEASUREMENT_RANGES still says the ranges hold the slider corners and spike bodies only, and the trailing "0.67–1.31; 5–7" does not mention the library's 3.3–4.8.
- `src/body/measurements.ts` line 335: The wrist floor drops from 4.0 to 3.0 cm for every body, not only library ones, so validateBody now admits a slider or stored body with a 3 cm wrist. If that is not wanted, keep the old floor unless limbJoints is set; otherwise add "Deliberate:" with the reason.
- `src/body/skeleton.ts` line 237: "The widest the knee is drawn, as a share of the calf" is no longer true for bodies with limbJoints set. Qualify it ("on a body without limbJoints").
- `scripts/library-bodies.ts` line 148: Rule 9: single-letter names `m` (in `inside`) and `c` (clamp lambdas), and `s` in scripts/drawn-widths.ts:39. Use `clamped`, `clamp`, `share`.
- `test/body/library-bodies.test.ts` line 93: The render check is a smoke test (length > 1000, no NaN, contains 'tee-main'). Only the three pinned goldens per row hold the look, so six of nine bodies per row are unpinned. Acceptable given the sheet's diagonal convention, but worth knowing.
- `scripts/library-bodies.ts` line 36: Rule 15: the source and joint-rule comparison (44/47, the garment table) ran only through scratch scripts in .ws-evidence/scratch. If the choice is to be revisited, a committed all-candidates summary mode would make the README's numbers reproducible.
- For the wrist floor: keep the old 4.0 cm floor for every body without `limbJoints`, and admit the lower floor only for a body that sets it, with a test for each side; the promise of this step is that bodies drawn before it are held to the rules they had.
- The evidence page's first line (`.ws-evidence/page/index.html`) repeats the 44-against-45 reason: correct it there too, since a person reads that page before the merge.

## Commands
One command per Bash call, each check you cite through the evidence runner: `npx tsx <file>.ts [args]`, `npx jest <paths> --runInBand`, `npx tsc --noEmit`, `npm run <script>`, `git status`, `git diff`, `git log`, `git add`, `git commit`, `grep`, `ls`, `cat`. No installs. Run `test/body` in parts so no call passes 10 minutes.

## Done when
Each point is fixed or answered in the result; `npx tsc --noEmit` and the tests covering the files touched pass (`test/body`, `test/body-library`, `test/renders`); `git diff --stat main -- test/renders/golden docs/renders` lists only the library-builds sheet's files, as before this round; and the result gives the corrected sentence for the choice of source exactly as the README now has it, and the number of tests with the log each count comes from. Safe to re-run.
