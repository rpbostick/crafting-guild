# figurewright: the three found-art candidates become garments

Track: light

A person has looked at the contact sheets and accepted all three found-art candidates: `op-easing-1-jacket`, `op-easing-2-jacket` (easing-2's shirt) and `op-easing-2-pants`.

Read first: `docs/found-art.md`, `assets/garments/candidates/`, `scripts/found-art-sheets.ts`, how the committed garments in `assets/garments/` are listed, named and tested (`test/garments/import/`, `test/renders/`).

## Build
1. Move the three from `assets/garments/candidates/` into `assets/garments/` (their art too, wherever the committed garments keep theirs), with the names the catalog uses; keep their source (`vendor/colorwright/...`, Open Peeps, CC0) recorded in the asset as the others record theirs. Store listings must not use the Open Peeps name; the asset's source field is fine.
2. They enter the garment catalog, the layering order (shirt and jacket as tops, trousers as a bottom) and the deviation, layering and seam tests the committed garments run under; the seam test derives its ids from the folder (a carried suggestion), so nothing hand-kept is left.
3. Their sheets become goldens: `npm run renders:approve` after looking at them; the byte pins re-pinned if the lineup changes.
4. `docs/found-art.md` says they were accepted and when; the candidates folder is left empty or removed, with the batch script still writing new candidates there.

## Prior art
Nothing new: the committed garments show the pattern.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts [args]`, `npm run renders:sheets`, `npm run renders:approve`, `node`, `cp`, `git mv`. No `env VAR=…` prefix, `git -C`, `git archive`, `tar`, `git stash`, `git checkout` or `git restore`. Do not run `npm install`.

## Done when
The three garments are in `assets/garments/` and the catalog, under the same tests as the others, with goldens approved; `npx jest --runInBand` over `test/garments`, `test/garment-import` and `test/renders` and tsc pass.

## Carried from the fw-shoulders-chest review (suggestions; do them where the code is yours to touch)
- `src/body/skeleton.ts:613`: Rule 3: the comment says the radius over the deltoid's width 'was 0.76 on broad against the medium's 0.85', but main's code measures 0.606 and 0.848 (.ws-evidence/before-shoulder-table-main.log); 0.763/0.854 come from an intermediate working-tree run (before-shoulder-table.log at 16:16). The test comment in shoulder-overhang.test.ts uses main's 0.24–2.04 range, so align this number with main's (0.61) or say what state it was measured on.
- `scripts/easing-overlay.ts:33`: Rule 9 layering: a production script (and scripts/shoulder-overhang.ts line 16, which the test suite runs) now imports measurement helpers from test/body/shoulder-measures.ts. Move bideltoidOf, posedBideltoidOf and capRadius under scripts/ or src/body so scripts do not depend on the test tree.
- `test/body/easing-shoulders.test.ts:63`: 'is easing-2 as registered on the medium' only checks across ≈ up on the average build, which artShoulders derives from that same skeleton, so it can only fail if BUILDS' 'average' stops being the neutral sliders. Also asserting across and up equal registration(posed).up (and lift 0, as transforms.json records) would test the claim in the name.
- `src/body/sliders.ts:209`: With the CHEST_OF_UPPER_ARM floor, the chest slider at −1 has no effect on bodies whose upper arm already sets the chest (limbs +1, round builds): a dead zone a user will meet. Worth a line in the chest slider's description (SLIDER_ENDS) so the UI copy can say so.
