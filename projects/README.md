# Registered projects

One file per project, `<slug>.conf`, written by `bin/ws init <path>` and safe to edit by hand. Running `ws init` again on a registered project changes nothing unless you pass `--force`, which backs the conf up and keeps the keys init does not write; `--dry-run` shows the difference first:

```
PROJECT_PATH="/absolute/path/to/repo"
PROJECT_BRANCH="master"
TEST_CMD="bash scripts/run-all-tests.sh"
```

`example.conf.sample` shows a full conf with every optional key. Confs hold your machine's paths, so they stay out of a published copy of the workspace.

`TEST_CMD` runs from the repo root, in the worktree for builders and in the main checkout before a push. Leave it empty for a project with no tests; merges then push without a gate and say so.

`WORKTREE_ENV_FILE` (a path in the repo, e.g. `.env.local`) and `WORKTREE_ENV` (an array of `KEY=value` lines) give builders' test runs their environment, since builders cannot run `env VAR=... <cmd>`: `ws dispatch` writes the lines into that file in each new or reused worktree, for tools that read it (Vite's `loadEnv` reads `.env.local`). It refuses when git does not ignore the file in the worktree, so the values never reach a branch, and a file there with other content is copied under `.ws-evidence/` with a warning before it is replaced.
