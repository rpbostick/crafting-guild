# rpbostick.github.io: plan

**In flight right now**
`site-fw` (step 1, `task-site-1-figurewright.md`) dispatched 2026-09-28 from the bike-weather session (use `--project rpbostick-github-io`): Pages deploy Action, card index at `/`, figurewright landing page at `/figurewright/` with React Bits Waves. When it finishes: review, preview on :8803 for Patrick, merge (the push deploys to https://rpbostick.github.io/).

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
