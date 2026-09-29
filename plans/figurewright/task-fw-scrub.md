# figurewright: reports and vendored tests state reasons, not people or dates
Track: light

Some tracked files attribute choices to a person or a date: `spike/**/REPORT.md` ("Questions for Patrick", "Patrick's decision"), `spike/body-refs-2/proto/body.ts`, and `vendor/colorwright/tests/` ("the operator, 2026-…"). Rewrite each as the plain technical reason.

**Scope:** `spike/`, `vendor/colorwright/`, `docs/` and `README.md` only. **Do not touch `src/`, `test/` or `scripts/`**, because another branch is changing them.

## Find them
`git grep -nIiE 'patrick|bostick|the operator|operator[,:'"'"'s]|orchestrator|fix round'`, plus dated attributions: a date next to asked, said, decided, approved, wanted, or a quote.

## Rewrite
- "Questions for Patrick" becomes "Open questions". "Patrick's decision (stylised)" becomes "a stylised choice, past the data". "Patrick approves it" becomes "approved on a contact sheet".
- A quoted request becomes its reason. Keep measurements, figures and conclusions exactly.
- `vendor/colorwright/`: comments and test names only, with the same rewrites colorwright's own copy gets. Keep the NOTICE and license text.
- `LICENSE` keeps its copyright line.

## Check
The grep finds nothing in scope. `npx jest --runInBand test/colorwright` passes, since it runs the vendored tests. List anything kept, with its reason, in `.ws-evidence/kept.txt`.

## Commands
One command per Bash call: `git grep …`, `npx jest --runInBand test/colorwright`. Do not run `npm install`.

## Done when
Nothing in scope names a person or a dated conversation, and the vendored tests pass.
