# rpbostick.github.io: the easing lineup in the hero, and a "How it's made" section of process art

Track: light

Patrick: "let's pick some better avatars for the Hero portion ... use some of the newer art" and "i do like the process art ... with the vectors and measurements and comparisons as well. that's cool stuff."

The orchestrator has already committed the source images on this branch, `agent/site-controls` (builders cannot copy from another repo): `public/figurewright/splash-easing.svg` (five figures in the easing pose, transparent) and raw PNGs under `public/figurewright/process-src/`. Check `git log` for that commit.

## Build
1. **Hero**: use `splash-easing.svg` instead of `splash.svg` (read its `viewBox` for the width/height attributes); delete `public/figurewright/splash.svg` and any reference to it. Recheck that the bottom strip clears the figures' shoes and that the translucent panel still fits the new lineup's shape.
2. **"How it's made" section** on `/figurewright/`, after the existing showcase sections (or merge the old sections into it if that reads better; say which). Convert each PNG in `process-src/` to WebP under 400 KB into `public/figurewright/process/` with `npx --yes sharp-cli` (keep the aspect ratio; wide sheets may be ~2400 px wide), then **delete `process-src/`** so raw PNGs don't ship. Chapters, each with a heading, one or two sentences, and its images (click to open full size in a new tab):
   - **Measuring Open Peeps**: `proportions.png` (landmarks and proportion lines on the nine Open Peeps figures and our average body), `contours.png` (traced Open Peeps outlines over our generated profiles).
   - **Real bodies**: `human-vs-peeps.png` (openly licensed photos traced to numbers, grey, against Open Peeps, colour, and the revised profiles, black; say no photos are stored), `builds.png` (seven builds from slim to short-and-round next to two Open Peeps figures).
   - **Sliders**: `proposed-sliders.png` (every slider at −1, 0, +1).
   - **Rigging a pose**: `rig.png` (fifteen joints read off the easing drawing), `posed-vs-original.png` (already in the page; move it here).
   - **Ink and layers**: `ink-closeup.png` (variable-width ink next to an original head), `layering.png` (garments layered and fitted).
   Keep captions factual (what the image shows); a sentence of process voice is fine ("we measured…"). Credit Open Peeps (CC0) as the footer does. Images `loading="lazy"`, with width/height.
4. Hint: add " · drag to reshape the waves" to the active desktop hint (and any matching wording elsewhere), so the drag is discoverable.
3. Dark theme: these renders are drawn on white; show them on a light card with a thin border in both themes so they don't glare or vanish.

## Check
`npm run build` and `npm run lint` pass; serve with `npx vite preview --host 127.0.0.1 --port 8791 --strictPort` and `curl` the page, `splash-easing.svg` and every process image (200, right content types; `splash.svg` and `process-src/` gone).

## Commands
One command per Bash call. `npm run build`, `npm run lint`, `npx vite preview ...`, `npx --yes sharp-cli ...`, `git rm ...`, `curl ...`, `node ...`. Do not run `npm install`.

## Done when
The hero shows the easing lineup; the "How it's made" section shows the ten process images as WebP with captions; no raw PNGs or the old splash ship; build and lint pass.
