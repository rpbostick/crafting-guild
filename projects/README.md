# Registered projects

One file per project, `<slug>.conf`, written by `bin/ws init <path>` and safe to edit by hand. Running `ws init` again on a registered project changes nothing unless you pass `--force`, which backs the conf up and keeps the keys init does not write; `--dry-run` shows the difference first:

```
PROJECT_PATH="/absolute/path/to/repo"
PROJECT_BRANCH="master"
TEST_CMD="bash scripts/run-all-tests.sh"
```

`example.conf.sample` shows a full conf with every optional key. Confs hold your machine's paths, so they stay out of a published copy of the workspace.

`TEST_CMD` runs from the repo root, in the worktree for builders and in the main checkout before a push. Leave it empty for a project with no tests; merges then push without a gate and say so.

`POST_MERGE_CMD` (optional) is a chore that follows every successful merge, such as rendering review sheets, restarting a server or rebuilding a site. `ws merge` starts it detached in the main checkout after the push (or the local merge when there is no remote), under the preview memory cap, with `WS_MERGED_SHA`, `WS_MERGED_NAME` and `WS_PROJECT` set. Its output goes to `runs/<slug>/post-merge-<name>.log`, its outcome to `runs/<slug>/post-merge.status`, and a failure raises a desktop notification and shows in cold start; it never changes the merge's exit code.

`WORKTREE_ENV_FILE` (a path in the repo, e.g. `.env.local`) and `WORKTREE_ENV` (an array of `KEY=value` lines) give builders' test runs their environment, since builders cannot run `env VAR=... <cmd>`: `ws dispatch` writes the lines into that file in each new or reused worktree, for tools that read it (Vite's `loadEnv` reads `.env.local`). It refuses when git does not ignore the file in the worktree, so the values never reach a branch, and a file there with other content is copied under `.ws-evidence/` with a warning before it is replaced.

`TEETH_CMD` (optional) is what `ws teeth` runs with a branch's non-test changes reverted; it defaults to `TEST_CMD`. `TEST_GLOBS` (optional) lists the shell globs that mark a file as a test, so teeth keeps it while reverting the rest; the default covers `*.test.*`, `*.spec.*`, `test/`, `tests/`, `__tests__/`, `test_*.py`, `*_test.py` and `*_test.go`. A `TEST_CMD` that runs `npm ci` or `npm install` works: teeth drops the worktree's linked `node_modules` first so the install stays in its scratch tree.
