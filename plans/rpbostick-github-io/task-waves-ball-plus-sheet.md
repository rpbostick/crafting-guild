# figurewright hero: a subdued ball spin plus the stretchy sheet

Track: light

Continue on this branch (sphere spin in `src/shared/sphereSpin.ts`; the earlier bedsheet follow/glide lived in `src/shared/clothFollow.ts`: if it was deleted, restore it from git history, e.g. `git show e4456a8:src/shared/clothFollow.ts` and its check script, at the doubled tuning: follow 30%, cap 12%, glide 3–9 s, heavier). Feedback: the ball is really cool; **subdue the spin about 80%** and **combine it with the stretchy sheet dynamics**.

## Behaviour
- **Spin at 20%:** a drag turns the sphere one fifth as much as the 1:1 grab (the pattern no longer stays under the pointer; it turns gently in the drag direction), and the release spin's angular velocity is one fifth as well (same 3–9 s deceleration). One named constant (`SPIN_SCALE = 0.2`) controls it.
- **Stretchy sheet on top:** the cloth follow returns: while dragging, the field stretches toward the pointer (30% of the drag offset, capped at 12% of the hero's shorter side, strongest near the pointer and weaker far away, soft lagging spring); on release it glides on in the drag direction and decelerates over 3–9 s with **no spring back**, then the pattern continues from where it ended up.
- The two combine additively: the sheet's stretch and glide in screen space, the subdued spin in sphere coordinates, the local ripple and swirl on top.
- Reduced motion: none of the three.

## Tests
Checks: spin scale 0.2 (a drag turns the sphere 20% of the 1:1 amount, both axes); cloth follow at 30%/12% with falloff; release glides without spring back; combined state stable and bounded; framerate independence. `npm run build` and `npm run lint` pass.

## Commands
`npm run build`, `npm run lint`, `node <script>` / `npx <tool>`, `git show <commit>:<path>`, `git add`, `git commit`. One command per Bash call.

## Done when
The hero spins gently (20%) like the inside of a ball while the sheet stretches toward the drag and glides on after release, with ripple and swirl on top, and checks, build and lint pass.
