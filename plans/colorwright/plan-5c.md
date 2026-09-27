# Colorwright 5c: facial-hair colour

**Done.** Current colorwright work: `plan-19-rest.md` (in-flight block) and `plan-20-heads-hair-hats.md`.

## Requirements (Patrick, 2026-09-24 and 2026-09-25)
- Facial hair gets its own colour, separate from the hair, plus an outline colour like hair.
- An unpicked beard follows the hair colour; once picked, it keeps its own. The pick carries over head and body switches like the hair picks, and is saved with a look (the 5b-3 `carried_colors` mechanism).
- Full 4 and Moustache 9 have a white fill shape that needs its own role (they ship as fixed white beards today).
- Today all 144 facial-hair items (16 styles x 9 poses) have one role, `outline` on `🖍-Ink`, default black: the beard is solid ink.

Guessed (the spike checks these): facial hair is drawn like the 18 solid-ink hairstyles, so 5b-2's opening-plus-derived-rim cut in `pipeline/split_hair_from_head.py` carries over; "follows the hair colour" means following `hair` for the fill and `hair-outline` for the outline.

## Steps
1. **Spike** (`task-5c-spike.md`, builder `cw-5c-spike`, budget $5): the source-art check and sample recolours, with options. Stops for Patrick. Retryable from scratch; it changes no catalog or app code.
2. **Build** (task written after Patrick's choice): pipeline roles for the 16 styles on 9 poses, the frontend's follow-the-hair default and carried pick, tests with teeth, and a preview for Patrick. Retryable from scratch until merged.

## Done when
Merged, and Patrick has checked on the preview that an unpicked beard follows the hair colour, a picked one keeps its own, and Full 4 and Moustache 9 colour correctly.
