# figurewright hero: dragging spins the waves like the inside of a ball

Continue on this branch (local ripple-stretch and swirl in `src/shared/rippleField.ts`, momentum in `momentum.ts`, the bedsheet follow/glide in `clothFollow.ts`, pattern drift in `patternDrive.ts`, Waves' getter props per the React Bits change list in `src/reactbits/LICENSE.md`). Feedback after trying the doubled bedsheet: a downward drag doesn't rotate the pattern at all, a horizontal one too little. The model to aim for: **you are looking at the inside of a ball; dragging spins the ball in the direction you pull, and it keeps spinning.**

## Behaviour
- **Replace the bedsheet follow** (the fractional global offset) with a **sphere rotation**: the visible wave field is the inside of a sphere around the viewer. A drag rotates the sphere so the surface point under the pointer stays under the pointer (1:1 grab): horizontal drags yaw, vertical drags pitch, diagonals both. Vertical drags must move the waves vertically just as horizontal ones move them horizontally.
- **Momentum:** on release the sphere keeps its angular velocity and keeps spinning in the pulled direction, decelerating with friction over **3–9 s** depending on fling speed (heavy, as tuned last round), then the waves resume their own drift from the new orientation with no snap back. A new press grabs the spinning sphere smoothly.
- **Seamless and curved:** sample the wave pattern through the sphere: for each wave line point, its position on screen maps to a view direction; rotate that direction by the sphere's orientation; map it to the pattern's coordinates with a wrapping (periodic) parameterisation so rotation never runs out of pattern or shows seams; add a gentle inside-the-ball curvature (slight barrel/perspective bend toward the edges, adjustable, subtle by default) so motion reads as rolling around a curved surface rather than a flat slide.
- **Local ripple and swirl** stay on top, in screen space, at the doubled strength.
- Pattern drift and the tag click keep working (the pattern's own motion continues in sphere coordinates).
- Reduced motion: no spin, no momentum (the drag still ripples lightly or not at all; choose and say).
- Implement the sphere as a pure module (`src/shared/sphereSpin.ts`: orientation as a quaternion or yaw/pitch, grab/drag/release/advance, momentum decay) consumed through Waves' existing getter props; keep Waves edits minimal and record any new one in the React Bits change list. Remove `clothFollow` if nothing uses it any more.
- Named constants: friction range (3–9 s), curvature, grab sensitivity, maximum spin speed.

## Prior art
Arcball / trackball rotation (Shoemake's arcball; three.js TrackballControls and OrbitControls damping, MIT) for grabbing a sphere with the pointer; the existing momentum module for the decay.

## Tests
Checks for `sphereSpin`: a horizontal drag yaws and a vertical drag pitches by matching amounts (both non-zero, symmetric); the point under the pointer stays under it during a drag (within tolerance); release keeps spinning in the drag direction and decelerates, stopping between 3 and 9 s for slow and fast flings; no snap back; framerate independence; wrapping produces no discontinuity across the seam; reduced motion behaviour. `npm run build` and `npm run lint` pass.

## Commands
`npm run build`, `npm run lint`, `node <script>` / `npx <tool>`, `git add`, `git commit`. One command per Bash call.

## Done when
Dragging in any direction spins the waves like the inside of a ball, the spin continues and slows over 3–9 s, the pattern wraps seamlessly with a gentle curvature, the local ripple and swirl still work, and the checks, build and lint pass.
