# rpbostick.github.io: card thumbnail fixes (fix round 1 on agent/site-thumbs)

Track: light

Continue branch `agent/site-thumbs`; read your commits and `.ws-evidence/` screenshots first.

1. **skywright card**: the crop cuts through the "Next 24 hours" row (temperatures show only their top halves). Re-crop so no row is cut: either end above that row, or include the whole row. The source screenshot was deleted; recreate it with `npx playwright screenshot --wait-for-timeout 6000 --viewport-size "1280,900" https://rpbostick.github.io/skywright/ .ws-evidence/sky-full.png` and crop from that.
2. **figurewright card**: replace `shapes.webp` (old headless straight-on bodies with heads floating below) with the hero lineup `public/figurewright/splash-easing.svg` (five figures, easing pose). Render it to a WebP card image on a light background matching the other cards (`public/figurewright/card.webp`, under 150 KB, full lineup visible within the card's 16/7 crop, so letterbox it rather than cutting heads or feet). Update the alt text.
3. `public/THIRD_PARTY_LICENSES.txt`: add the Open Peeps art (CC0, Pablo Stanley, https://www.openpeeps.com/) used on /figurewright/ and in colorwright.
4. `scripts/third-party-licenses.mjs`: "1 package" vs "N packages" in group headings and the summary line; regenerate the files.
5. `README.md`: one path for the license-checker JSON in the regeneration steps (match what the script's usage line says).
6. Re-take the four index screenshots (desktop and phone, light and dark) into `.ws-evidence/`.

## Check
`npm run build`, `npm run lint` pass; the screenshots show three cards with no cut-off text or figures.

## Commands
One command per Bash call. `npm run build`, `npm run lint`, `npx vite preview ...`, `npx --yes sharp-cli ...`, `npx playwright screenshot ...`, `node ...`, `git rm ...`, `curl ...`. Do not run `npm install`.
