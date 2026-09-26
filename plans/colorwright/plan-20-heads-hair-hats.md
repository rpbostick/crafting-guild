# Colorwright plan 20: head styles × hair × hats

**In flight right now**: see `plan-19-rest.md` (the one in-flight block for colorwright today).

## Requirements (Patrick, 2026-09-26, on the heads analysis `scripts/evidence/heads-analysis/`)
- "if there is any variation in heads, i want the variation to be kept. if that means there are only a small number of head styles, that's fine. but i want as much variety in head style as we can. separate the head style from the hairs, make them work together. and then make all the hats work with all the heads + hairs."
- Bear: "keep bear as a head hair shape, but be able to add hair and hats to it." Bear is a head style (its face and fur), and hair and hats can go on it.
- Big hair under hats: "Redraw big-hair edges too" (Long Afro, Long Curly, Cornrows 2), not only the 6 "top" tucks.
- Earlier today: the hat heads become hats (hats round 2, `task-hats-round2.md`); hand-drawn tuck regions, not a straight line.

Facts from the analysis: 29 of 31 heads are one skull and jaw redrawn, varying mostly in ear height (y 326-384) and chin (up to 29 units); only No Hair 1 draws a skull; Bear has its own face; the Hijab's face is No Hair 1's. So head styles = the distinct visible variations (ear, jaw, chin), each needing a bald skull patched from No Hair 1's.

Guesses to check with Patrick at the spike: how many head styles (the spike proposes groupings with renders; he picks); whether hair ears follow the head style (the ear belongs to the head now).

## Steps
1. **Spike: head styles and hair on each** (report only) — `task-heads-spike-2.md`, continuing branch `agent/cw-heads-spike` (its first review's stale Q2 numbers are fixed there first). Stop for Patrick to pick the head styles.
2. **Build: head styles + a Hair row** — pipeline (bald head styles, hair items with back/front layers), manifest `hair` slot, backend look migration (`hair` column), frontend Hair row and draw order. After hats round 2 merges.
3. **Hats on every head + hair** — hand tuck regions per hat per hair class, redrawn big-hair edges per hat; Hijab hides all; checked on a grid for Patrick.

## Done when
Every hair on every head style, every hat on every head + hair, checked by Patrick on a preview.

## Decisions
- 2026-09-26: **9 head styles** (the 2-preview-px threshold), Patrick: "go with 9 head styles". Given before the part-2 README was finished; the build uses the spike's 9-style grouping.
- 2026-09-26, on the spike's part 2 (`bfeb4df`): **Bear**: hats on Bear now, hair later (Bear stays a head style with its fur; the Hair row greys out on Bear; face-on hair redrawings are a later project). **No earless variants**: the head style's ear is drawn over the hair (some combinations will show an ear where the hair would cover it). **Hair defects fixed once per hair** (Gray Bun's back, Bun 2's wisp, Flat Top Long's sideburn). Earlier today: redraw big-hair edges under hats (all three hats), 9 head styles.
