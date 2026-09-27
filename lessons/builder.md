# Lessons: builder

Appended to every builder prompt. Keep under 25 lines.

- One command per Bash call; compound commands are denied and cost a turn.
- Never install packages in the worktree; the environments are shared symlinks.
- Symlinked directories: Read and Glob work, `ls` does not.
- An absolute path must start with your worktree root, not the main checkout and not another repo.
- Run the suite in the foreground with a long timeout, not in the background; a background run can end your turn before the result exists.
- The head geometry class of bug (colorwright): a value computed from a raw number that assumes a shared viewBox starts at 0,0 recurred four times. When you fix one instance of an assumption, grep for the others before committing.
- Record the exit status of each test suite, not only counts.
- Files under `.claude/` in the project cannot be edited headlessly (Claude Code treats them as sensitive). Do not retry; report the exact change as an open question.
- Before committing any log, replace the worktree path and the home directory (including pytest's `/tmp/pytest-of-<user>`) with repo-relative paths or placeholders, and end the log with the command's `exit N`. Three reviews blocked on this in one day.
- Commands longer than 10 minutes can't finish in one foreground call, and a backgrounded one dies when your run ends. Split long test or render runs into parts.
