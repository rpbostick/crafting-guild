# rpbostick.github.io: plan

**In flight right now**
`site-fw` round 2 (`task-site-2-waves-colour.md`, $12) dispatched 2026-09-28 11:35 MDT on the same branch: 72-stop OKLCH palette (12 hue families × A–F, serpentine), drift + click-to-activate wheel stepping, colour tag, splash lineup (`figurewright/docs/renders/splash.svg`, merged as 2a3f8ce) over a translucent panel, and the round-1 review's suggestions. Round 1 was reviewed **merge** at 5ef1b00; re-review after round 2. Preview on :8803 (`ws serve site-fw 8803`, already running). Queued after round 2: `task-site-3-scroll-strip.md` (a bottom strip where the wheel scrolls normally; Patrick). Then review, Patrick looks, merge, the push deploys.

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
- 2026-09-28, on the preview (Patrick): the hero is a toy: Waves ripples on the mouse; colours drift slowly on their own; click into the hero and the wheel steps forward/back through 12 hue families (every 30°) × 6 shades A (tint) to F (shade); drift resumes 8 s after the last tick; a lineup of five figures in front, opaque, with a slightly transparent surround. Serpentine order through the stops is the orchestrator's call (no lightness jumps).
