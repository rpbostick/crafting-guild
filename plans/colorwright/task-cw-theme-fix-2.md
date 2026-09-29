# colorwright: theme round 3 (a "More demos" link, review items)

Track: light

Continue branch `agent/cw-theme`; read your commits and `.ws-evidence/` first. The review of 131dd72 said merge; this round adds one feature and the review's suggestions.

## A link back to the demo site (Patrick, 2026-09-29)
- In **static mode only** (the published build), add a **"← More demos"** link to `https://rpbostick.github.io/` at the bottom of the page, in the site notice below the Open Peeps credit. The skywright and figurewright demos already have one. Backend mode shows nothing new.
- Put the URL in the static `config.js` that `build-static.sh` writes, next to the base path, not hard-coded in `app.js`.
- In host-backdrop mode, give the footer (credit, notice, link) the same opaque panel with a translucent edge as the other panels, so its text doesn't sit straight on the backdrop. Do the same for the header (h1 and tagline). The spacer beside the title stays clear of the host's controls.
- Test: a static-mode browser check finds the link with the right `href`; backend mode has none.

## Review suggestions (of 131dd72)
- Run the whole frontend suite once, `node --test frontend/tests/`, and save it with its exit code.
- README's host-mode paragraph: the host's backdrop must follow the theme's neutrals, since contrast in the translucent band is guaranteed only over them.
- `style.css`: next to each duplicated dark rule block, add a comment pointing to its twin, or a test that the two stay identical.
- Size the title spacer from the host controls' 64 px, the same figure the README and the e2e check use.

## Check
`bash scripts/build-static.sh` (ending "leak check: clean"), then `node scripts/theme-e2e-check.js --static` on the real build and the backend run, each on a port in 8790–8799. Screenshot the static page's footer in light and dark, with and without the host attributes.

## Commands
One command per Bash call: `bash scripts/build-static.sh`, `bash scripts/static-leak-check.sh`, `node …`, `node --test …`, `backend/.venv/bin/pytest …`, `python3 …`, `curl …`. Do not install packages. Nothing dated or personal in comments.

## Done when
The static build has the "More demos" link (config-driven, tested). Header and footer are on panels under host-backdrop. The review items are done, and the suites and the leak check pass.
