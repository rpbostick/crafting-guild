# Speed up the pipeline test suite

**Track: light**, plus the timing numbers below.

`pipeline/.venv/bin/python3 -m unittest discover -s pipeline/tests -p "test_*.py"` (run by `bash scripts/run-all-tests.sh`) now takes about 13-17 minutes (1,035 s at `bcf85c2`), which is longer than one builder command may run and makes every merge gate slow. Most of the time is likely tests re-reading and re-parsing the real catalog (about 900 items and their SVG files) per test or per class. Use one command per Bash call.

Commands you may run: `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `bash scripts/run-all-tests.sh`, `git grep ...`, git add/commit.

## Do
1. Measure: time each test file (split into groups so no call passes 10 minutes) and list the ten slowest files with seconds.
2. Make them faster without weakening them: load the manifest and parse each SVG once per process (a module-level cache, e.g. `functools.lru_cache` on the loaders the tests use, or `setUpClass`/`setUpModule` instead of `setUp`), avoid re-running a pipeline step per test when one run can serve a class, and parallelise if the suite allows it. Don't drop, skip or shrink any test; the test count must stay the same.
3. Re-measure. Target: the whole pipeline suite under 5 minutes.

## Done when
- Same number of pipeline tests, all OK, before and after (both counts reported with exit codes).
- The before/after times per slow file and in total are in the final summary.
