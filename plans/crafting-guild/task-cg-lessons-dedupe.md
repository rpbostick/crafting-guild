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

## Carried from the cg-grants-env review (suggestions; do them where the code is yours to touch)
- `scripts/selftest.sh:160`: Rule 2: the 'before' evidence for the home-path check (.ws-evidence/before-selftest-homepath.log) only shows exit 127 because home_path_leaks did not exist yet. It never ran the old merge.sh line or the old precheck grep against private/x. The test does exercise the new code path. A before run that inlines the old diff|grep line and shows it flagging private/x would prove the test can fail on behaviour, not just on a missing function.
- `scripts/precheck.sh:54`: Precheck rule 18 used to skip every attribution_exempt path (LICENSE, manifests, CREDIT_PATHS). It now checks those files for home paths. This matches merge.sh, which is the stated intent. The builder disclosed the change, but neither the commit message nor MODIFYING.md says that review and merge will now both flag a home path in a LICENSE or CREDIT_PATHS file. Worth one line in MODIFYING.md.
- `projects/skate-mario.conf:11`: Dispatch refuses unless .env.local is git-ignored in the skate-mario worktree. I could not read skate-mario's .gitignore (it is outside the worktree), and no evidence shows a dispatch for skate-mario succeeding with this conf. The failure is loud, with a clear message, but a dry run for skate-mario saved under .ws-evidence would confirm the conf works before the next dispatch.
- `projects/skate-mario.conf:12`: Rule 18 (not blocking here): this tracked conf adds absolute home paths. It is exempt because projects/*.conf is in the workspace's ATTRIBUTION_EXEMPT, and confs are documented as private and left out of a published copy. The existing TEST_CMD line already has the same paths. Make sure RELEASE_PATHS keeps excluding projects/*.conf.
- `scripts/dispatch.sh:96`: The backup file name uses a UTC timestamp (date -u). That is harmless for an evidence file name, but it differs from the local-date convention (WS_TZ) used elsewhere, so the backup's time won't match the logs, which use local time.
