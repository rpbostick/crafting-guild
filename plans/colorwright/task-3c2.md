# 3c-2: keep face, facial hair, hat and accessories when the body style changes

Patrick's interface standard (2026-09-24, point 8): choices that can carry over, do, when the body style changes. Today `equipOutfit` in `frontend/logic.js` (about line 669) keeps the head's style across a body-style switch (`headIdForFamily` / `sameStyleInFamily`) but resets face to the first face and facial hair, hat and accessories to None. The comment there says carrying them is this step. Since plan 18 step 6 (`1ce248a`) every pose has all 16 facial-hair and 8 accessory styles, and since the hats step every pose has the Hat slot, so the same style exists on the new body style for almost everything. Use one command per Bash call.

Commands you may run: `node ...`, `npm test ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `git grep ...`, `bash -n ...`, and git add/commit.

**Browser ports: 8796-8799 only.** Another builder runs on 8790-8795.

## Build
- On a body-style change, face, facial hair, hat and accessories each keep the **same style** on the new body style when it exists (match the way `sameStyleInFamily` matches heads). When it doesn't, face falls back to the new style's first face and the others to None, as today. A None stays None.
- The colours picked for those parts carry too, role by role, where the new item has the same role (as head colours do via `carriedHeadColors`); a role the new item lacks gets its default. Outfit colours still reset (unchanged). The one Skin control is unchanged.
- Nothing else changes: saved looks, the rows, ordering, the head carry-over.
- Update the comment in `equipOutfit`, and `README.md` / `plans/requirements.md` where they describe what a body switch resets.

## Tests
- Unit tests in `frontend/tests/` for each slot: same style carried; missing style falls back; None stays None; a picked colour carries; a role the new item lacks gets its default. Show they fail against master's `logic.js` (save the output as teeth under `scripts/evidence/3c-2/`).
- A browser check `scripts/carry-over-e2e-check.js` using `scripts/e2e-app.js` (`--port 8796`): in the real app, pick a face, a facial hair with a colour, a hat with a colour and an accessory on one body style, switch through all 9 body styles, and assert each is still the same style and colour. Show it fails against master's frontend (`e2e-app.js` may need a `--frontend-rev` option like `rows-e2e-check.js` has; add it if so).
- Screenshots of the preview before and after one switch in `scripts/evidence/3c-2/`.

## Carried review suggestions (small, same PR)
- `scripts/thumbnail-framing-e2e-check.js:8`: the header says close-ups are "at least 40 px wide"; the constant is 20. Make the comment match.
- `scripts/evidence/3b/README.md`: two rows are numbered 9 (renumber; the re-run against master came first; fix the text citing "run 9"); add `e2e-after-20px.log` to its Files table; line 68 reads as contradicting the 20 px floor: say 40 px was the builder's state before Patrick's decision.

## Evidence
`scripts/evidence/3c-2/README.md`: every command, result and exit code; repo-relative paths only. Full `bash scripts/run-all-tests.sh` output in `scripts/evidence/3c-2/unit-tests.log`.

## Leave alone
`pipeline/`, `assets/`, `backend/` `.claude/`. Another builder is changing `pipeline/` and `assets/catalog/manifest.json` at the same time.

## Done when
- Unit tests and the e2e check pass and were shown failing against master.
- `git diff master --stat -- pipeline assets backend` is empty.
- `bash scripts/run-all-tests.sh` exits 0 and its log is committed.
