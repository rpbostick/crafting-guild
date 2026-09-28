# colorwright: a static mode that runs with no backend, for the public demo site

colorwright (plain-JS frontend in `frontend/`, FastAPI + SQLite backend in `backend/`) will be shown on Patrick's public demo site at **https://rpbostick.github.io/colorwright/**, which is static hosting (GitHub Pages): no backend, no server state. Read `README.md`, `frontend/app.js` (`rawApiFetch`, `readApiResponse`, `ASSET_BASE_URL`) and `backend/app/main.py` first.

## Build
1. **A data layer with two implementations** in the frontend: the existing API one, and a **static** one:
   - `GET /api/catalog`: build the same response the backend returns from `assets/catalog/manifest.json` (read how `main.py` shapes `CatalogOut` from the catalog table, and match it exactly; if the backend does work the manifest lacks, do it in JS or generate a `catalog.json` at build time with a small Python script that reuses the backend's own code, so both modes stay identical).
   - `POST /api/session`: a local session (no token needed).
   - Looks (`POST /api/looks`, `GET /api/looks`, `GET /api/looks/{name}`): saved in **localStorage** under a versioned key; wrap every access in try/catch and fall back to in-memory for the visit. Same validation and error messages as the backend where the UI depends on them (a missing look → the same not-found path).
   - The mode is chosen by a config value set at build time (e.g. `window.COLORWRIGHT_CONFIG = { mode: 'static', basePath: '/colorwright/' }` in a generated `config.js`), not by probing the API.
2. **Base path**: every URL (assets, scripts, styles) must work under `/colorwright/`. `ASSET_BASE_URL` and the API root come from the config; the backend-served app keeps working at `/` unchanged.
3. **Build script** `scripts/build-static.sh`: writes `dist-static/` (gitignored) with `index.html`, the JS/CSS, `config.js` (static mode, base `/colorwright/`), the catalog JSON if generated, and **only** the catalog art the app loads (`assets/catalog/...`; not `openpeeps-source/`, `raw*`). Print the total size. Add a line to the site notice in the UI or footer in static mode: "Looks are saved in this browser only." and keep the existing Open Peeps credit / unofficial notice.
4. Tests: unit tests for the static data layer (catalog shape equals the backend's for the same manifest, save/list/load a look, not-found, storage unavailable) in the frontend's existing test setup; and a backend test or script check that the generated catalog JSON equals `GET /api/catalog`'s body.

## Check
`bash scripts/run-all-tests.sh` passes. Build with `bash scripts/build-static.sh`, serve `dist-static/` under `/colorwright/` (a small node or `python3 -m http.server` setup that maps the prefix), and check with `curl` that the page, `config.js`, the catalog and a sample of part SVGs return 200. If the frontend's browser tests can run against the static build, run them.

## Commands
One command per Bash call. `bash scripts/run-all-tests.sh`, `bash scripts/build-static.sh`, `backend/.venv/bin/python ...`, `backend/.venv/bin/pytest ...`, `node ...`, `npx ...`, `python3 -m http.server ...`, `curl ...`. Do not install packages.

## Done when
`dist-static/` runs the full editor under `/colorwright/` with no backend (catalog loads, parts swap and recolour, looks save and reload in the same browser), the backend mode is unchanged, and the suites pass.
