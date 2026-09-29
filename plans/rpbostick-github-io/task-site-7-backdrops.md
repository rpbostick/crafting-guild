# rpbostick.github.io: demo backdrops, one control cluster, an animations switch, the new hero

Branch from `main`. The orchestrator committed the inputs there (see `git log -3`):
- the rebuilt `public/colorwright/` and `public/skywright/` (each with its own theme switch, a dark theme, a "More demos" link and a **host mode**, described below)
- the new `public/figurewright/splash-easing.svg` (the hero lineup, with new hair on two figures)
- the `ogl` package (Unlicense) in `package.json`

Read `src/shared/theme.ts`, `src/shared/ThemeSwitch.tsx`, `src/shared/themeSwitch.css`, `src/figurewright/Hero.tsx`, `src/reactbits/LICENSE.md`, `vite.config.ts` and `README.md` first.

## Host mode (already in both demos; do not edit files under `public/colorwright/` or `public/skywright/`)
Each demo's `index.html` changes its behaviour when `<html>` carries these attributes before its own scripts run:
- **`data-host-controls`**: the demo hides its own theme switch, leaves a **280 × 64 px** space at the top right, and follows `data-theme` on `<html>` live. The attribute is absent for System, `"light"` or `"dark"` otherwise, with the same `theme` localStorage key the site uses.
- **`data-host-backdrop`**: the page background turns transparent. Panels stay opaque, except for a translucent band about 1 cm wide at their edges.

The site switches both on **at build time**. A small step in the build (a Vite plugin hook or a post-build script run by `npm run build`) rewrites `dist/colorwright/index.html` and `dist/skywright/index.html`. It adds the two attributes to `<html>` and a `<script type="module">` for that page's host bundle, built by Vite as an extra entry. Because the `public/` copies stay untouched, re-copying a demo never loses host mode. Add a check to the build that fails if either file no longer contains a single `<html` tag and a `</head>` to hook into.

## The control cluster (every demo page: `/figurewright/`, `/colorwright/`, `/skywright/`)
One fixed cluster at the top right, at most **280 × 64 px**, in the existing pill style (`themeSwitch.css`):
- **Row 1:** the existing `ThemeSwitch` (System / Light / Dark).
- **Row 2:**
  - An **Animations** toggle, a single button showing "Animations on" or "Animations off" with `aria-pressed`. Store it in localStorage as `motion`: `"off"`, or the key removed for on. With nothing stored, it starts **off** when `prefers-reduced-motion: reduce` is set, and on otherwise.
  - On **skywright only**: **Sun**, **Rain** and **Snow** buttons (icon plus visible text or an `aria-label`, `aria-pressed` on the active one).

Share one module for the `motion` state, shaped like `theme.ts` (a hook plus a setter, try/catch around storage). The index page (`/`) keeps its theme switch only. Put the cluster behind a React root mounted into its own element, so it never touches the demo's DOM.

## Backdrops (React Bits, from https://github.com/DavidHDev/react-bits, `src/ts-default/Backgrounds/<Name>/`)
Fetch `Aurora.tsx`/`Aurora.css` and `Iridescence.tsx`/`Iridescence.css` with `curl -L -o <path> https://raw.githubusercontent.com/DavidHDev/react-bits/main/<path>` into `src/reactbits/Aurora/` and `src/reactbits/Iridescence/`. Keep them unchanged except for what lint, strict TypeScript or these requirements need. List every change in `src/reactbits/LICENSE.md`, as it does for Waves.

- **Behind `/colorwright/`: Iridescence.** Fixed, full viewport, behind everything (`z-index` below the page). Its colours follow the theme.
- **Behind `/skywright/`: Aurora**, with weather "feels" (Patrick):
  - Three presets:
    - **sunny:** warm golds and clear sky blues, bright, calm
    - **rainy:** slate blues and greys, dimmer, more movement
    - **snowy:** icy whites, pale blues and a little lavender, soft and slow
  - Each preset has a light-theme and a dark-theme version.
  - **Default:** the aurora drifts slowly between the three feels. Hold each for about 20 s, and cross-fade over about 8 s by interpolating colour stops (in OKLab or similar, so the mid-points don't go muddy), along with amplitude, blend and speed.
  - **Clicking Sun, Rain or Snow:** the aurora moves to that feel within about 1.5 s and **holds it for about 20 s**, then resumes the default drift from that feel. The pressed button shows as active during the hold. Clicking again during a hold restarts the 20 s.
  - Put the timing and interpolation in a pure module with unit-testable functions: given the time since the last click and the current feel, return the target parameters.
- **Readability wash:** the demos' contrast in the translucent band assumes the backdrop stays near each theme's own background. Render each backdrop under a theme-coloured wash (the theme's `--bg` at a fixed opacity, or the backdrop's own opacity), so its brightest and darkest pixels stay near the theme background. Pick the opacity by computing, for every preset and both themes, the contrast of the demos' muted text over their 70%-opaque surface composited on the washed extreme colours. Every pair must reach 4.5:1. Write this as a script under `scripts/` (like `check-palette.ts`) with an npm script `check:backdrops`.
- **Animations off:** every backdrop stops its animation loop and shows one still frame (the current feel on skywright; Sun, Rain and Snow still change the still frame). figurewright's hero (Waves and the colour drift) stops too. Hook this into whatever the hero already does for `prefers-reduced-motion`, so both paths go through the same `motion` state. Turning animations back on resumes without a reload.
- Pause every loop while the tab is hidden (`visibilitychange`), whatever the setting.

## The new hero picture on the index card too (Patrick: the same picture for both)
`public/figurewright/splash-easing.svg` is the figurewright hero already. Also make it the **figurewright card** on `/`. Render it to `public/figurewright/card.webp` with `npx --yes sharp-cli`, under 150 KB. **Fit the whole lineup** into the card's 16:7 frame with no cropping; all five figures show head to foot, centred on a transparent or card-coloured background, in both themes. Update the card's alt text to describe the lineup.

## Licences
Regenerate `public/THIRD_PARTY_LICENSES.txt` for the site bundle, which now includes `ogl`: `npx --yes license-checker --production --json` into a scratch file under `.ws-evidence/`, then `node scripts/third-party-licenses.mjs site <file>`. Follow README's licences section. The footers credit React Bits for the backdrops ("Background animation: React Bits (reactbits.dev)") on the colorwright and skywright pages too. The site can add a small credit line through the host bundle, placed so it never covers the demo's own footer.

## Check
- `npm run build` and `npm run lint` pass. So do `npm run check:backdrops` and the unit tests for the weather timing and the `motion` state (use `node --test` with `.ts` via `node`, as the existing check scripts do).
- Run `npx vite preview --host 127.0.0.1 --port 8791 --strictPort` (start it, check, stop it). With `curl`, confirm that `/`, `/figurewright/`, `/colorwright/` and `/skywright/` return 200. Confirm the built demo pages carry both host attributes and the host script, and that every script and image they reference returns 200.
- If a headless browser is available through `npx` (for example `npx --yes playwright screenshot`), save screenshots of the three demo pages in light and dark, and of skywright after clicking Rain, to `.ws-evidence/`. If not, say so; the operator will look.
- No personal names, home paths or dated journey comments in anything under `src/`, `scripts/` or the built output (`release-audit.md` runs before anything is pushed).

## Commands
One command per Bash call: `npm run build`, `npm run lint`, `npm run check:*`, `npx vite preview …`, `npx --yes sharp-cli …`, `npx --yes license-checker …`, `npx --yes playwright …`, `curl …`, `node …`. `cp` is not granted: copy with `node -e "require('fs').copyFileSync(a,b)"`. Do not run `npm install`; if you need a package, ask in open_questions.

## Done when
All three demo pages carry the cluster at the top right. Iridescence and Aurora run behind colorwright and skywright under the wash. Sun, Rain and Snow drive the aurora, holding 20 s and then drifting. Animations off stops everything, including figurewright's hero, and is remembered. The new lineup is the figurewright card. The licences are regenerated, and build, lint and the checks pass.
