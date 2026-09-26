# Spike: can facial hair get its own fill and outline colour? (plan 18 step 5c, report only)

Colorwright is an avatar builder over the Open Peeps art. Heads already have `hair` and `hair-outline` colour roles: `pipeline/split_hair_from_head.py` cuts them, and for the 18 styles drawn as solid black ink it takes the ink surviving a morphological opening as the hair mass, with a derived rim as the outline (see its docstring and `scripts/evidence/hair-colour-5b2/`). Facial hair has no such roles yet. All 144 facial-hair items (16 styles on 9 poses, `assets/catalog/manifest.json`, slot `facial-hair`) have one role, `outline` on `🖍-Ink`, default black. Full 4 and Moustache 9 also have a white fill shape with no role, so they render as fixed white beards.

Patrick wants facial hair to get its own colour and outline colour. An unpicked beard follows the hair colour. This task is a **report only**: change no pipeline module, catalog file, frontend or backend code. Stop when the report is written.

Use one command per Bash call. Commands you may run: `pipeline/.venv/bin/python3 ...` and `pipeline/.venv/bin/python ...` (write your scripts under `scripts/evidence/facial-hair-colour-spike/`), `backend/.venv/bin/python ...`, `ls`, `cat`, `grep`, and git add/commit.

## Answer, with evidence in `scripts/evidence/facial-hair-colour-spike/`
1. **How is each of the 16 styles drawn?** Check the source SVG shapes of one pose's items (walking) and confirm the other 8 poses match: solid ink only, ink plus a white or coloured fill, or thin strokes (stubble, a thin moustache) where an opening would erase everything. Give a table: style, shapes, and the ink area that survives the opening `split_hair_from_head.py` uses (`SOLID_INK_OPENING`). Check the Sketch source's regions if `plans/sketch-source-extraction-spike/` has them for facial hair.
2. **Does the 5b-2 cut work?** Reuse `split_hair_from_head.py`'s functions (import them; don't copy or change them) to cut a fill and a derived rim for every style on walking. Report per style: fill area, rim area, and whether anything visible is lost or left over. List styles where it fails, and why.
3. **Full 4 and Moustache 9:** what the white shape is (a fill inside the ink? a highlight?), and whether it should take the facial-hair fill colour or its own role. Show both options rendered.
4. **Sample recolours:** render each of the 16 styles on walking, on one head with a hair colour set, twice: the beard following `#8B4513` hair with a `#3B1F0A` outline, and a separate pick of `#C0C0C0`. Use `pipeline/render_check.py`'s `compose_svg` and `render`. Put them on one contact sheet, `contact-walking.png`, and render one more pose (crossed_arms) for the three hardest styles.
5. **Options and a recommendation:** the approach (for example, the 5b-2 cut for all 16; or the cut for the solid ones and a single fill role for thin-stroke styles where the ink stays the colour), the item count affected, and what the build step would touch (pipeline module, catalog regeneration, `frontend/logic.js` for "follows the hair until picked", the 5b-3 carried picks, tests).

Write `scripts/evidence/facial-hair-colour-spike/README.md` with the answers, every command with its exit code, and repo-relative paths only (no `/home/...`). Commit it with the scripts and images in one commit.

## Done when
- The README answers 1-5, with the table in 1 and the per-style results in 2.
- `contact-walking.png` exists and shows all 16 styles in both colourings.
- `git status` is clean apart from gitignored files, and no file outside `scripts/evidence/facial-hair-colour-spike/` changed.
