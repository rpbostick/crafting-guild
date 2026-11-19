# Registered projects

One file per project, `<slug>.conf`, written by `bin/ws init <path>` and safe to edit by hand. Running `ws init` again on a registered project changes nothing unless you pass `--force`, which backs the conf up and keeps the keys init does not write; `--dry-run` shows the difference first:

```
PROJECT_PATH="/absolute/path/to/repo"
PROJECT_BRANCH="master"
TEST_CMD="bash scripts/run-all-tests.sh"
```

`example.conf.sample` shows a full conf with every optional key. Confs hold your machine's paths, so they stay out of a published copy of the workspace.

`TEST_CMD` runs from the repo root, in the worktree for builders and in the main checkout before a push. Leave it empty for a project with no tests; merges then push without a gate and say so.

`RECORD_CONFIG_PATHS` (optional) is a space-separated list of shell globs for config files that `ws orchestrator-record` counts as docs and config rather than code, on top of `*.md`, `docs/*`, `.gitignore` and `.editorconfig`.

`POST_MERGE_CMD` (optional) is a chore that follows every successful merge, such as rendering review sheets, restarting a server or rebuilding a site. `ws merge` starts it detached in the main checkout after the push (or the local merge when there is no remote), under the preview memory cap, with `WS_MERGED_SHA`, `WS_MERGED_NAME` and `WS_PROJECT` set. Its output goes to `runs/<slug>/post-merge-<name>.log`, its outcome to `runs/<slug>/post-merge.status`, and a failure raises a desktop notification and shows in cold start; it never changes the merge's exit code.

`COLD_START_CMD` (optional) is a short, read-only command cold start runs in the project with a 20-second timeout; its output is printed only when it prints something. It is for a project-specific flag the orchestrator should see at every session start, such as a retention status line.

`WORKTREE_ENV_FILE` (a path in the repo, e.g. `.env.local`) and `WORKTREE_ENV` (an array of `KEY=value` lines) give builders' test runs their environment, since builders cannot run `env VAR=... <cmd>`: `ws dispatch` writes the lines into that file in each new or reused worktree, for tools that read it (Vite's `loadEnv` reads `.env.local`). It refuses when git does not ignore the file in the worktree, so the values never reach a branch, and a file there with other content is copied under `.ws-evidence/` with a warning before it is replaced.

`TEETH_CMD` (optional) is what `ws teeth` runs with a branch's non-test changes reverted; it defaults to `TEST_CMD`. `TEST_GLOBS` (optional) lists the shell globs that mark a file as a test, so teeth keeps it while reverting the rest; the default covers `*.test.*`, `*.spec.*`, `test/`, `tests/`, `__tests__/`, `test_*.py`, `*_test.py` and `*_test.go`, and, when `TEST_GLOBS` is unset, the script the command's final segment runs as `bash <path>`, `sh <path>` or a tracked executable word, so a project whose whole suite is one shell script counts it as a test file. A set `TEST_GLOBS` replaces the default and the derived script. A `TEST_CMD` that runs `npm ci` or `npm install` works: teeth drops the worktree's linked `node_modules` first so the install stays in its scratch tree.

`ws security-scan` reads six optional keys, all empty by default. A scanner with nothing to read prints `not scanned` and is not a failure. Every run ends in one of three states, printed as its last line: `RESULT: PASS <n> passed <m> accepted` (exit 0), `RESULT: FAIL <n> actionable` (exit 1, a finding no acceptance covers) and `RESULT: INCOMPLETE <reason count> <first reason>` (exit 2). INCOMPLETE is the scan not having fully run: a tool named for the run is not installed, a report is unreadable or empty, an acceptance is stale, or the run is offline. Findings are counted and printed in every state. In `--quick`, dependencies are read from these lockfiles, never from an installed tree, so a missing lockfile means a clean miss and not a directory scan; `--all` adds whole-checkout scans (syft `dir:.`, trivy `fs .`, gitleaks `--source .`, npm audit in `SECURITY_FRONTEND`, which audits `--package-lock-only`) that read every file there.

Acceptances live in `plans/<slug>/security-baseline.tsv`, one `tool<TAB>rule<TAB>path<TAB>reason` row per accepted finding. The path is repo-relative with a leading `./` and is the whole identity: a basename or a line number is not a key, so a second `Dockerfile` elsewhere in the tree is never accepted by a row for `./Dockerfile`, and moving a file means accepting it again. A row with no reason is refused when the file is read, naming the row; an acceptance whose path no longer names a file in the tree prints `[STALE]` and makes the run INCOMPLETE. `--update-baseline` rewrites the file with `unreviewed: --update-baseline` as the reason for a new row, keeps the reason of a row it rewrites, refuses a finding whose path is not a file, and refuses the write while a tool did not run.

- `SECURITY_PATHS=(...)` — the directories or files semgrep reads (`SECURITY_PATHS=(scripts bin)`). Empty means semgrep has nothing to scan.
- `SECURITY_LOCKFILES=(...)` — the lockfiles osv-scanner reads, one call each (a `requirements.txt`; it cannot read a uv lock).
- `SECURITY_UV_LOCK=""` — the hash-pinned requirements-format lock pip-audit reads with `--disable-pip`, e.g. from `uv export --format requirements-txt`; a `uv.lock` is TOML and is refused.
- `SECURITY_FRONTEND=""` — the directory `npm audit` runs in, relative to the repo root.
- `SECURITY_EXCLUDE=(...)` — extra paths or globs no scanner reports, on top of the built-in `.git`, `.worktrees`, `.venv`, any `*venv` directory, `node_modules`, `__pycache__`, `.pytest_cache`, `dist` and `coverage`.
- `SECURITY_SCAN_OFFLINE=1` — skip semgrep (no offline rule cache) and npm audit (registry data) with a `skipped` line each; the run ends INCOMPLETE.
