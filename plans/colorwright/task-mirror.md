# Mirror the avatar (look left / look right)

Patrick, 2026-09-26: "i eventually want to be able to have the avatar mirror along the vertical axis (look left, look right), which will allow the prosthesis to be on either side." Use one command per Bash call; anything over 10 minutes in parts; scratch under `build/`. Browser ports 8796-8799.

Commands you may run: `node ...`, `npm test ...`, `bash scripts/run-all-tests.sh`, `backend/.venv/bin/pytest ...`, `backend/.venv/bin/python ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, `git status`, `git diff ...`, git add/commit/rm/mv.

## Build
- A **Facing** control (Left / Right, default as drawn today) near the preview. Mirroring flips the **whole figure** as one: one `transform="scale(-1,1)"` (about the figure's vertical centre) on the preview's figure group, so every layer, mask and clip (hat `hair_cover`, the Hijab clip, facial hair masks) flips with it. No per-item art changes.
- Row thumbnails stay as drawn (they're for picking items), unless a mirrored thumbnail reads better for outfits and bodies; say which you chose.
- Stored browser state and **saved looks** keep the facing: a `mirrored` boolean on the look (`ALTER TABLE look ADD COLUMN mirrored`, default false, as `hat` and `hair` were added), sent and loaded by the API; old looks load unmirrored. Carried across body, head, hair and outfit switches.
- Anything that exports or renders the figure elsewhere (screenshots, a download, the backend) follows the flag; list what you checked.

## Tests (shown failing before)
- Frontend unit: the control toggles the flag; the preview group gets the transform; state and saved-look round trip; old state defaults to unmirrored.
- Backend: the migration adds `mirrored`; old looks load false; save and load keep it.
- e2e (`--port 8796`): the mirrored preview is the pixel mirror of the unmirrored one (within antialiasing), with a hat, the Hijab, facial hair and a prosthesis outfit; the flag survives a reload and a saved-look load.

## Done when
- Tests pass and were shown failing first; a screenshot pair (left/right) of 2 poses with a prosthesis outfit and a hat.
- `bash scripts/run-all-tests.sh` (or its parts) exit 0, each exit code in its log.
