# Character sheet: no broken lines, weapon damage spacing, printer-paper background

Continue on this branch (the character on the letter-width World of Dungeons sheet). Fixes after a careful look at the preview.

## Behaviour
- **No broken lines anywhere.** At normal zoom (100%, devicePixelRatio 1) the widened boxes show breaks: faint hairlines and steps where art pieces meet, most visibly in and around the HIT DICE and HIT POINTS boxes, along the top of NOTES and across ruled lines; some stretched box corners don't match the original notched corners. Evidence: `/home/patrickb/agentic-workspace-v2/runs/pen-paper-rpg/staging/seams-hp-1x-zoomed.png` (a 1× screenshot enlarged 4×). At 3× zoom it looks clean, which is why earlier checks missed it.
  - Fix the cause, not each seam: **composite each art style into one finished image at build time** (the committed Node PNG code in `chargen/scripts/` can draw the pieces, bars and seams into a single RGBA bitmap per art: color and printer friendly) and show that one image per art behind the fields, so the browser never places pieces side by side. Keep the piece table as the source of truth; the composite is a build output. Check the size of the inlined images and keep the page reasonable (say the before/after size).
  - Every box corner on the stretched boxes (HIT DICE, HIT POINTS, COIN, XP, NAME, PORTRAIT, WEAPONS, EQUIPMENT, NOTES) must match the original sheet's corner shape exactly: copy the corner pixels from the art, never scale them.
  - Check at 100% and 200% zoom in headless Firefox (screenshots at 1× and with the page zoomed 2×, then enlarge crops 4× and look at every box edge); include those crops in `.ws-evidence/`.
- **Weapon damage sits a fixed distance after the weapon's name**, not pushed to the right edge: the damage starts about two to three tab widths after the end of the name (use one constant, about 6ch in the field font), so "Dagger      d6" and "Magical attack      2d6+1" each have the same gap. Long names still fit: the damage wraps nothing; if a name is too long the gap shrinks to 2ch. Same in both art styles and print.
- **Background paper looks like high-quality printer paper, not aged or speckled.** `chargen/assets/paper-texture.jpg` has already been replaced (committed on the branch) with a clean warm white (251/250/246) with a faint even grain; rebuild with it and check it reads as plain good paper behind the teal art. The Color style keeps its teal art on this paper.

## Prior art
The existing `chargen/scripts/png.js` encoder/decoder and the sheet-art piece table. No library.

## Tests
A test that the composited art image per style equals drawing the piece table (byte-for-byte or pixel hash) and that the page shows one art image per style (no piece images positioned side by side); corner pixels of each stretched box equal the art's corner pixels; weapon damage x position = name end + the constant gap; the paper image is the new one. Rebuild both outputs and commit them.

## Leave alone
`rules.js`, `data/`, `assets/wod-sheet.png`, `assets/wod-sheet-bw.png`, everything outside `chargen/`.

## Commands
`node --test chargen/tests/<file>.test.js` (one or several), `node chargen/build.js`, `node chargen/build.js --public`, `node chargen/scripts/<script>.js`, `node .ws-evidence/<script>.js`, `firefox --headless …` (as before), `git add`, `git commit`. One command per Bash call.

## Done when
No hairlines or steps at 100% or 200% zoom, stretched box corners match the original, weapon damage follows its name at a fixed gap, the background is the clean printer paper, both builds are rebuilt, and the tests pass.
