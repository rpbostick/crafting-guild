# Prosthesis fix round 1: the mechanical parts are Color 2

**Track: light.**

You are continuing on branch `agent/cw-prosthesis`. Patrick looked at the preview, 2026-09-26, and chose: **Prosthesis Color 2 = the mechanical parts (pylon, knee joint, rings; black today) on both outfits; Color 1 = the socket/shell.** The thin pylon gap you found on Blazer-2 joins Color 2. Use one command per Bash call.

Commands you may run: `node ...`, `npm test ...`, `backend/.venv/bin/pytest ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, git add/commit.

## Do
- On `blazer/outfit/blazer-2` and `shirt/outfit/shirt-1`, the prosthesis's mechanical parts that are drawn as solid black fill today (the pylon, the knee joint, the rings/clamps; not the outline strokes around shapes) become `prosthesis-2` fills, default a dark grey that reads as metal (e.g. `#4A4A4A`), with the outline strokes staying `outline`. Find them in the outfit SVGs and the Sketch layers as you did for the gap; if a mechanical part is only ink (a stroke with no fill), cut a fill for it the way the hair split cuts solid ink (`pipeline/split_hair_from_head.py`), or say it can't be done cleanly.
- Shirt-1 gains `prosthesis-2` too.
- Update your pipeline step, the manifest for those two items, and the tests (a point in each part).
- One render: skin green, Color 1 red, Color 2 blue, both outfits.

## Done when
- The unit tests covering the change pass (and the new points failed before); report the files you ran and their exit codes.
- The render is committed.
