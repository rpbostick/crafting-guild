# figurewright hero: a local ripple-stretch and swirl instead of moving the whole pattern

Continue on this branch (the hero's waves follow a drag that starts on bare hero background, with momentum after a fling: `src/shared/momentum.ts`, `src/figurewright/Hero.tsx`, `heroInput.ts`, `patternDrive.ts`, `src/reactbits/Waves/Waves.tsx` with its React Bits change list in `src/reactbits/LICENSE.md`, checks in `scripts/check-*.ts`). Feedback after trying it: a grab shakes and moves the **whole** wave pattern. It should instead be a local effect that flows outward, and it should swirl the lines.

## Behaviour
- **No global change on drag:** a drag no longer changes the whole pattern's motion parameters (`patternDrive.grab` or whatever drives the global morph); the waves' own flowing pattern continues everywhere except where the pointer disturbs it.
- **Local ripple-stretch:** points of the wave lines within a radius of the pointer (about 120–180 px, scaled with the hero size) are pulled along by the pointer's motion (displacement proportional to pointer velocity, falling off smoothly with distance, e.g. a Gaussian). The disturbance **propagates fluidly** into the rest of the field: couple each point to its neighbours along its line and to the corresponding points on the adjacent lines with springs and damping (a damped 2D wave / spring-mesh step), so a stretch spreads out as a ripple and fades, rather than the whole field jumping.
- **Swirl:** add a rotational displacement around the pointer (a vortex: tangential displacement falling off with distance), driven by the drag's speed and its turning (the curl of the motion: circling the pointer winds the lines up), which slowly unwinds after release. The lines should visibly twirl near the pointer.
- **Momentum stays:** after a fling, the coasting virtual pointer from `momentum.ts` keeps dragging a fading ripple and swirl through the field; a new press takes over.
- **Stability:** framerate-independent integration, clamped displacements so lines never tangle or explode, settles back to the waves' own pattern within a few seconds of the last disturbance. Reduced motion: no ripple/swirl.
- Tuning constants (radius, pull strength, coupling stiffness, damping, swirl strength, unwind rate) in one named place with a comment on what each does.
- Implement the field as a small pure module (e.g. `src/shared/rippleField.ts`) that Waves consumes through a per-frame getter prop (extend change 8 or add change 9 in the React Bits change list); keep Waves' own edits minimal.

## Prior art
2D water-ripple simulation (the classic two-buffer damped wave equation, as in Hugo Elias's water algorithm), spring-mesh cloth (verlet-js, MIT), and vortex/curl displacement used in fluid-like UI effects; Waves' own per-point spring (`tension`, `friction`) already exists and is the base.

## Tests
Checks for the pure field module: a single disturbance stays local at first and spreads outward over time; energy decays (settles to zero displacement); displacement is bounded; swirl direction follows the turning direction and unwinds; framerate independence (same state at t for dt=1/30 and 1/120 within tolerance); momentum's virtual pointer drives the field. `npm run build` and `npm run lint` pass.

## Commands
`npm run build`, `npm run lint`, `node <script>` / `npx <tool>` for the check scripts, `git add`, `git commit`. One command per Bash call.

## Done when
A drag on the hero makes a local ripple-stretch that flows outward and swirls the lines, momentum carries a fading disturbance after a fling, the global pattern no longer jumps, and the checks, build and lint pass.
