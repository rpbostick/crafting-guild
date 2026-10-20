# Crafting Guild: the private orchestrator lessons hold only what the shared file does not

Track: light

`lessons/orchestrator.local.md` (41 lines) was seeded as a dated copy of `lessons/orchestrator.md` (40 lines), and both load into every orchestrator session, so most lessons are read twice. The local file should hold only the installation's specifics: names, dates, project incidents and lessons with no shared counterpart. Nothing may be lost.

## Build
- `scripts/lessons-check.py`: pairs each local bullet with the shared bullet it restates (by its opening words and overlap; print the pairing and a similarity score) and reports local bullets with no shared counterpart. Used to review the change and kept as a check.
- Rewrite `lessons/orchestrator.local.md`: a bullet that restates a shared one is cut down to the specifics the shared one lacks (the incident, date, project or number that makes it concrete), or removed when it adds nothing; a bullet with no counterpart stays whole. The header says the file holds only what the shared file does not.
- Same for `lessons/builder.local.md` and `lessons/reviewer.local.md` if they exist.

## Tests
`scripts/selftest.sh` runs `lessons-check.py` over the real files and fails when a local bullet restates a shared one without adding specifics (high similarity and no date, number or project name of its own). A fixture test shows it catches a duplicate and passes a specific. Put the before/after pairing in `.ws-evidence/` so the reviewer can confirm every removed sentence is present in the shared file or kept as a specific.

## Prior art
Python's `difflib.SequenceMatcher` for the similarity score; no new dependency.

## Commands
`bash scripts/selftest.sh`, `bash -n *`, `shellcheck *`, `python3 *`, `bash *`, `git add`, `git commit`, `git log *`, `git show *`, `git worktree *`, `git rev-parse *`. One command per Bash call.

## Done when
- `.ws-evidence/` holds the before/after pairing; every removed local sentence is shown present in the shared file (log).
- The new checks fail before and pass after (logs); `bash scripts/selftest.sh` passes (log).
