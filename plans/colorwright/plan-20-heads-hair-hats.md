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

## Backlog (not scheduled)
- **Mirror the avatar** (Patrick, 2026-09-26): "i eventually want to be able to have the avatar mirror along the vertical axis (look left, look right), which will allow the prosthesis to be on either side." Likely a look-level flip (one SVG transform on the whole figure), a stored `mirrored` flag on saved looks and session state, and the preview and thumbnails following it; check that nothing asymmetric breaks (text, masks, hat cover regions are drawn in item units so they flip with the figure). After plan 20 and the prosthesis colours.
- 2026-09-26: Head row names **Head 1–8 + Bear** (descriptive names in the tooltip); an old session/look with one of the 31 heads becomes its head style + its hair. Step 2b task: `task-p20-2b-hair-row.md`.

## Wrap (Patrick, 2026-09-26: "we want to wrap this functionality soon. colorwright will be the foundation for a new project soon.")
In scope, in order (each after the in-flight prosthesis fix 3 and p20-2b fix 1 merge):
1. Pipeline test speed (`task-pipeline-tests-speed.md`, light) — first, so every later step runs faster.
2. Mirror the avatar and redrawn big-hair edges under hats (p20-3) — in parallel (frontend/look state vs pipeline hair covers).
3. Wrap-up pass: README and requirements current (head styles, hair, hats, colour roles, the pipeline chain), stale scripts and evidence clutter out, the live app on :8800 checked end to end; then tag colorwright `v1.0`.
- 2026-09-27: p20-2b fix round checked: head lines and Turban right; Beanie and Hat Hip not ("reference the original source art, maybe it just needs to have a small amount of hair like the turban but otherwise just fit well"; Hat Hip "hair is in the background behind it"). Patrick: merge 2b now, fix the two hats next (`task-hats-round3.md`); **the big-hair-edges step is folded into the Hat Hip fix** (`task-p20-3-bighair-edges.md` is dropped).
