# Crafting Guild: the chain commits the suggestions it carries

Track: light

After a merge, `scripts/chain.sh` appends the review's suggestions to the next step's task file (the "Carry the review's suggestions" block near its end). Plans are tracked in the workspace repo, so that edit leaves a modified tracked file. When the project is the workspace itself (crafting-guild), that file is in the project's main checkout, and the next `ws merge` refuses: "has modified tracked files; commit or discard first". It stopped the efficiency chain twice on 2026-10-20.

## Fix
- Right after appending, commit just that file in the workspace repo (`git -C "$WS" commit -- <file>`, a message naming the step it came from), for every project, so plans stay committed. If the commit fails (another commit in progress, a hook), log it and stop the chain with the reason rather than going on to a merge that will refuse.
- Leave the automatic fix-round task files (`*-fix-auto-N.md`) as they are unless they cause the same refusal; say which.

## Tests
`scripts/selftest.sh`: a scratch workspace-as-project case (the project path is the workspace repo or a scratch repo holding the plans) where a carry happens; afterwards `git status --short -uno` in it is empty and the commit holds the carried section. Show it failing first (log).

## Prior art
The chain's existing `log`/`stop` helpers; `git commit -- <pathspec>` commits only that path.

## Commands
`bash scripts/selftest.sh`, `bash -n *`, `shellcheck *`, `bash *`, `git add`, `git commit`, `git log *`, `git show *`, `git status *`, `git worktree *`, `git rev-parse *`. One command per Bash call.

## Done when
- The new check fails before and passes after (logs); `bash scripts/selftest.sh` passes (log).
