# Fix round 1 for `task-fw-warmers.md`

Track: light
Resume: the worktree holds the group as built and reviewed. Continue from it; commit each fix as soon as its test passes.

## From the look at the render sheet
- Knee warmers are drawn like knee-length shorts from the hips, and leg warmers like full trousers from the hips. Each must be a tube on the leg only: knee warmers from mid-thigh to mid-shin over the knee, leg warmers from mid-thigh to the ankle, with a gripper band at the top, and nothing on the hips or pelvis.
- In the outfits, the shorts (or bib shorts) must show above the knee or leg warmers, with the warmer's top band over the shorts' leg end.
- Arm warmers read right; keep them.

## From the review (blocking)
- src/garments/fit.ts:478 (rule 2): The top band is drawn from `from`, which for a far sleeve's front part is the cut point, not the piece's top: posed.ts:158 fits that part with the piece unchanged and `from: Math.max(span.from, frontFrom)`, with flatStart true. With FAR_FOREARM 'behind', frontFrom is at or below the elbow and non-null on round, pear and short and round, so ARM_WARMERS (from upperArm 0.2) is always split there and the front part draws a 2 cm 'arm-warmers-trim' band and a cross line on the far forearm where it comes out past the belly, painted over the torso by farFrontSvg. The behind part already keeps the real band, so this is a duplicate at the wrong place. The only test of the engine addition (validate.test.ts 'accepts a band at the top of a tube on a limb, and draws it') runs the straight fitGarment, not the posed path, so the done-when's 'any engine addition has its own unit tests' is met for half the path. Fix: guard the top band with `!flatStart` in fitTube (the end band's analogue is `end: undefined` on the behind part at posed.ts:157), and add a dressPosed test on a round body in EASING_POSE asserting the far-front group of ARM_WARMERS has no bands.

Redraw the sheet once at the end (`npm run renders:sheets -- warmers`) and copy it to `.ws-evidence/sheets/warmers.png`. Look at it whole. Keep the spec pending (no goldens): the look comes first.

## Commands
`npx jest *`, `npx tsc *`, `npx tsx *`, `npm test`, `npm run typecheck`, `npm run renders:sheets *`, `npm run scorecard`, `node *`, `git add`, `git commit`, `grep *`, `cp *`, `mkdir *`. One command per Bash call. Run jest on the files you touch (`npx jest test/garments`), not the whole suite, until the end. No installs.

Never run `npm run renders:approve` or `npm run scorecard:approve`.
## Leave alone
`src/body/`, `src/colorwright/`, `src/ink/`, `test/renders/golden/`, `docs/renders/`, `package.json`, `assets/`, `src/garments/shells.ts`.

## Done when
- Each item above reads as described on the new sheet, with a test for each that fails without its fix.
- `npx jest test/garments test/renders`, `npm run typecheck` and `npm run scorecard` pass with no approved sheet changed and no new fault.
