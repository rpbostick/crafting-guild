# colorwright: comments state reasons, not people or dates
Track: light

Many comments and docs in this repo attribute a choice to a person and a date. For example, in `frontend/app.js`: "the operator, 2026-09-13: 'you could start with…'". Rewrite each one as the plain technical reason, keeping what a future editor needs: what the code does, why, and "Deliberate:" where a choice must not be "fixed" back.

## Find them
`git grep -nIiE 'patrick|bostick|the operator|operator[,:'"'"'s]|orchestrator|builder|reviewer|fix round|spike'` over the tracked tree, plus dated attributions: a date next to asked, said, decided, wanted, approved, reported, or a quote. Dates that are data (test fixtures, API values, changelog-style version dates) stay.

## Rewrite
- A quoted request becomes its reason. For example, "the operator, 2026-09-13: 'start with walking'" becomes "A fresh session starts on the walking body, so the page never opens on an empty placeholder."
- "per the operator", "as agreed" or "plan 20 step 2b" become the fact itself, or are dropped when the code already says it.
- Test names and assertion messages follow the same rule.
- Docs (`README.md`, `docs/`): the same. Delete journal-style sections (histories, dated decision logs) if nothing links to them. Otherwise rewrite them in the present tense.
- **`scripts/evidence/`:** it is test output written by the e2e scripts. Remove it from git (`git rm -r --cached scripts/evidence`) and add it to `.gitignore`. The files stay on disk.
- Change no behavior. Rename identifiers only if a name itself carries a person.

## Check
- The grep above finds nothing except legitimate uses (a `builder` in code meaning something else, and so on). List each one kept, with its reason, in `.ws-evidence/kept.txt`.
- `node --test frontend/tests/` passes.
- `bash scripts/build-static.sh` ends "leak check: clean".

## Commands
One command per Bash call: `git grep …`, `git rm -r --cached …`, `node --test …`, `bash scripts/build-static.sh`. Do not run `npm install`.

## Done when
No tracked file attributes anything to a person or a dated conversation. `scripts/evidence/` is untracked. The tests and the static build pass.
