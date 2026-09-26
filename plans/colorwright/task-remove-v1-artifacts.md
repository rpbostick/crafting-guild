# Remove the agentic-workspace v1 artifacts from colorwright

Colorwright was built with agentic-workspace v1, which installed a per-commit review pipeline and committed its logs into this repo. That pipeline is retired (its git hook dispatchers are already disabled outside the tracked tree). Remove the tracked artifacts and fix the docs that describe them. Change nothing about the app, the pipeline or the tests.

## Delete with `git rm -r` (one path per command)
- `.claude/hooks/post-commit-review`
- `.claude/hooks/post-merge-tests`
- `.claude/skills/` (plan-checkpoint, detect-drift, verify-release)
- `reviews/checklist.md`
- `reviews/checklist-proposals.md`
- `reviews/test-log/` (all of it; about 43 files)
- `scripts/check-plan-retryable.sh` if it is tracked

## Keep
- `.claude/hooks/pre-commit` (a syntax check that still runs on every commit)
- `.worktree-links` (still used to link gitignored data into worktrees)
- `scripts/run-all-tests.sh` and everything under `scripts/` except the file named above
- everything else

## Then
1. `git grep -n` for each of these strings and fix every remaining reference in tracked files (README.md, backend/README.md, scripts/, plans/, docs): `post-commit-review`, `post-merge-tests`, `check-plan-retryable`, `checklist-proposals`, `reviews/checklist`, `reviews/test-log`, `plan-checkpoint`, `detect-drift`, `verify-release`, `agentic-workspace`. Where README.md describes the review process, replace that paragraph with two sentences: changes arrive on `agent/<name>` branches built by headless builders, are reviewed once per branch, and are merged only after `scripts/run-all-tests.sh` passes on the merged tree. Do not delete a plans/ document because it mentions v1; only fix the reference.
2. Run `bash scripts/run-all-tests.sh` from the worktree root, in the foreground. Save the full output to `test-output.txt` in the worktree root (untracked; do not commit it) and report its path, the pass and fail counts, and each suite's exit status.
3. Commit in two commits: first the deletions, then the doc fixes. Do not amend.

## Done when
- `git ls-files reviews .claude/skills` prints nothing, `git ls-files .claude` prints only `.claude/hooks/pre-commit`.
- `git grep -l -E "post-commit-review|post-merge-tests|checklist-proposals|reviews/test-log"` prints nothing.
- The test suite passes with the same counts as before the change.
