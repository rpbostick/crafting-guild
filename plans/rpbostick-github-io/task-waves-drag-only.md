# figurewright hero: the waves react only while dragged on bare background

Track: light

On the figurewright page, the hero's Waves background (`src/reactbits/Waves/Waves.tsx`, wired in `src/figurewright/Hero.tsx`, `heroInput.ts`, `patternDrive.ts`, `figurewright.css`) ripples under the cursor whenever the mouse moves over the hero, because Waves listens to `mousemove`/`touchmove` on its container (see `src/reactbits/LICENSE.md`, change 3). A left-drag on the hero already morphs the pattern and shows `cursor: grabbing`. Make the waves react to the pointer only during such a drag, and only on bare hero background.

## Behaviour
- Hover with no button pressed: the waves do not follow the pointer.
- A left-button (or touch) press **on bare hero background** (not on the hero's text, buttons, tag, the strip at the bottom, or any element marked `data-solid`) starts a drag: while held, the waves follow the pointer (as the hover did before) and the existing pattern morph continues; the cursor is `grabbing` until release. Hovering bare hero background shows `cursor: grab`.
- On release or cancel, the waves get their pointer-left state and settle.
- Middle-click colour mode and wheel stepping behave as now.
- Implement it in Waves with the smallest change: a prop that turns off Waves' own `mousemove`/`touchmove` listeners and a per-frame pointer getter (in the style of the existing `motion` and `lineColor` getter props), fed by Hero's drag handling. Record the change in `src/reactbits/LICENSE.md` as a numbered change under Waves, as the existing ones are.

## Tests
The repo's test gate is `npm run build && npm run lint`; keep both passing. If the repo has check scripts for the hero input rules (`heroInput.ts` is written as pure functions for a check script), extend them: hover feeds no pointer, a drag that starts on bare background does, one that starts on content does not, release settles.

## Commands
`npm run build`, `npm run lint`, `node <script>` / `npx <tool>` for any existing check scripts, `git add`, `git commit`. One command per Bash call.

## Done when
The figurewright waves follow the pointer only during a left-drag that starts on bare hero background, with grab/grabbing cursors, the change is recorded in the React Bits change list, and build and lint pass.
