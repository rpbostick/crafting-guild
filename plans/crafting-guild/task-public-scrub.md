# Make the workspace publishable as Waystation Guild

Track: light

This repository (an orchestration workspace for Claude Code: `bin/ws`, `scripts/`, `agents/`, `checklist.md`, `schema/`) will be published as a new public repository, **Waystation Guild**, through `ws release` with `RELEASE_PATHS` (scripts/release.sh, 2.3.9). This repository stays the private working copy: `plans/`, `projects/`, `runs/`, `state/`, `reports/` and the private files named below never go public. Your job: make the public paths read as a tool anyone can use, and keep the operator's personal material in private files that the tool still loads. Read `release-audit.md` (the policy), `README.md`, `CLAUDE.md`, `MODIFYING.md`, `config.sh`, `lessons/*.md`, `agents/*.md`, `checklist.md`, `scripts/dispatch.sh`, `scripts/review.sh`, `scripts/cold-start.sh`, `scripts/release.sh` and `scripts/selftest.sh` first.

## What to find
Run `git grep -n -i -E "patrick|patrickb|/home/|rpbostick|bike|figurewright|colorwright|toybox|skywright|chargen|pen-paper|reactbits|20[0-9]{2}-[0-9]{2}-[0-9]{2}"` over the public paths listed under Done when. About 30 lines outside `CHANGELOG.md` and `lessons/` match: mostly comments citing an incident ("on 2026-10-08 that kept an old toybox.js …"). Each becomes a plain technical reason in the present tense, keeping the number or mechanism that makes it convincing ("release zips have fixed timestamps, so rsync's size-and-time check skips a rebuilt file of the same size"). Example names in docs become generic (`my-app`, `my-site`).

## Behaviour
- **Private overlay files, loaded when present:** `lessons/<role>.local.md` beside each `lessons/<role>.md`, and `CLAUDE.local.md` (Claude Code loads it by itself). `scripts/dispatch.sh` and `scripts/review.sh` paste `lessons/<role>.local.md` after `lessons/<role>.md` when it exists; `scripts/cold-start.sh` names both in its lessons line and applies the line cap to each. Add a selftest check that a `.local.md` lesson reaches the dry-run prompt (dispatch `--dry-run` prints enough to check, or add a flag that prints the prompt).
- **Lessons:** each `lessons/<role>.md` becomes generic advice any user benefits from, with the anonymised numbers kept (memory caps, grants, usage limits, worktree links, merge timing). Every dated, named or operator-specific line moves, unchanged, into `lessons/<role>.local.md`. Nothing is lost: the two files together hold every current line's content.
- **CLAUDE.md** stays the orchestrator's guide, generic ("the operator"). Operator-specific preferences move into `CLAUDE.local.md`: asking through AskUserQuestion with multi-select checkboxes and a recommended option first, opening previews in Firefox, port ranges, the budget habits, anything naming a person or project.
- **Defaults as config:** where a preference is a setting rather than prose (the preview browser command, the preview port ranges), add it to `config.sh` with a comment, default to today's value, and use it where the scripts or docs hard-code it. Do not invent settings the scripts would not read.
- **README.md** becomes the public README for Waystation Guild: what it is (one orchestrator session plans, dispatches headless builders into git worktrees, reviews and merges with a test gate), requirements (bash, git, Claude Code CLI, systemd user scopes optional, gh optional), install, `ws init`, the loop, the commands (`bin/ws help`), configuration, and what stays private by design (plans, runs, project confs, `*.local.md`). The command stays `ws`; the private repository keeps its folder name.
- **CHANGELOG.public.md:** a fresh changelog with one entry for the current `VERSION`, "first public release", summarising the features in present tense. `CHANGELOG.md` stays as is (private).
- **release-audit.md:** generic (the operator, not a name); the specific credits it lists move to the private overlay.
- **projects/agentic-workspace-v2.conf:** add `RELEASE_PATHS` with exactly the public paths: `bin`, `scripts`, `agents`, `schema`, `checklist.md`, `config.sh`, `lessons/builder.md`, `lessons/orchestrator.md`, `lessons/reviewer.md`, `CLAUDE.md`, `MODIFYING.md`, `README.md`, `LICENSE`, `release-audit.md`, `projects/README.md`, an example conf (`projects/example.conf.sample`, written by you from `ws init`'s template), `.gitignore`, and `CHANGELOG.public.md=CHANGELOG.md`. Make `.gitignore` also ignore `*.local.md`? **No**: the private repository tracks them; leave `.gitignore` as is and say so in the README (users may ignore them themselves).
- `bin/ws release --project agentic-workspace-v2 --dry-run` cannot run without a `public` remote; do not add one. Instead check the public tree by building it the way release.sh does and grepping it (see Tests).

## Prior art
None needed: a docs and comments pass plus a small loader change.

## Tests
`bash scripts/selftest.sh` passes, including the new `.local.md` check. A public-tree scan: build the RELEASE_PATHS tree from your branch's last commit in a temporary index (as release.sh does) or list the files with `git ls-tree -r --name-only HEAD -- <paths>`, and run the grep under "What to find" over those files' contents: zero matches except the LICENSE copyright line and the `rpbostick` GitHub URL if the README links the public repository. Save the scan's output in `.ws-evidence/`.

## Commands
`bash scripts/selftest.sh`, `git grep`, `git ls-tree`, `git mv`, `git rm`, `git add`, `git commit`, `bash -n`, `shellcheck` (if installed). One command per Bash call.

## Done when
The public paths read as a generic tool named Waystation Guild with no personal or journey text (the scan shows it); every removed personal line lives on in a `.local.md` file the tool loads; `config.sh` holds the preference settings that scripts read; `CHANGELOG.public.md` and `RELEASE_PATHS` exist; the selftest passes.
