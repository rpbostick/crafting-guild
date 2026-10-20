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

## Carried from the cg-lessons-dedupe review (suggestions; do them where the code is yours to touch)
- `scripts/lessons-check.py:133`: Rule 15 and the precheck FLAG: this is a false alarm. scripts/selftest.sh:244-249 runs the check, but through the `$WS/` path, so precheck's scan misses it. Consider teaching precheck to match `$WS/scripts/<name>` so it does not flag this again.
- `scripts/lessons-check.py:129`: `--removed` always exits 0, even when sentences fall below COVERED. That is fine for a display tool. If it ever becomes a gate, return `low > 0`. With fewer than three paths, `removed(*args[1:4])` raises a TypeError instead of printing usage.
- `scripts/lessons-check.py:60`: The check is lenient, as the builder noted. Any digit or mid-sentence capitalised word (for example 'SIGKILLed', 'Metro', 'Code' from 'VS Code') counts as a specific, so a full restatement that adds one date still passes. This matches the task's definition. Worth a line in the docstring that the check only catches bullets that add nothing.
- `MODIFYING.md:36`: The path `scripts/lessons-check.py` is wider than the 24-character column, so the description starts on the same line and breaks the table's alignment. This is cosmetic.
- `lessons/orchestrator.local.md:40`: This bullet also changes a fact, from 'written by the orchestrator right after dispatch' to 'written by dispatch from the conf's WORKTREE_ENV'. That is consistent with the cg-grants-env merge, but the commit message does not mention it.
