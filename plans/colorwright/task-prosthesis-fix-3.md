# Prosthesis fix round 3: the two unmarked prostheses (Blazer 1, Shirt 2)

**Track: light.**

You are continuing on branch `agent/cw-prosthesis`. Patrick, 2026-09-26: "blazer (or blazer 2?) shows a below the knee prosthesis on the left leg. it has two color regions, one is black by default and the other changes with the skin tone." That is **`blazer/outfit/blazer-1`** (Outfit 1), not blazer-2: a render of all 23 outfits shows four with a prosthesis. `blazer-2` and `shirt-1` have `prosthesis` roles; **`blazer-1` and `shirt-2`** have prostheses drawn with no prosthesis role: a black socket (outfit ink or pants) and a pylon in the `skin` region, so the pylon follows the Skin control.

Give `blazer-1` and `shirt-2` the same scheme as the other two: **Color 1 (`prosthesis`) = the socket, Color 2 (`prosthesis-2`) = pylons, rings, joints**, nothing on the prosthesis following Skin, and the leg's own skin cut away under it (as round 2 did). Defaults: keep today's look (socket black `#000000`-ish as drawn, Color 2 `#4A4A4A`), so nothing changes until a colour is picked. Extend `pipeline/split_prosthesis_colour.py` (pinned zones for the two new items), the manifest for those two items, the tests (a point in each part, and Skin changes no prosthesis pixel), and `scripts/prosthesis-colours-e2e-check.js` (run it on `--port 8790`).

Also update `pipeline/README.md`'s line for `split_prosthesis_colour` (it predates round 2). Leave blazer-2's thin skin strip on the trousers above the socket as it is.

Commands you may run: `node ...`, `npm test ...`, `backend/.venv/bin/pytest ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, git add/commit. Scratch under `build/`. One command per Bash call.

## Done when
- All four prosthesis outfits: Skin changes no prosthesis pixel in the real app; Color 1 changes only the socket; Color 2 only the mechanical parts (one render of all four, skin green, Color 1 red, Color 2 blue).
- The unit tests and the e2e check pass; report files and exit codes.
