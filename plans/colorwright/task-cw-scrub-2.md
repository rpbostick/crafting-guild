# colorwright: finish the attribution scrub
Track: light

You are continuing `agent/cw-scrub`. Finish what your first run left open, with the same rewrite rule: state the reason as a fact, use "Deliberate:" where a choice must stay, and never name who or when.

1. **`pipeline/tests/*.py` and pipeline modules.** Rewrite the 42 remaining attributed lines. While you're there, rewrite the ~40 lines of plain process wording ("the spike found", "fix round", "hats round N"): say what the code or test establishes. Run the tests with `pipeline/.venv/bin/pytest -q pipeline/tests` and `backend/.venv/bin/pytest -q backend/tests`. These are granted; plain `python3` and `pytest` are not.
2. **`plans/` journal files.** The workspace has archived them. `git rm` these: `plans/requirements.md`, `plans/requirements-checkpoint.md`, `plans/backlog-plan-1.md`, `plans/builder-cw-extraction-plan.md`, `plans/open-peeps-research-2026-09-11.md`, `plans/session-checkpoint-2026-09-13-geometry-sweep.md`.
   - Keep the `plans/*-spike` and research directories that code or the manifest reads.
   - Every comment, docstring or doc that cites a removed file loses the citation. Keep its reason, stated in place.
3. **`scripts/evidence/` inputs.** `scripts/hair-colour-e2e-check.js:68` reads `scripts/evidence/hair-colour-5b1/sample-points.json`. Move that file (and any other file a script or test reads from `scripts/evidence/`; grep for `evidence/` in `scripts/`, `frontend/`, `backend/` and `pipeline/`) into a tracked fixtures directory, `scripts/fixtures/`. Point the readers at it.
4. **Citations of untracked evidence.** About 90 comments cite `scripts/evidence/...` paths. Drop each citation. Where the fact matters, point to the test that pins it instead.
5. **`node --test`.** Use `node --test "frontend/tests/*.test.js"`, as your first run found.

## Check
- `git grep -nIiE 'patrick|bostick|the operator|operator[,:'"'"'s]|orchestrator|fix round'` finds nothing outside `.ws-evidence/kept.txt`'s list.
- `git grep -n 'scripts/evidence/'` finds only `.gitignore`.
- The frontend, pipeline and backend tests above pass. `bash scripts/build-static.sh` ends "leak check: clean".

## Commands
One command per Bash call: `git grep …`, `git rm …`, `git mv …`, `node --test …`, `pipeline/.venv/bin/pytest …`, `backend/.venv/bin/pytest …`, `bash scripts/build-static.sh`. Do not install anything.

## Done when
No tracked file attributes anything to a person, a dated conversation or this process's rounds. The journal is gone from `plans/`. Every file a script reads is tracked. The tests pass.
