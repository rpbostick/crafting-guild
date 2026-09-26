# Registered projects

One file per project, `<slug>.conf`, written by `bin/ws init <path>` and safe to edit by hand:

```
PROJECT_PATH="/absolute/path/to/repo"
PROJECT_BRANCH="master"
TEST_CMD="bash scripts/run-all-tests.sh"
```

`TEST_CMD` runs from the repo root, in the worktree for builders and in the main checkout before a push. Leave it empty for a project with no tests; merges then push without a gate and say so.
