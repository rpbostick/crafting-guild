# rpbostick.github.io: backdrops fix round (static credits, American English, --text-faint, reduced-motion opt-in)
Track: light

You are on `agent/site-backdrops`, continuing your own branch. The orchestrator has just committed rebuilt demo inputs on it (see `git log -1`):
- `public/colorwright/` and `public/skywright/`: each demo's footer now shows "Background animation: React Bits (reactbits.dev)" itself when `data-host-backdrop` is set. Its "More demos" link is the relative `/`, and its theme label reads "Color theme".
- `public/figurewright/splash-easing.svg`: the hero lineup, now drawn through figurewright's src, which fixes the far-sleeve layering on the red tee and the zip jacket.

Do not edit files under `public/colorwright/` or `public/skywright/`.

## Changes (Patrick, from the preview)
1. **Remove the site's floating React Bits credit** on `/colorwright/` and `/skywright/` (the host bundle's credit line). The demos carry it statically now. Keep figurewright's static credit as it is.
2. **American English** in every piece of visible text the site owns, and in `src/reactbits/LICENSE.md` notes, `README.md`, and the output of `scripts/third-party-licenses.mjs` ("license", "color", "behavior" and so on). "Colour theme" becomes "Color theme" wherever the site says it. Then regenerate `public/THIRD_PARTY_LICENSES.txt` as README's licenses section says. Identifiers you rename must stay consistent; a CSS custom property or a localStorage key visitors already have (`theme`, `motion`) keeps its name.
3. **Gate colorwright's `--text-faint`** (#687079 in light; read the dark value from `public/colorwright/style.css`) in `check:backdrops`, alongside `--text-muted`, at the same 4.5:1 bar. If it fails at the current wash, raise colorwright's wash until it passes and say what you changed.
4. **Keep "on" saved for reduced-motion visitors who opt in** (your open question, accepted as you built it). Make sure the test for it stays.
5. **Card:** re-render `public/figurewright/card.webp` from the new `splash-easing.svg` the same way as before (whole lineup, 16:7, under 150 KB).

## Check
`npm run build`, `npm run lint`, `npm run check:backdrops`, and `node --test scripts/motion.test.ts scripts/weather.test.ts scripts/hostMode.test.ts` pass. `git grep -niE 'colour|licence|behaviour|labelled'` over `src/`, `scripts/`, `README.md` and `public/THIRD_PARTY_LICENSES.txt` finds nothing, except inside third-party license texts that are quoted verbatim (list those). The built `/colorwright/` and `/skywright/` pages no longer contain the host bundle's credit element.

## Commands
One command per Bash call: `npm run build`, `npm run lint`, `npm run check:*`, `node …`, `npx --yes sharp-cli …`, `npx --yes license-checker …`, `git grep …`. `cp` is not granted: copy with `node -e "require('fs').copyFileSync(a,b)"`. Do not run `npm install`.

## Done when
There's no floating credit. The site's text is American English. `--text-faint` is gated and passes. The reduced-motion opt-in is kept. The card shows the new lineup. Build, lint and the checks pass.
