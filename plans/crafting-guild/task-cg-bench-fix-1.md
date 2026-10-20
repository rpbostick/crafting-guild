# Crafting Guild: the bench's selftest passes inside the merge gate

Track: light

This branch was reviewed `merge`, but its merge failed: `ws merge` holds `runs/crafting-guild/merge.lock` while it runs the project's tests (`bash scripts/selftest.sh`), and `scripts/bench.sh` (line 88) waits while any `runs/*/merge.lock` is held. So inside the gate, the selftest's bench checks ("bench merge wait", "bench run records", "bench opaque names and cleanup", "bench resume") wait on the very merge that is running them, and fail. Your own runs passed because no merge held a lock then. The merge log is `runs/crafting-guild/cg-bench.merge-tests.log` in the workspace (read it with the Read tool).

## Fix
- The set of lock files `bench.sh` waits on comes from one place that the selftest can point at a scratch directory (e.g. `WS_BENCH_LOCKS`, a glob defaulting to `$WS/runs/*/merge.lock`). The selftest's bench checks use a scratch glob, and the "waits on a held lock" check holds a lock in that scratch set.
- Keep the real behaviour: outside the selftest, the bench still waits on every project's merge.

## Tests
Reproduce the gate: run `bash scripts/selftest.sh` while holding `runs/crafting-guild/merge.lock` the way merge.sh does (`flock` on it in a wrapper you run through ws-run, e.g. `flock runs/crafting-guild/merge.lock bash scripts/selftest.sh` from the worktree, whose runs/ is its own; if the worktree has no runs/crafting-guild, create the lock file under .ws-evidence/scratch and point the glob at it in a second run). Show the bench checks failing that way before the fix and passing after (logs). `bash scripts/selftest.sh` passes plain too (log).

## Commands
`bash scripts/selftest.sh`, `flock *`, `bash -n *`, `shellcheck *`, `python3 *`, `bash *`, `git add`, `git commit`, `git log *`, `git show *`, `git status *`, `git worktree *`, `git rev-parse *`. One command per Bash call.

## Done when
- The bench checks fail with a held merge lock before the fix and pass after (logs); `bash scripts/selftest.sh` passes (log).
