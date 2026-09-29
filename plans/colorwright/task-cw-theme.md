# colorwright: a dark theme and a System / Light / Dark switch

The frontend (`frontend/`) is light-only: `style.css` hard-codes its colours. It ships in two places: the backend app, and `dist-static/` (from `scripts/build-static.sh`), which is published at https://rpbostick.github.io/colorwright/. Add a dark theme and a theme switch to the frontend, so both modes get them.

## The switch
- A three-option segmented control, **System | Light | Dark**, in the **upper right of the page**, level with the `<h1>`. System is the default.
- Behave like the host site's switch: a `role="radiogroup"` with `aria-label="Colour theme"`, and three `role="radio"` buttons with `aria-checked`. Only the checked option is in the tab order. The arrow keys move the choice and focus and wrap at the ends; Home and End jump to the first and last.
- The choice lives in `data-theme` on `<html>`: absent for System, `"light"` or `"dark"` otherwise. It is saved in `localStorage` under the key **`theme`** (`"light"` / `"dark"`; the key is removed for System). This is the same key and the same values the host site uses, so a choice made on the site carries into the demo, which is on the same origin. Wrap every storage access in try/catch; with no storage, the choice applies to this page view only.
- A small inline script in `<head>` applies the saved choice **before first paint**, so a saved Dark never flashes Light. Under System, follow `prefers-color-scheme` live, including a change while the page is open.

## The dark theme
- Move every colour in `style.css` into custom properties on `:root` (the light values, unchanged). Then redefine them under `:root[data-theme='dark']` and under `@media (prefers-color-scheme: dark) { :root:not([data-theme]) { … } }`. Set `color-scheme` in each.
- Dark tokens: use the host site's neutrals: background `#1a1816`, surface `#24211e`, text `#efe9df`, muted `#b3aa9d`, border `#3a3530`. Lighten the blue accent so selected tiles, focus rings and pressed buttons reach WCAG AA contrast against the dark surface. Check every text/background pair for AA contrast.
- **The art stays on light canvases.** The Open Peeps parts have black ink, which disappears on dark. In dark mode, keep the preview figure's box and each option tile's thumbnail area on a light background (a soft off-white, not pure white). The surrounding chrome goes dark. Check the "none" icons and the head underlays too.
- Also cover: the status bar, empty rows, nav arrows, colour-picker inputs, the save form and the saved-looks list, and the facing buttons.

## Check
- Frontend tests and `bash scripts/run-all-tests.sh` pass. Add frontend tests for the theme logic: stored value to attribute, System removes the key, a storage exception doesn't throw, arrow-key wrapping.
- Using the existing browser tooling in `scripts/` (`e2e-browser.js`), save screenshots to `.ws-evidence/` of the full editor in Light, in Dark, and in System with the browser emulating dark. Take them in both the backend mode and the static build served under `/colorwright/`. Also save a 2× close-up of a row of tiles and of the preview in Dark.
- `bash scripts/build-static.sh` still ends with "leak check: clean".
- Put nothing dated or personal in comments: the static build is public.

## Commands
One command per Bash call. `bash scripts/run-all-tests.sh`, `bash scripts/build-static.sh`, `node …`, `node --test …`, `npm test`, `backend/.venv/bin/pytest …`, `python3 …`, `curl …`. Do not install packages. Use browser-check ports 8790–8799.

## Done when
The switch sits top right and works by mouse and keyboard. Dark is complete, with no light-only leftovers except the art canvases. The choice persists under the key `theme` and applies before first paint. The screenshots are in `.ws-evidence/`, and the suites and the leak check pass.
