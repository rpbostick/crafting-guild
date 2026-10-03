# figurewright hero: the whole pattern follows a drag a little, like a bedsheet on water

Track: light

**Resume:** an earlier run of this task was stopped to change the release behaviour (below). Start with `git log` and `git status`, keep what fits the new spec.

Continue on this branch (local ripple-stretch and swirl via `src/shared/rippleField.ts`, momentum via `src/shared/momentum.ts`, pattern drift and tag click in `patternDrive.ts`). Feedback: it looks great; add a gentle **global** follow so dragging feels like moving a bedsheet that is also a wave on water.

## Behaviour
- While dragging, the whole wave field is displaced a fraction of the drag (start around 15% of the pointer's offset from the press point, capped at about 6% of the hero's size), through a **soft spring with damping**, so it lags behind the pointer and overshoots slightly.
- The global shift is not uniform: it is strongest near the pointer and weaker far away (e.g. a broad falloff over the whole hero, so the far edge moves maybe a third as much), which reads as cloth being pulled rather than a picture sliding.
- **On release, the sheet keeps its momentum; it does not spring back.** The part under the pointer lets go, but the whole field carries the velocity it had at release (and any rotation/swirl it had) and keeps travelling in that direction together, decelerating with friction (the same exponential decay as `momentum.ts`), over roughly 1–3 s depending on how fast it was moving. When it has slowed down, the field simply continues its own drifting pattern from wherever it ended up: the displacement is absorbed into the pattern's phase (or relaxes very slowly, over several seconds, with no visible snap or wobble back). The local ripple and swirl decay on top as now.
- A new press during that glide takes over smoothly.
- Edges never show gaps: extend the line field beyond the visible area or clamp the shift so lines always fill the hero.
- Reduced motion: no global follow.
- Named constants (follow fraction, cap, stiffness, damping, falloff) in one place with comments.

## Tests
Checks for the global follow: a held drag converges to the follow fraction of the offset (capped); falloff makes the far edge move less; on release the field keeps moving along the release velocity and decelerates, with no spring back toward the press point (the offset at release does not decrease in the first half second); it then continues its own pattern without a jump; framerate independence; reduced motion off. `npm run build` and `npm run lint` pass.

## Commands
`npm run build`, `npm run lint`, `node <script>` / `npx <tool>`, `git add`, `git commit`. One command per Bash call.

## Done when
Dragging pulls the whole field a little with a springy, cloth-like lag, and on release the sheet glides on in the drag's direction, slows and resumes its own pattern without springing back, on top of the local ripple and swirl, and the checks, build and lint pass.
