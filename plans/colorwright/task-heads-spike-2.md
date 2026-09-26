# Heads spike, part 2: head styles, and every hair on every head style (report only)

You are continuing on branch `agent/cw-heads-spike` (your heads analysis, `scripts/evidence/heads-analysis/`). Patrick read it on 2026-09-26 and chose a different direction from its recommendation (C, one head):

- **"if there is any variation in heads, i want the variation to be kept. if that means there are only a small number of head styles, that's fine. but i want as much variety in head style as we can. separate the head style from the hairs, make them work together. and then make all the hats work with all the heads + hairs."**
- **Bear:** "keep bear as a head hair shape, but be able to add hair and hats to it."
- **Big hair under hats:** redraw big-hair edges (Long Afro, Long Curly, Cornrows 2), not only tuck the "top" class.

Still report only: **change nothing in the app, `pipeline/`, the manifest or the tests.** Work under `scripts/evidence/heads-analysis/` (new files may go in a `part-2/` subfolder). Use one command per Bash call. Commands you may run: `node ...`, `pipeline/.venv/bin/python3 ...`, `backend/.venv/bin/python ...`, `bash scripts/run-all-tests.sh`, `git grep ...`, `md5sum ...`, git add/commit/rm.

## 0. Fix the review's findings on part 1 first (one commit)
- `README.md:214`: the back-layer numbers are stale. `hairlayer.log` gives Bangs-2 898, Bear 2685, Long 2190, Long-Afro 1967, Long-Curly 2013, Medium-Bangs 2271 (range 898-2,685); borderline Cornrows 320, Medium-Bangs-2 354. Use the log's numbers.
- `README.md:219`: "the other 17 are under 60 units²" is false (Afro 103). Pick a threshold the log supports, regroup, and update the Summary's Q2 row.
- `README.md:270`: say which Hat Hip figure is the 17-pair total and which the single pair (213 by bbox, 4,142 by anchors-ear).
- `heads.py:231`: `agreement_table()` silently reuses a stale `q1-agreement.json`; recompute or fail when it's older than the code. `heads.py:258`: comment that a None agreement becomes 0.0 on purpose. `heads.py:461`: move the numpy import to the top.

## 1. Head styles: keep every real variation
- From Q1's measurements, list every **visible** variation between the 29 template heads: ear position (height, size), jaw line, chin length, neck, cheek. Group the heads so that each group is visibly one head and different groups are visibly different at the app's preview size. Aim for **as many head styles as are really distinct**; merge only heads a viewer couldn't tell apart. Show the grouping as a contact sheet (bare heads, grouped, labelled with their source styles) and the numbers behind it. Say how many head styles you propose and what makes each distinct.
- **A bald version of each head style:** only No Hair 1 draws a skull. For each proposed head style, patch a bald head: the style's own face line, ear, jaw and chin, joined to No Hair 1's skull. Show where the join is drawn and whether it needs hand work. Render every bald head style on walking, crossed_arms and robot_dance.
- **Bear** is a head style with its own face and fur (its fur keeps its hair colour from the Option C build). Hair and hats must go on it.

## 2. Every hair on every head style
- Hair becomes separate items (back and front layers, as your Q2). The **ear now belongs to the head style**, so a hair must not cover it wrongly or carry its own. How: cut each hair's sideburn around an ear zone, draw hair behind the ear, or fit per head style? Try the best method and measure poke, gap and ear-wrong as in Q3.
- Render a grid: the 26 hairs × every proposed head style on walking (a contact sheet, or several), and 6 varied hairs × all head styles on crossed_arms and robot_dance. Include Bear: which hairs fit it, and what fitting a hair to Bear's wider head takes (a per-head-style hair fit, e.g. scale or a hand-adjusted anchor).
- Count what's needed by hand for full coverage: per hair, per head style.

## 3. Big-hair edges under a hat: one worked example
- For **Long Afro under the Beanie**, redraw the hair's edge where the tuck region cuts it (a "squashed afro" edge following the hat), by hand in atom units, on walking. Render before/after. Estimate the cost for Long Afro, Long Curly and Cornrows 2 × each hat (Beanie, Turban, Hat Hip; the Hijab hides all hair).

## 4. Options and the plan
Lay out the build as steps (head styles; hair items; the Hair row and migration; hats × head + hair), with what each changes and how it's tested, and the questions Patrick must decide (first: which head styles).

## Output
Update `scripts/evidence/heads-analysis/README.md` with a "Part 2" section (or `part-2/README.md` linked from it): answers, renders, measurements, the proposal. Repo-relative paths only. Save `bash scripts/run-all-tests.sh` output as `part-2/unit-tests.log` (it must be unchanged from master, since nothing outside evidence changes).

## Done when
- The review's findings are fixed and committed.
- The head-style grouping, bald heads, hair grid and the Long Afro edge each have committed renders and numbers.
- `git diff master...HEAD --stat -- ':!scripts/evidence/heads-analysis'` is empty.
