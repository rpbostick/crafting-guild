# Fix round: CharacterStudio hands-on report, figures against the saved runs

Track: light

The review of `docs/research/avatar-characterstudio-handson.md` (at f9d5f49) found one claim its own evidence contradicts. Fix it, and bring the measured ranges in line with the saved results files. Edit only the report; run nothing new (the editor runs are done). The evidence is in this worktree's `.ws-evidence/` (`drive-results-run9.json`, `-run10.json`, `-run12.json`, `-run13.json`).

## Blocking
- Line 141: "Some waist traits carry a mesh named like the body (Feminine002, 1,908–5,708 triangles)". In `drive-results-run12.json`, Feminine002 with 1,908 triangles is in the Chest group (trait ring_mail, lines 669–681) and Feminine001 with 794 triangles is in the Head group (trait silk_hood, lines 618–631); no saved run shows a Waist trait with such a mesh. Correct the claim to what the saved files show (which groups and traits carry body-named meshes, with counts), and drop any figure no saved file holds.

## Also fix
- Line 131 (initial outfit): widen the ranges to the saved runs or name the runs: mean frame 91.41 ms (run12) to 103.33 ms (run9) against the stated 112–125; p95 166.6 ms (run12) against 183–217; render triangles 39,240 (run13); 37,873 is in no saved file.
- Line 134: the initial load's saved spread is 7.2–21.4 s (bodyLoadMs 7,160 in run10, 21,429 in run9), not 7.8–15.5 s.
- Line 129: body + cap, gauntlets, boots p95: give the range including run10's 100 ms, or name the run.
- Line 74: say the next pass also removed the chest (the chestRemoved step), so a reader does not expect the cancel alone to restore faces.
- Line 9: say that only runs 9, 10, 12 and 13 were kept, so figures from other runs cannot be checked; quote only figures from those.

## Done when
- Every figure in the report's measurement sections matches one of the four saved results files, or names its run.
- The line 141 claim matches `drive-results-run12.json`.
- The report is committed.

## Prior art
Not a build: a correction to a research report.

## Commands
`cat`, `grep`, `ls`, `node *` (to read the JSON files), `git add`, `git commit`. One command per Bash call.
