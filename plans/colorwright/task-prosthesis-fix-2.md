# Prosthesis fix round 2: the part that follows Skin; pylons to Color 2

**Track: light.**

You are continuing on branch `agent/cw-prosthesis`. Patrick looked at the preview (served from this worktree on :8802), 2026-09-26:
1. **"blazer prosthesis needs its fleshtone part changeable too."** Asked which part, he said: **it follows the Skin control**. Your cairosvg renders with skin green showed no green on the prosthesis, so the part is found only in the real app: something on `blazer/outfit/blazer-2`'s prosthetic leg changes when the Skin control changes. Find it **in the browser** (start the app with `scripts/e2e-app.js` on `--port 8790`, pick Blazer outfit 2, set Skin to a strong green, screenshot the leg, compare). It may be a shape with the `skin` role, a shape the frontend colours by the head/figure skin, or the leg's skin showing through a gap. Make it a prosthesis colour, not skin: if it's part of the socket, Color 1; if it reads as a liner or cover of its own, say so and put it in Color 1 for now. Check shirt-1 the same way.
2. **Pylons and Blazer's teal ring to Color 2** (Patrick: yes): move those subpaths from `🎨-prosthesis` into `🎨-prosthesis-2` by subpath, as you proposed. Color 1 = socket only; Color 2 = everything mechanical.

Commands you may run: `node ...`, `npm test ...`, `backend/.venv/bin/pytest ...`, `pipeline/.venv/bin/python3 ...`, `pipeline/.venv/bin/pytest ...`, `git grep ...`, git add/commit. Write scratch files under `build/`, not `/tmp`. Use one command per Bash call.

## Done when
- In the real app, changing Skin changes no pixel of either prosthesis (screenshot pair committed); Color 1 changes only the socket, Color 2 only the mechanical parts, including the pylons and ring (one render).
- The unit tests covering the change pass (new points failed before); report the files and exit codes.
