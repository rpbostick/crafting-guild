# figurewright hero: momentum after a fling

Track: light

The figurewright hero's waves now follow the pointer only during a left/touch drag that starts on bare hero background (Waves' `pointer` getter prop, React Bits change 8 in `src/reactbits/LICENSE.md`; drag handling in `src/figurewright/Hero.tsx`, `heroInput.ts`, `scripts/check-hero-controls.ts`). Add inertia: a quick drag released mid-motion keeps going as if the disturbance had mass.

## Behaviour
- While dragging, keep the last ~100 ms of pointer samples; on release compute the release velocity.
- After release, feed Waves a **coasting virtual pointer** that continues along that velocity and slows with friction (exponential decay, framerate-independent: `v *= exp(-k·dt)`), soft-bouncing off the hero's edges (velocity component reversed with some loss).
- When its speed drops below a threshold, fade the pointer's influence out over ~0.5 s, then send the pointer-left state so the waves resume their own pattern. A fast fling coasts for several seconds; a slow release stops almost at once (no coast below a minimum release speed).
- A new press during the coast takes over immediately. Reduced motion: no coast.
- Constants (friction, minimum speed, maximum coast time ~4 s, bounce loss) in one place, named, with a comment on what each changes.
- The figure pattern morph (`patternDrive`) is unaffected unless it already has its own easing.
- Put the momentum logic in a small pure module (`src/shared/momentum.ts`) with no React, so other pages can reuse it.

## Prior art
Inertial/fling scrolling as in popmotion's `inertia` (MIT): exponential velocity decay with a stopping threshold; implemented here in ~50 lines rather than adding a dependency.

## Tests
Extend `scripts/check-hero-controls.ts` (or add `scripts/check-momentum.ts` run the same way) for the pure module: release velocity from samples; decay over time independent of frame rate; coast time grows with release speed and is capped; edge bounce; a new press cancels the coast; reduced motion disables it. `npm run build` and `npm run lint` pass.

## Commands
`npm run build`, `npm run lint`, `node <script>` / `npx <tool>` for the check scripts, `git add`, `git commit`. One command per Bash call.

## Done when
A fling on the figurewright hero coasts with decaying speed and bounces, fades back into the waves' own motion, the logic is a reusable pure module with checks, and build and lint pass.
