# figurewright I5: found-art import, third run (the medium's joints, the trousers under the hand)

**Resume.** Same branch (`agent/fw-found-art`), third run, through cdda09b. Run `git status` and `git log --oneline main..` first and read your last result's open questions. Change files with Edit and Write.

## Decisions on your open questions
1. **Register the candidates by the medium's own posed joints carried onto the art** (your `medium` variant). Your measurement settles it: the pose takes only the rig's angles and ratios, so the posed medium's joints lie 2.75 to 6.65 cm off the fitted ones, and only the medium's own joints put a piece back where the art drew it. Make `medium` the default and the registration of every candidate; keep `drawn` and `fitted` only if a test or the comparison table uses them, and say in `docs/found-art.md` why `medium` is the one. Re-run the batch and the contact sheets with it.
2. **The trousers are completed under the art's hand** in the pocket, as the waistline is: a part marked completed, closing the notch along the trousers' own side edge. Then tighten the seam test's bound for the trousers to what the shirts meet (a few pixels at notches the garment itself has), with the number measured.
3. **Unit tests for the importer's two fail-loud cases** (a seam on a torso part, a seam on a rigid part), and a saved failing run of the seam test file itself (one seam's blend disabled), so the test is shown to fail.
4. **What stays as it is**, stated in `docs/found-art.md` with the numbers: our ink is centred on the art's fill edge, so the dressed outline sits about half an ink stroke outside the art's; the collar's largest distance is the dark tee's collar under the open shirt; the lower legs' largest is at the shoes.

## Evidence
`.ws-evidence/found-art/index.html`: at the top, the overlay of the medium dressed in easing-2's shirt and trousers registered by `medium`, beside the tee, zip jacket and long pants overlay, with the table of every region for both; then the contact sheets of every candidate on the seven bodies; then the comparison of the three registrations.

## Prior art
Nothing new: the repo's own scripts, as before.

## Commands
One command per Bash call, each check through the evidence runner: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>.ts [args]`, `npm run renders:sheets`, `npm run renders:approve`, `node`, `cp`. No `env VAR=…` prefix, `git -C`, `git archive`, `tar`, `git stash`, `git checkout` or `git restore`. Do not run `npm install`. Hold one raster at a time; run long render jobs in the foreground, split if needed.

## Done when
Every candidate is registered by the medium's joints, the trousers are whole, the three tests are in, `npx jest --runInBand` over the whole `test/` directory (in parts) and tsc pass, and the evidence page is laid out as above with the final table in your result.
