# Crafting Guild: the merge's home-path check skips the project's private files

Track: light

This branch is reviewed `merge`, but `ws merge` refused it: `scripts/merge.sh`'s home-path and username check (the `leaks=` line) flags `projects/skate-mario.conf`'s new `WORKTREE_ENV` line. Project confs hold home paths by design (`PROJECT_PATH`, `TEST_CMD`) and are private: `projects/crafting-guild.conf`'s `ATTRIBUTION_EXEMPT` names them ("Private files that hold the operator's own notes by design (never in RELEASE_PATHS)"), and the attribution check already skips them. The home-path check should skip exactly those private paths too, and nothing else: not `CREDIT_PATHS`, licences or package files, which `attribution_exempt` also returns.

## Fix
- In `scripts/lib.sh`, a helper that returns pathspecs for `ATTRIBUTION_EXEMPT` alone; `merge.sh`'s home-path check passes them to its `git diff`, as the attribution check passes its own. `scripts/precheck.sh` rule 18 does the same, so review and merge agree.
- From this branch's review (suggestions to take now, they are in code you wrote): reject `WORKTREE_ENV` values with an embedded newline; selftest checks for the conf errors (WORKTREE_ENV without WORKTREE_ENV_FILE, an absolute or `..` file, a line that is not KEY=value) and that a refused fresh dispatch leaves no worktree and no `agent/<name>` branch.

## Tests
`scripts/selftest.sh`: in a scratch project whose conf sets `ATTRIBUTION_EXEMPT=("private/*")`, a branch adding a home path in `private/x` passes the merge's leak check, and the same line in `public/x` is refused (call the check as merge.sh does, without merging, or merge in the scratch repo). Show it failing first (log).

## Commands
`bash scripts/selftest.sh`, `bash -n *`, `shellcheck *`, `python3 *`, `bash *`, `git add`, `git commit`, `git log *`, `git show *`, `git worktree *`, `git rev-parse *`. One command per Bash call.

## Done when
- The new checks fail before and pass after (logs); `bash scripts/selftest.sh` passes (log).
