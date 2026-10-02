# figurewright hero: patterns drift on their own, and the tag click moves to the next

Track: light

Continue on this branch. Decision after viewing the six presets side by side (`dev/wave-patterns.html`): the hero should do both of these.

## Behaviour
- **Slow drift:** the hero's waves cycle through the six presets by themselves, easing from one to the next (as the preview's seventh panel does): hold each pattern for a while (about 20–30 s) and ease over a few seconds; the pattern tag shows the current name (and "A → B" while easing, as `patternLabel` already does).
- **Click the tag (or arrows beside it) to change:** clicking the tag eases to the next preset right away (a left arrow goes back); the drift then holds that pattern for its full hold time before moving on. Keyboard: the tag and arrows are buttons with labels; Enter/Space work.
- Drags stay local ripples and swirls with momentum; they don't change the pattern.
- Reduced motion: no drift (the tag click still changes pattern, with a short or instant transition).
- The hold and ease times are named constants.
- **The dev preview page stays out of the production site:** `dev/wave-patterns.html` and `src/dev/` must not be in the build output deployed to Pages (serve it only from `npm run dev`; if it was added to the Vite build inputs, remove it from the production inputs). Say how to open it.

## Tests
Extend the pattern/hero checks: drift advances after the hold time and wraps; a tag click advances immediately and resets the hold; the back arrow goes back; reduced motion disables drift; the production build has no `dev/` page. `npm run build` and `npm run lint` pass.

## Commands
`npm run build`, `npm run lint`, `node <script>` / `npx <tool>`, `git add`, `git commit`. One command per Bash call.

## Done when
The hero drifts through the six patterns on its own, the tag and arrows change pattern on click, drags stay local, the dev page is not deployed, and the checks, build and lint pass.
