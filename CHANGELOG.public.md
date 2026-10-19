# Changelog

Versions of Crafting Guild. `ws version` prints the current one.

## 2.5.4

- `ws release` authors the public commit and tag as GitHub's no-reply address for the public repository's owner (or `RELEASE_NAME`/`RELEASE_EMAIL` from the conf), so the private repository's e-mail never reaches the public history.
- `ws release` publishes a GitHub Pages site when the conf sets `PAGES_BUILD` (and `PAGES_DIR`, default `dist`): it builds from a clean clone of the new tag, scans the output for home paths and keys, and pushes it to the public repository's `gh-pages` branch.
- `ws release`: the e-mail check skips third-party licence texts, manifests and lockfiles (as the attribution check already did), so a dependency author's address in `THIRD_PARTY_LICENSES` or `package-lock.json` no longer stops a first release.
- `ws merge` takes a per-project lock (`runs/<project>/merge.lock`), so two lanes that finish together merge one after the other instead of both working in the same main checkout. A second merge says it is waiting.
- `ws review`: when the reviewer model has reached its usage limit, the review runs once more on the light-track model (`WS_REVIEW_MODEL_LIGHT`) instead of failing, so a chain doesn't stop on it.
- `ws chain`: an automatic fix round's task keeps the original task's `## Commands` section, so the fix builder gets the same grants and can re-run its tests. Before, the section was demoted with the rest of the original task, the fix round got none of those grants, and it ended partial.
- Result check: a done-when item's evidence path is read without the punctuation after it (`.ws-evidence/a.log: 192 functions` names `.ws-evidence/a.log`), and a bare file name is also looked for in `.ws-evidence/`. Before, a trailing colon failed a run whose evidence was there, and some citations weren't checked at all.
- `ws chain` resumes a stopped run: a `NO RESULT` file (what a run stopped by hand or a closed session leaves) counts as no result, and a worktree with no run whose task has a line starting `Resume:` is dispatched again. Before, the chain stopped on the stale file as a failed check.
- Builders may run `git check-ignore` (read-only), and the builder lessons say to read files outside the worktree with the Read and Grep tools: the automation audit found Bash `grep`, `ls` and `git show --output` on outside paths among the most frequent denials.
- `ws chain` and the result check read a weekly limit's reset time ("resets Oct 19, 4am"), not only a clock time ("resets 8pm"), and never roll a dated reset to the next day. Before, a review that hit the weekly limit stopped the chain with "reset time unknown".
- `ws wait` checks a saved failing result again when the result check has changed since, so restarting `ws chain` after a fix to the check carries on instead of stopping on the old verdict.
- `ws merge` keeps the git-ignored files a builder made (a generated recording, a download) under `runs/<project>/evidence/<name>/ignored/` and names them, instead of discarding them with the worktree. Dependency, build and cache folders, `.ws-evidence` and linked paths are skipped; files over 20 MB are named, not kept.
- `ws dispatch` names the paths `.worktree-links` links into a worktree as read-only in the builder's prompt (writing through them is denied), and says where to save files that must outlive the run.
- `ws review` names any other project's plan that mentions the branch, so a branch kept waiting on purpose (for a demo or a recording) isn't merged by mistake.
- Builders may run `sha256sum` and `file` by default (both read-only), so checking a download no longer costs a denied call. `unzip` still has to be named in a task's `## Commands`.

## 2.5.3

- `ws dispatch`: a glob in a task's `## Commands` is not expanded against the workspace's files. `` `node *` `` is granted as `Bash(node*)`; before, it became `Bash(node agents*)` from the folder listing.
- `ws dispatch --dry-run` (and `--print-prompt`) leaves nothing behind: a worktree and branch it created for the dry run are removed, so a later dispatch branches from the main branch as it is then. A worktree that already existed (a resume) is kept.

## 2.5.2

- `ws dispatch`: a task command written `git -C <dir> <sub>` is granted as exactly that. Any other git command starting with an option is no longer granted; before, both became a grant for every git command (`Bash(git*)`).
- `ws audit`: a check script counts as in the suite when any script the test command runs names it, followed through more than one file (`run-all-tests.sh` calling `run-e2e.sh`), including by name without its extension. Wrapper calls from before `ws-run` existed, and hand runs of scripts the suite already runs, are no longer flagged.
- The selftest's shellcheck step fails the selftest on a warning. Before, it only skipped printing "shellcheck ok". The scripts are now shellcheck-clean (`.shellcheckrc` covers sourcing config files by a variable path), and `ws init`'s Node detection works in a repo with more than one `*/node_modules`.

## 2.5.1

- `ws release`: moving the `v<major>` branch no longer prints GitHub's pull-request hint, and the "version already exists" message names `VERSION` as well as `package.json`.

## 2.5.0

- **Versions and rollback.** Every `ws release` now creates a GitHub release page (notes from the published changelog, marked Latest), tags the private commit it published (`released-vX.Y.Z`), and with `RELEASE_MAJOR_BRANCHES=1` moves a public branch `v<major>` to the release, so users can install any exact version or the newest of a major version. `ws rollback <version>` puts the published files back to a release as one new commit, leaving everything outside `RELEASE_PATHS` alone; `--dry-run` lists what would change. README: Install a specific version.
- Release notes match the version exactly (2.3.1 no longer picks up 2.3.10's section).

## 2.4.2

- `ws doctor` runs on its own: cold start prints its failures (with their fix) and warnings at every session start, and `ws chain` refuses to start while a required check fails. CLAUDE.md says when to run it by hand. Its `gh` check has a 5-second timeout.

## 2.4.1

- README: "Check a setup: `ws doctor`", what it checks (required and optional, per machine, workspace and project) and when to run it.
- Documentation brought up to date with 2.4.0: CLAUDE.md (init --dry-run, doctor, the done-when report), COMPARISON.md (done-when checks), MODIFYING.md (check-result, statusline.sh, what the selftest covers), projects/README.md (re-running init), the README's command table (`ws version`).

## 2.4.0

- **Done-when, item by item.** Builders report every done-when item as met, partial or open, and whether they ran something to show it (`observed`, with the log or file) or reasoned it (`inferred`), plus what they could not establish (`unknowns`). The result check fails a `done` with an item not met and an observed item whose evidence is missing, and shows items met on inference alone. The reviewer gets the task's done-when and the builder's report, and treats an inference a user would hit as blocking.
- **`ws init --dry-run`** shows the conf it would write and the changes; an existing conf is replaced only with `--force`, after a backup, keeping keys init does not write.
- **`ws doctor`** checks the machine (bash, git, jq, GNU timeout, python3, the Claude Code version, systemd scopes, gh, rsync, shellcheck, the browser command), the workspace (the SessionStart hook, `ws` on PATH, lessons caps) and the selected project (path, branch, test command, remote, excludes), with a fix for each failure.

## 2.3.11

- CONTINUITY.md: how a new session picks up where the last one stopped (the files, the cold start, the cycle), summarised in the README.
- Cold start prints the whole In flight block: paragraphs separated by blank lines, up to the next section. It used to stop at the first blank line.
- README: a short "Why use it"; COMPARISON.md has the longer case, the evidence and a table against Claude Code in a terminal, Claude Code in VS Code and the Agent SDK.

## 2.3.10

- The name in titles and `ws version` is Crafting Guild; the full product name, Crafting Guild Agentic Workspace, opens the README.
- `ws release` names the release commit after the public repository, and its e-mail check skips `git@github.com` (GitHub's SSH host).

## 2.3.9

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
