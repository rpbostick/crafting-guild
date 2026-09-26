# Plan 20 step 2a: 9 bald head styles and hair items (pipeline and catalog)

Patrick wants hair separate from the head: "separate the head style from the hairs, make them work together", with "as much variety in head style as we can". Read first: `scripts/evidence/heads-analysis/README.md` and `part-2/README.md` (the analysis this builds; its code is `heads.py` and `part-2/part2.py`), and the hats round 2 evidence `scripts/evidence/hats-round2/README.md` (the Hat Beanie, Turban, Hat Hip and Hijab heads are already gone from the Hair row).

**This step is pipeline and catalog only.** The app keeps working as today: the new items are written to the catalog and manifest, but nothing in the frontend uses them until step 2b. Use one command per Bash call.

Commands you may run: `node ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, `bash -n ...`, `md5sum ...`, git add/commit/rm/mv. Run long render or pipeline jobs **in the foreground** (split them if needed); a backgrounded job dies when your run ends.

## Patrick's decisions (2026-09-26)
- **9 head styles**, the spike's 2-px grouping (`part-2/README.md`, "At 2 px"): [No-Hair-1, Bantu-Knots, Flat-Top, Bangs-2, Cornrows-2, Gray-Bun, Long, Long-Afro, Long-Curly, Medium-Bangs], [Gray-Short, Medium-Bangs-2, Twists, Afro], [Flat-Top-Long, Shaved-2, Buns], [Short-5, Short-2], [Short-4, Cornrows], [Mohawk, Pomp], [Mohawk-2], [Bun, Bun-2], and Bear. (Turban, hat-beanie and hat-hip are no longer heads.) The spike built bald heads and the hair grid at 6 styles only: build them at 9.
- **Bear** stays a whole head style with its fur and its hair colour (Option C). No hair items go on Bear for now; hats will.
- **No earless variants:** the head style's own ear is drawn over the hair.
- **Hair defects fixed once per hair:** Gray-Bun's back, Bun-2's wisp, Flat-Top-Long's sideburn (`part-2/README.md`, section 2), so each sits on every head style.

## Build
1. **Bald head styles** (a new pipeline step): for each of the 9 styles × 9 poses, a head item: the style's base face, jaw, chin and ear joined to No Hair 1's skull (`bald_of_base` in `part2.py`). Hand-fix the joins the spike lists (H2's steps, the one-join styles, the ear-top notch on H4/H5-type styles; recheck all at 9). Colour roles `skin` and `outline` as today's heads. Bear is its existing head. Name each style readably (e.g. by its base head; propose names in the README; Patrick can rename).
2. **Hair items** (`pipeline/split_hair_into_items.py`, part 1 Q5 step 2): a `hair` slot item for each of the 25 hair styles × 9 poses, with back and front layers (Q2's rule, with its 3-unit overlap), keeping each hair's `hair` / `hair-outline` (and `bandana` / `bandana-outline`) roles and defaults, and a `tuck_class` (top / volume / braids / none, from part 1 Q4). The hair's own ear is not in the item. Plus a `*-None` hair item per pose.
3. **The three per-hair fixes**, in the hair items.
4. Keep the existing 31-style head items as they are for now (step 2b switches the app over and retires them). Re-run `compute_option_thumbnail_viewboxes` last; update `pipeline/README.md`'s "Run it".

## Tests (each shown failing against master first; teeth logs in the evidence folder)
- 81 bald head items (9 × 9) with `skin` and `outline` roles; each has no hair-role shape; the join fixes (a point per fixed join is outline or skin as intended).
- 225 hair items + 9 None: each item's shapes equal the source head file's hair shapes (fill and ink); back and front overlap by 3 units; roles and defaults as the source; `tuck_class` set.
- The three fixed hairs: a point per fix.
- The catalog sync (backend) accepts the new slot's items and doesn't touch saved looks.

## Renders (`scripts/evidence/p20-2a/`)
- The 9 bald head styles on all 9 poses.
- Every hair on every head style (25 × 8, plus Bear alone) on walking, with the style's ear drawn over; and 6 varied hairs × 9 styles on crossed_arms and robot_dance. Hair red, outline blue, so misfits show. List the misfits left, per pair.

## Evidence
`scripts/evidence/p20-2a/README.md`: every command, result and exit code; repo-relative paths only; full `bash scripts/run-all-tests.sh` output in `unit-tests.log` there.

## Done when
- The tests pass and were shown failing against master; the app is unchanged (`git diff master --stat -- frontend` empty).
- Renders committed, with the misfit list.
- `bash scripts/run-all-tests.sh` exits 0 and its log is committed.
