# pipeline/README.md as a current reference

**Track: light.** Docs only; no code or catalog changes.

colorwright is tagged `v1.0` and will be the foundation of a new project. `pipeline/README.md` (411 lines) still reads partly as a dated log: "What's where" (lines 52-322) describes modules by when and why they were added, and "Real findings from running this against all 30 files" (323-398) is history from the first build, mentioning modules that were since deleted. Rewrite it as a reference a newcomer can use; move history out, don't lose it.

## Do
1. Keep **"Run it"** as the authoritative, ordered chain (check each command's module exists: `git grep`/`ls pipeline/`). One line per step: what it does now, what it needs, what must run before it.
2. Replace "What's where" with a **module reference**: one short entry per module that exists in `pipeline/` today (and the pinned data files: `head_hair_regions.json`, `head_styles.json`, `hair_item_fixes.json`, `hat_hand_regions.json`, ...): purpose, inputs, outputs, the manifest fields or colour roles it writes, and its test file. Present tense, no dates, no "the operator said" (the decisions stay in history).
3. Add a short **"Concepts"** section: body styles and `canonical_viewbox`, atoms and the atom→item transform, slots, colour roles, `option_thumbnail_viewbox`, hats' `hides_hair` / `hair_cover` / `hair_below_rim` / `hair_edges`, head styles and hair items; each in two or three sentences, pointing to the module.
4. Move the dated material ("Real findings", the history paragraphs in the old "What's where", and "What this does NOT cover" if it's historical) to `docs/pipeline-history.md` unchanged, with a one-line pointer from the README. Keep a current "Known gaps" section in the README if any still apply (check each).
5. Every module, file, field and command named in the new README must exist: list the `git grep`/`ls` checks you ran and their results in your final summary.

Commands you may run: `git grep ...`, `ls ...`, `git status`, `git diff ...`, `pipeline/.venv/bin/python3 -m ... --help` (to check a module's usage), git add/commit/mv. One command per Bash call.

## Done when
- `pipeline/README.md` is a current reference (Run it, Concepts, Module reference, Known gaps, pointer to history); `docs/pipeline-history.md` holds the moved text.
- No name in the README is missing from the repo.
