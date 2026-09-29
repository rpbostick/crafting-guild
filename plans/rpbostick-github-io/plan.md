# rpbostick.github.io: plan

**In flight right now**
Live: one fresh audited commit 3eee33d (2026-09-28, history replaced after the release audit found colorwright journey comments; the old history is kept locally only as branch `backup-before-fresh-history`, never push it). All three demos, card thumbnails, THIRD_PARTY_LICENSES. Every change to this public repo follows `release-audit.md`. Carried: Actions Node 24 bump when released.
**Theme switch + backdrops on the demos: last round, then publish.** cw-site-links (colorwright dd667c9), sky-site-links (skywright a76b197) and fw-splash-src (figurewright 9bc7e8f) merged 2026-09-29. Their rebuilt demos and the new splash are committed on `agent/site-backdrops` (9bf3ac0). Running since 13:46 MDT: `site-backdrops` fix round (`task-site-7-fix-1.md`, light): no floating credit, American English, `--text-faint` gated, reduced-motion opt-in kept, card re-rendered. Local site `main` is still ahead of origin with abe747c and 665bf6f, **not pushed**. Patrick (2026-09-29): after this round, stop polishing the demos, publish, and go back to Bike Weather.
Then review, `release-audit.md` with findings shown to Patrick, merge (which pushes).

## Requirements (Patrick, 2026-09-28)
- Live, somewhat interactive demos of colorwright, figurewright, skywright and later projects, for a job-building class (Multiverse, run by Lizthedeveloper).
- One public GitHub user site, `rpbostick/rpbostick.github.io`, served at https://rpbostick.github.io/; built output only; source repos stay private. Free GitHub Pages, deployed by GitHub Actions.
- Vite + React + TypeScript, so reactbits.dev animated components can be used (MIT + Commons Clause: fine in a website; never copied into the MIT libraries).
- A simple card index at `/`; one landing page per project at `/<project>/`.

## Steps
1. **Deploy + index + figurewright landing** (`task-site-1-figurewright.md`): the Pages Action, a multi-page Vite build, the index, `/figurewright/` with Waves.
2. **skywright demo**: the Expo web export of `example/` under `/skywright/` (after sky-demo merges), with the Open-Meteo credit.
3. **colorwright static mode**: in the colorwright repo, a no-backend mode (catalog from `manifest.json`, looks in localStorage); its build under `/colorwright/`.
4. **figurewright live demo**: once figurewright's compose (step 7) lands, a live figure with sliders on `/figurewright/`.

## Decisions
- 2026-09-29 (Patrick): demo backdrops from React Bits: **Iridescence** behind colorwright, **Aurora** behind skywright. On skywright, **sun / rain / snow** buttons near the theme switch put the aurora into a sunny / rainy / snowy colour and intensity for about 20 s, then it resumes its default: slowly transitioning between those three feels. Panels stay opaque, but the backdrop **shows about 1 cm into each panel's edge** through a slightly translucent band. **Every demo, figurewright included, gets an "animations off" button** (CPU and battery).
- 2026-09-29 (Patrick): every demo has a link back to the site's main page at the bottom (colorwright was missing one). The figurewright hero lineup: pink Mohawk on pointing_finger, blue hair with a black outline on the red-shirt figure; the same picture on the index card and the demo page.
- 2026-09-29 (Patrick, on the site preview): the backdrops and controls look good. The React Bits credit is static near the other credits (it doesn't need to float). Visible text is in **American English** (license, color). Links between the demos and the index are relative, so a local preview stays local. The builder's four recommendations are accepted.
- Orchestrator design, not asked: the site draws one control cluster at the top right of each demo page (theme, animations, and weather on skywright) in the figurewright switch's pill style. The backdrops are site code, never in the MIT demo repos (React Bits is MIT + Commons Clause). The demos get a web "host mode": under `<html data-host-controls>` they hide their own switch and follow `data-theme` live; under `data-host-backdrop` the page background is transparent and panels get the translucent edge. Animations: localStorage key `motion` (`off` or absent); defaults to off under `prefers-reduced-motion`; off shows a still frame.
- 2026-09-28: user site (option 2) over a `demos` repo; colorwright gets a static mode, not a hosted backend; simple card index; work starts now alongside fw-refs; figurewright landing page uses React Bits Waves (Patrick).
- 2026-09-28 (Patrick): middle-click toggles colour mode and page scroll; dragging morphs the wave pattern, accelerating with speed; a theme switch (System default; black background wanted if only one); orchestrator picked the preset loop and drag axes.
- 2026-09-28 (Patrick): the hero uses the easing-pose lineup; the process art (measurements, traces, rig, sliders) goes on the page as "How it's made".
- 2026-09-28, on the preview (Patrick): the hero is a toy: Waves ripples on the mouse; colours drift slowly on their own; click into the hero and the wheel steps forward/back through 12 hue families (every 30°) × 6 shades A (tint) to F (shade); drift resumes 8 s after the last tick; a lineup of five figures in front, opaque, with a slightly transparent surround. Serpentine order through the stops is the orchestrator's call (no lightness jumps).
