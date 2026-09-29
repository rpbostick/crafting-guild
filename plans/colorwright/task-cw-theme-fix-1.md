# colorwright: theme round 2 (host mode, real static check)

Continue branch `agent/cw-theme`; read your commits and `.ws-evidence/` first. The review said merge. `bash scripts/build-static.sh` is granted now (the orchestrator ran it on your branch: "leak check: clean").

## Host mode
The static build is published inside a host site that draws its own controls and an animated backdrop behind the page. The host signals this with attributes on `<html>`, set before the page's scripts run:
- **`data-host-controls`**: hide the page's own theme switch. The theme still follows `data-theme` on `<html>`, which the host's switch changes; it writes the same `theme` key. Keep about 280 px of room at the top right, so the host's controls never cover the title or the status bar at 360 px wide or at desktop width.
- **`data-host-backdrop`**: `body` and the page background become transparent, so the backdrop shows around the panels. Each panel stays **opaque in the middle**, but its outer **~1 cm (38 px)** is slightly translucent, fading inward from about 70% opacity to fully opaque. The panels are the rows, the colours box, the status bar, the preview column's controls and the saved-looks list. Use a CSS mask or layered gradients (a sketch: the panel background drawn by a `::before` with `mask-image` gradients on all four edges, the content above it). The art canvases (the preview figure and the tiles) stay fully opaque and light. It must work in both themes.
- Without either attribute, nothing changes (the light and dark screenshots match round 1).
- Add a browser check that sets both attributes on a coloured page background (a stand-in for the backdrop). Screenshot it in light and dark, plus a 2× close-up of one row's edge showing the translucent band.

## Carried from the review
- Re-run `bash scripts/build-static.sh`, then `node scripts/theme-e2e-check.js --static` on the **real minified build** (use a port in 8790–8799). Save the log and the screenshots.
- In light, `--text-faint` on `--row-empty-bg` reaches AA (about `#6e7781`; measure it). The contrast test asserts it.
- The contrast test's "no colour outside the token blocks" check also catches named colours (`white`, `black`, `grey`/`gray`, and so on).

## Commands
One command per Bash call: `bash scripts/build-static.sh`, `bash scripts/static-leak-check.sh`, `node …`, `node --test …`, `npm test`, `backend/.venv/bin/pytest …`, `python3 …`, `curl …`. Do not install packages. Nothing dated or personal in comments.

## Done when
Host mode works as described, with screenshots. The static build is leak-clean, and the browser check passes on the real build. The contrast tests cover the new pairs.
