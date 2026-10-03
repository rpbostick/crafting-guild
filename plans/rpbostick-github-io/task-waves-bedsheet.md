# figurewright hero: the whole pattern follows a drag a little, like a bedsheet on water

Track: light

Continue on this branch (local ripple-stretch and swirl via `src/shared/rippleField.ts`, momentum via `src/shared/momentum.ts`, pattern drift and tag click in `patternDrive.ts`). Feedback: it looks great; add a gentle **global** follow so dragging feels like moving a bedsheet that is also a wave on water.

## Behaviour
- While dragging, the whole wave field is displaced a fraction of the drag (start around 15% of the pointer's offset from the press point, capped at about 6% of the hero's size), through a **soft spring with damping**, so it lags behind the pointer and overshoots slightly.
- The global shift is not uniform: it is strongest near the pointer and weaker far away (e.g. a broad falloff over the whole hero, so the far edge moves maybe a third as much), which reads as cloth being pulled rather than a picture sliding.
- On release (and during momentum's coast), the spring pulls the field back to rest with a gentle wobble that settles within ~1.5 s; the local ripple and swirl keep working on top.
- Edges never show gaps: extend the line field beyond the visible area or clamp the shift so lines always fill the hero.
- Reduced motion: no global follow.
- Named constants (follow fraction, cap, stiffness, damping, falloff) in one place with comments.

## Tests
Checks for the global follow: a held drag converges to the follow fraction of the offset (capped); falloff makes the far edge move less; release returns to rest and settles within the time limit; framerate independence; reduced motion off. `npm run build` and `npm run lint` pass.

## Commands
`npm run build`, `npm run lint`, `node <script>` / `npx <tool>`, `git add`, `git commit`. One command per Bash call.

## Done when
Dragging pulls the whole field a little with a springy, cloth-like lag and settles back on release, on top of the local ripple and swirl, and the checks, build and lint pass.
