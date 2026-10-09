# Registered projects

One file per project, `<slug>.conf`, written by `bin/ws init <path>` and safe to edit by hand. Running `ws init` again on a registered project changes nothing unless you pass `--force`, which backs the conf up and keeps the keys init does not write; `--dry-run` shows the difference first:

```
PROJECT_PATH="/absolute/path/to/repo"
PROJECT_BRANCH="master"
TEST_CMD="bash scripts/run-all-tests.sh"
```

`example.conf.sample` shows a full conf with every optional key. Confs hold your machine's paths, so they stay out of a published copy of the workspace.

`TEST_CMD` runs from the repo root, in the worktree for builders and in the main checkout before a push. Leave it empty for a project with no tests; merges then push without a gate and say so.
