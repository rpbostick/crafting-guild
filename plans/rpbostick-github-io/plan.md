# rpbostick.github.io: plan

**In flight right now**
Live: one fresh audited commit 3eee33d (2026-09-28, history replaced after the release audit found colorwright journey comments; the old history is kept locally only as branch `backup-before-fresh-history`, never push it). All three demos, card thumbnails, THIRD_PARTY_LICENSES. Every change to this public repo follows `release-audit.md`. Carried: Actions Node 24 bump when released.

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
- 2026-09-28: user site (option 2) over a `demos` repo; colorwright gets a static mode, not a hosted backend; simple card index; work starts now alongside fw-refs; figurewright landing page uses React Bits Waves (Patrick).
- 2026-09-28 (Patrick): middle-click toggles colour mode and page scroll; dragging morphs the wave pattern, accelerating with speed; a theme switch (System default; black background wanted if only one); orchestrator picked the preset loop and drag axes.
- 2026-09-28 (Patrick): the hero uses the easing-pose lineup; the process art (measurements, traces, rig, sliders) goes on the page as "How it's made".
- 2026-09-28, on the preview (Patrick): the hero is a toy: Waves ripples on the mouse; colours drift slowly on their own; click into the hero and the wheel steps forward/back through 12 hue families (every 30°) × 6 shades A (tint) to F (shade); drift resumes 8 s after the last tick; a lineup of five figures in front, opaque, with a slightly transparent surround. Serpentine order through the stops is the orchestrator's call (no lightness jumps).
