# Test speed: merge master and resolve

**Track: light.**

You are continuing on branch `agent/cw-testspeed` (faster pipeline tests: memoised `pipeline/tests/cached_areas.py`, the parallel runner `scripts/run_pipeline_tests.py`). Master has moved (plan 20 step 2b, `215bb5a`), and `git merge master` conflicts in `pipeline/tests/test_add_hat_layer.py` and `pipeline/tests/test_split_hair_into_items.py`. Merge master, keeping both sides: master's new and changed tests, and your switch to the cached area helpers. Then run `bash scripts/run-all-tests.sh` once at the merge commit and report the pipeline test count (it must equal master's count, all OK) and time. Also from the review: narrow `cached_areas.py`'s docstring to what `scripts/check_cached_evenodd_area.py` actually checks, and say in a comment that the `lru_cache` is unbounded on purpose (one module per process).

Commands you may run: `git merge master`, `git status`, `git diff ...`, `bash scripts/run-all-tests.sh`, `pipeline/.venv/bin/python3 ...`, `git grep ...`, git add/commit. One command per Bash call.
