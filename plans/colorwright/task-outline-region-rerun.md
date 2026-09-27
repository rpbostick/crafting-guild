# add_outline_region: safe to re-run after split_facial_hair_colour

**Track: light.**

Found while rewriting `pipeline/README.md` (see its "Known gaps"): `pipeline/add_outline_region` skips only items that already have an `outline` role. After `pipeline.split_facial_hair_colour`, Moustache 1, 4 and 8 have only a `facial-hair` region on their ink shape (`🖍-Ink`), so re-running the head-SVG steps after that step would add a second region on the same shape. Found by reading the code, not by running it; confirm it first.

## Do
1. Show it: a test that re-runs `add_outline_region` over the current catalog's facial-hair items (in a temp copy, not the committed files) and asserts no shape gets two regions. It should fail now for those three moustaches.
2. Fix: `add_outline_region` skips an item whose ink shape already carries any colour role (not only `outline`). Keep it failing loud on anything unexpected.
3. `pipeline/README.md`: remove the gap from "Known gaps"; if it's now safe, give the head-SVG steps their fixed place in the "Run it" chain (just before `split_hat_cloth_from_head`, as the README suggests), and add to the idempotence note that `cut_hats_from_heads` only re-cuts after the head steps are re-run.

Commands you may run: `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `bash scripts/run-all-tests.sh`, `git grep ...`, `git status`, `git diff ...`, git add/commit. One command per Bash call; scratch under `build/`.

## Done when
- The new test failed before the fix and passes after; the pipeline tests pass (report files and exit codes).
