# rpbostick.github.io: Pages deploy, card index, and a figurewright landing page with React Bits Waves

This repo is Patrick Bostick's public demo site, served by GitHub Pages at https://rpbostick.github.io/ (a user site, so the base path is `/`). It is a fresh `create-vite` React + TypeScript scaffold with dependencies installed. It will hold live demos of his projects (colorwright, figurewright, skywright, more later) for a job-building class. Everything in this repo is public.

## Build
1. **Multi-page Vite build.** `index.html` at the root is the index; `figurewright/index.html` is the figurewright page (so the URL is `/figurewright/`). Configure `build.rollupOptions.input` in `vite.config.ts`. Each page has its own entry under `src/` (for example `src/index/main.tsx`, `src/figurewright/main.tsx`); shared bits under `src/shared/`. Remove the scaffold's demo counter, logos and CSS.
2. **Deploy Action**: `.github/workflows/deploy.yml`: on push to `main` (and `workflow_dispatch`): checkout, setup-node 24 with npm cache, `npm ci`, `npm run build`, `actions/upload-pages-artifact` of `dist/`, `actions/deploy-pages`. Permissions `pages: write`, `id-token: write`, `contents: read`; a `pages` concurrency group. Pages is already set to deploy from Actions. You cannot run the Action; check the YAML by reading it carefully against GitHub's documented starter workflow for static sites.
3. **React Bits Waves**: copy the TypeScript + CSS variant from https://github.com/DavidHDev/react-bits (`src/ts-default/Backgrounds/Waves/Waves.tsx` and `Waves.css`; fetch the raw files with `curl -L -o <path> https://raw.githubusercontent.com/DavidHDev/react-bits/main/<path>`) into `src/reactbits/Waves/`. Keep it unchanged except for what lint or strict TypeScript requires (say what you changed). Add `src/reactbits/LICENSE.md` with React Bits' licence text (fetch `LICENSE.md` from the same repo) and a line naming which components are copied. It needs no npm packages.
4. **Index page (`/`)**: Patrick's name, one line ("Live demos of things I'm building"), and a card per project: figurewright (linked, live), skywright and colorwright ("coming soon", not linked). A card has a title, a one-line description and, for figurewright, an image. Plain and clean, responsive to phone width, light and dark via `prefers-color-scheme`.
5. **figurewright page (`/figurewright/`)**:
   - Hero: full-viewport **Waves** background (it follows the cursor), the name **figurewright**, the tagline "Build an avatar that looks like you: body shapes, swappable heads, and layered garments that fit every body.", and a status line "In development. Open-source (MIT) release coming."
   - The look should suit the art: Open Peeps is black hand-drawn ink with flat colour fills. Choose Waves' `lineColor` and background to sit behind that (for example soft ink-grey lines on a warm off-white, and a dark variant for dark mode); make the hero text readable over the lines.
   - Below the hero, sections with images, each with a short caption: **Body shapes** (`spike/renders/shapes.png`), **Garments that fit every body** (`docs/renders/garments.png`), **A natural pose** (`spike/easing/renders/posed-vs-original.png`: say it's the pose in development, next to the original drawing it's rigged from), **Hands and shoes** (`assets/extremities/contact.png`). Copy them from `/home/patrickb/figurewright/` (read-only for you; do not change anything there) into `public/figurewright/`. Convert each to WebP under 400 KB with `npx --yes sharp-cli` (or keep PNG if that tool is not available, and say so); keep the originals out of the repo.
   - A credits footer: "Head, hand and shoe art from Open Peeps by Pablo Stanley (CC0). figurewright is unofficial and not affiliated with Open Peeps." and "Background animation: React Bits (reactbits.dev)." Link back to the index.
   - Respect `prefers-reduced-motion`: render Waves still (or not at all) when it is set.
6. `README.md`: update the page list and the React Bits note if needed.

## Check
- `npm run build` and `npm run lint` pass (this is the merge gate).
- Serve the build with `npx vite preview --host 127.0.0.1 --port 8791 --strictPort` in the foreground-safe way you have (start it, check, stop it), and fetch `/` and `/figurewright/` with `curl` to check both return the page and every image path in them returns 200. If you have a headless browser available through npx, save screenshots of both pages (desktop and phone width) under `.ws-evidence/`; if not, say so.
- No file outside this repo changes.

## Commands
One command per Bash call. `npm run build`, `npm run lint`, `npx vite preview ...`, `npx --yes sharp-cli ...`, `curl ...`, `node ...`, `cp` is not granted: copy images with `node -e "require('fs').copyFileSync(a,b)"` or via sharp-cli's output. Do not run `npm install` (ask in open_questions if a package is needed).

## Done when
`/` and `/figurewright/` build and serve with every image; Waves animates behind the figurewright hero; the deploy workflow is committed; build and lint pass.
