# Crafting Guild: grants and a worktree env file for recurring builder denials

Track: light

Builders lose a turn on each denied call. In the last month the recurring ones were `git check-ignore` (3), `git -C <path inside the worktree>` (3), `env VAR=... <cmd>` to run tests that need environment variables (2; skate-mario's SMB tests need RETROWRIGHT_* variables, which the orchestrator has been writing into each worktree's git-ignored `.env.local` by hand), and `git show <ref>:<path> --output=...` (2). Read `scripts/dispatch.sh` (the grant lists and how the worktree is set up), `projects/README.md` and `projects/example.conf.sample` first.

## Build
- Grant `git check-ignore *` to every builder (read-only).
- `git -C <dir>`: grant only when the path is inside the builder's own worktree; if Claude Code's rule syntax cannot express that safely, do not grant it and add a line to `lessons/builder.md` saying to run git from the worktree root with a pathspec instead. Say which you chose and why.
- A project conf key `WORKTREE_ENV_FILE` (a file name, e.g. `.env.local`) and `WORKTREE_ENV` (an array of `KEY=value` lines): dispatch writes them into that file in each new or reused worktree, refuses if the file is not git-ignored there, and never overwrites a file with different content without a warning. Set it in `projects/skate-mario.conf` with the three RETROWRIGHT_* values its `TEST_CMD` uses. Document both keys in `projects/README.md` and the sample conf.
- `lessons/builder.md`: name `git show <ref>:<path>` plus the Write tool (already there) as the way to save a file from git; keep it, and check it is in the prompt.

## Tests
`scripts/selftest.sh`: the dry-run prompt's grants include `Bash(git check-ignore*)`; a scratch project with `WORKTREE_ENV` gets the file written with the lines in its worktree, and dispatch refuses when the file is not ignored; the `git -C` choice is covered (a grant pattern test or the lesson line in the prompt). Show them failing first (log).

## Prior art
Claude Code permission rules (`Bash(cmd:*)`/prefix matching) as dispatch already uses them; Vite's `loadEnv` reads `.env.local` (skate-mario's vitest.config.ts).

## Commands
`bash scripts/selftest.sh`, `bash -n *`, `shellcheck *`, `python3 *`, `bash *`, `git add`, `git commit`, `git log *`, `git show *`, `git worktree *`, `git rev-parse *`. One command per Bash call.

## Done when
- The new selftest checks fail before and pass after (logs); `bash scripts/selftest.sh` passes (log).
