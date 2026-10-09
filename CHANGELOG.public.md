# Changelog

Versions of Waystation Guild. `ws version` prints the current one.

## 2.3.9 (2026-10-09)

First public release.

- **One orchestrator session per project.** `ws <slug>` opens Claude Code in the workspace with the project attached; a SessionStart hook prints a cold start (git state, worktrees, running builders and chains, previews, the plan's in-flight block) at every start, resume and compaction. Sessions are pinned to their project; cold-start warns when another session moved the selection.
- **Headless builders in git worktrees.** `ws dispatch` runs `claude -p` on a task file in `<project>/.worktrees/<name>` on branch `agent/<name>`, with a dollar budget, a timeout that follows the task's track (45m light, 120m otherwise), a memory cap through systemd user scopes, and a grant of exactly the commands it needs (the task's `## Commands` section is granted; destructive forms never are). Gitignored environments and `file:../` siblings are linked into the worktree.
- **Checked results.** Every run returns a JSON result; `check-result.sh` verifies claimed commits and test logs against the branch, lists denied calls, and recognises a run stopped by the usage limit with its reset time.
- **Evidence outside the product.** Builders run checks through `ws-run`, which logs each command's real exit code under `.ws-evidence/`; the merge keeps it under `runs/`.
- **One review per branch.** `ws review` runs a mechanical precheck (stray logs, malformed SVGs, future dates, missing paths, deleted files still referenced), then a read-only reviewer against the 20-rule `checklist.md`; light-track branches review on a cheaper model.
- **A merge with a test gate.** `ws merge` merges only the reviewed SHA, refuses lines that add home paths, the username or configured names, runs the project's tests on the merged tree, undoes the merge on red, pushes on green, restores files the test run rewrote, and warns when the suite is slow.
- **Unattended chains.** `ws chain` runs a queue of steps (dispatch, wait, review, one automatic fix round, merge), waits out usage limits, carries review suggestions forward, and stops only on a failure, a gate or a judgment call.
- **Previews.** `ws serve` runs a project's preview command from a worktree or the main checkout under a memory cap.
- **Releases and sites.** `ws release` publishes a private repository's main branch (or its `RELEASE_PATHS`) as one audited commit per release on a public repository, with a clean-clone build attached to a GitHub release; `ws site` copies published files into a site project, checks them byte for byte, tests, pushes and waits until live.
- **An automation audit.** `ws audit` reads the run logs for work builders keep doing by hand.
- **Private overlays.** `config.local.sh`, `CLAUDE.local.md` and `lessons/<role>.local.md` hold an installation's own settings, preferences and lessons beside the shared files.
