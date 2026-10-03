# figurewright hero: double the drag effects

Track: light

Continue on this branch. Feedback after trying the bedsheet glide: turn every drag mechanic up about 2×.

## Behaviour
- **Follow:** the held-drag pull goes from 15% to **30%** of the drag offset; raise its cap from 6% to about **12%** of the hero's shorter side (keep the falloff shape away from the pointer).
- **Glide:** after release the sheet carries on and slows over **3 to 9 seconds** (slow flings near 3 s, hard flings near 9 s) instead of 1–3 s: lower the glide friction accordingly and raise the maximum glide time; it still resumes its own pattern with no spring back.
- **Heavier:** the sheet feels more massive: slower to start following (softer spring / more lag) and more momentum on release.
- **Local effect 2×:** the ripple-stretch pull and the swirl strength both doubled (keep displacements bounded so lines never tangle; widen the clamp if needed to allow the stronger effect).
- Keep all of these as the named constants they already are; update their comments with the new values.

## Tests
Update the checks that pin the old values (follow fraction, cap, glide duration range, ripple and swirl strength); the stability checks (bounded displacement, settles, framerate independence, no spring back) must still pass. `npm run build` and `npm run lint` pass.

## Commands
`npm run build`, `npm run lint`, `node <script>` / `npx <tool>`, `git add`, `git commit`. One command per Bash call.

## Done when
Follow 30%, glide 3–9 s with more mass, local ripple and swirl doubled, stable, checks/build/lint passing.
