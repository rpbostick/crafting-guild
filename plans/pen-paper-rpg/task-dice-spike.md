# Spike: four dice rollers, side by side, with their customization options

A comparison page for rolling each candidate dice roller and try its options before one is added to the character generator. This is a spike: working demos and a short written comparison, not production code. Everything lives in `spikes/dice/`.

## The four candidates
1. **Fantastic Dice / dice-box**: `@3d-dice/dice-box` (MIT; BabylonJS + AmmoJS physics in a web worker). Its assets (worker, wasm, themes) must be copied into the demo's static folder and pointed to with `assetPath`.
2. **dice-box-threejs**: `@3d-dice/dice-box-threejs` (MIT; Three.js + cannon-es; last release 2022).
3. **Light 2D roller**: `@dice-roller/rpg-dice-roller` (MIT) for the notation and maths, plus our own CSS-animated 2D dice (tumbling d6 faces with pips; a simple shape for other dice), written for this spike.
4. **Owlbear Rodeo dice**: vendored, untracked, at `spikes/dice/vendor/owlbear-dice/` (GPL-3.0; React, Three.js via @react-three/fiber, Rapier physics). Its `src/plugin/` code talks to Owlbear Rodeo through `@owlbear-rodeo/sdk`; the dice, tray and physics should run without it. Build it as a **separate standalone page** (its own Vite build, base path under `spikes/dice/dist/owlbear/`), with the Owlbear-specific parts removed or stubbed, and show it in the comparison page inside an `<iframe>`, talking to the host page only by `postMessage` (the host sends "roll 2d6+1", the dice page answers with the result). Record every change made to its code in `spikes/dice/OWLBEAR-CHANGES.md`. If it cannot be made to run standalone in reasonable time, stop on it, explain what blocks it, and finish the other three.

## The comparison page
`spikes/dice/dist/index.html` (served statically from `spikes/dice/dist/`), one section or tab per roller, the same controls for each:
- Roll buttons for this game's rolls: **2d6 + attribute** (a −1…+3 picker) with the World of Dungeons result band shown (6 or less: miss; 7–9: partial success; 10+: full success; 12+: critical), **d6 damage** (with a +bonus), **hit dice** (Nd6, keep the highest), and a free notation box (e.g. `3d6+1`).
- A **quick roll** toggle: results without animation.
- **Customization** each library actually offers, exposed as controls: dice color/theme, material or texture where available, size/scale, throw force, gravity, sound on/off, tray background, and for the 2D roller the colors, pip style and animation speed. Show what each library cannot do.
- A small results log.
- For each roller, a footer line with its licence, bundle/asset size on disk (measure it), and first-roll load time on this machine.

## Deliverables
- `spikes/dice/dist/` built and committed (except vendor and node_modules), plus the sources and a `spikes/dice/build.sh` (or `package.json` scripts) that rebuilds everything.
- `spikes/dice/COMPARISON.md`: for each roller, what worked, size, load time, look, customization, maintenance status, licence consequences (for Owlbear: what serving it as a separate GPL page requires: its modified source published under GPL-3.0, the iframe boundary), and how it would fit the single-file generator page (inline? separate files on the site?). End with a recommendation.
- Screenshots of each roller mid-roll and at rest under `.ws-evidence/` (headless Firefox has WebGL via software; say if one renders blank there).

## Prior art
These four are the candidates; do not add others. Use each library's own examples and docs (dice-box: fantasticdice.games/docs; dice-box-threejs README; rpg-dice-roller docs).

## Leave alone
Everything outside `spikes/dice/` (the generator in `chargen/` is being changed on another branch).

## Commands
From the worktree root: `npm install --prefix spikes/dice <packages>` (and `--prefix spikes/dice/vendor/owlbear-dice` for that app, `npm install --legacy-peer-deps` if its old peers clash), `npx --prefix spikes/dice <tool>` for vite/esbuild, `node <script>`, `cp` inside the worktree, `bash spikes/dice/build.sh`, `firefox --headless …` for screenshots (absolute paths, one per call), `python3 -m http.server 8795 --bind 127.0.0.1 --directory spikes/dice/dist` (run it in the background only while taking screenshots, then stop it by its PID), `git add`, `git commit`. One command per Bash call.

## Done when
The comparison page rolls with each working roller, with its options exposed and the WoD result bands shown; COMPARISON.md compares them and recommends one; the build is committed and reproducible.
