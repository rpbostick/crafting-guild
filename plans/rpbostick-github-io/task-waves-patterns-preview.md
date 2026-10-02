# figurewright: a preview page showing the six wave patterns side by side

Track: light

Continue on this branch. The hero's waves have six named patterns (`PRESETS` in `src/figurewright/patternDrive.ts`: Swell, Choppy, Rollers, Ripple, Crosswind, Storm). Since drags became local ripples and swirls, nothing switches between them. Before deciding what to do with them, the patterns need to be seen together.

## Behaviour
- A dev preview page, `dev/wave-patterns.html` (with its own small `src/dev/wavePatterns.tsx` entry), showing **six panels at once**, each a `Waves` instance locked to one preset (its motion and look exactly as the hero would show that preset, with the hero's colours and background in the current theme), labelled with the preset's name.
- Each panel supports the new drag ripple-and-swirl and momentum, so they can be compared under the same interaction.
- A seventh panel shows the hero's eased morph cycling slowly through all six (as a "drift" option would), with the current name shown.
- Light/dark follows the site theme switch.
- The page is served by `npm run dev` and by the preview (`npx vite preview` after `npm run build`), but is **not linked** from the site and not listed in the README's page table. Add it to the Vite build inputs only if needed for the preview, and say so.

## Prior art
The hero's own Waves wiring; no library.

## Tests
`npm run build` and `npm run lint` pass; the page builds.

## Commands
`npm run build`, `npm run lint`, `node <script>` / `npx <tool>`, `git add`, `git commit`. One command per Bash call.

## Done when
`/dev/wave-patterns.html` shows the six presets side by side plus a drifting seventh panel, each draggable with ripple, swirl and momentum, and build and lint pass.
