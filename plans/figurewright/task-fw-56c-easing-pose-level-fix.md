# Fix round for `fw-easing-pose-level` (review at 7553810)

Track: light

The review found one blocking issue. Fix it, commit, and do nothing else beyond the one check below. The rig, the body measurements, every bound, `assets/bodies/`, `tools/body3d/` and the code are not touched.

## Blocking
- `README.md:66` (rule 3): "easing's per-build arms: the library's abduct the far arm 18 to 45° by its arm rule" is no longer true. The regenerated easing `armRuleDegrees` for the far (left) arm now run from 3 (slim) to 18 (short and round); athletic-broad has `{right:12,left:12}` where it had `{right:2,left:26}`. Read the nine bodies' easing `armRuleDegrees` from `assets/bodies/*.json`, restate the range for both arms from that data (a small table in `.ws-evidence/arm-rule.md`), or drop the item if it no longer describes an open problem.

## One check in the same commit
- `README.md:99`: "easing's far arm stands stiffly out after the arm rule" came from the old 18–45°. Look at the far arm in the existing easing renders on the branch (`docs/renders/`, the page's sheets); restate or drop the line to match what the render shows, and say in the result which you did and why.

## Commands
One command per Bash call through the evidence runner: `node`, `cat`, `grep`, `ls`, `git add`, `git commit`. No other changes.

## Done when
README.md lines 66 and 99 match the regenerated data and the renders; one commit; the result quotes the old and new lines.
