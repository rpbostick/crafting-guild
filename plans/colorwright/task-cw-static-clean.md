# colorwright: a clean static build for public hosting (no comments, no internal fields, fails on leaks)

Track: light

`scripts/build-static.sh` writes `dist-static/`, which is published on a public website. Its output currently ships development comments that quote the project's owner with dates ("the operator, 2026-09-13: …"), references to `plans/`, `scripts/evidence/` and tests, and `catalog.json` carries internal fields such as `source_file` ("plans/head-crossfamily-spike …"). None of that belongs in public output.

## Build
1. **Minify** the shipped JS (`app.js`, `logic.js`, `data.js`, `config.js`) and CSS with esbuild (`npx --yes esbuild <in> --minify --legal-comments=none --outfile=<out>`; for JS keep the same module format the page loads today; for CSS `--minify` too). No comments survive. Source files in `frontend/` are unchanged; only `dist-static/` is minified.
2. **Trim `catalog.json`** to the fields the frontend actually reads (grep `frontend/*.js` for every property it uses on catalog items and the response); drop everything else (e.g. `source_file`, notes, provenance). Keep the backend's `/api/catalog` unchanged; the parity test between the static catalog and the API must compare only the kept fields (update it, and add a test that the trimmed fields are absent from the static file).
3. **A leak check at the end of `build-static.sh`** that fails the build (non-zero exit, listing file and match) if any file in `dist-static/` other than art SVGs contains: `operator`, `Patrick`, `patrickb`, `/home/`, `plans/`, `evidence`, `scripts/`, an ISO date (`20[0-9][0-9]-[01][0-9]-[0-3][0-9]`), `TODO`, `FIXME`, an email address, or `localhost`/`127.0.0.1`. Scan the art SVGs for `/home/`, `patrickb` and emails only (they may legitimately contain other words). Print "leak check: clean" on success.
4. Update `README.md`'s static-build section in one or two plain sentences (what it produces and that it is minified and leak-checked), no history.

## Check
`bash scripts/build-static.sh` exits 0 and prints "leak check: clean"; the static e2e check still passes against the minified build (run it as the earlier static task did); the frontend tests and `backend/tests/test_static_catalog.py` pass. Show the leak check failing once on a deliberately planted string (then remove it) and save both logs.

## Commands
One command per Bash call. `bash scripts/build-static.sh`, `npx --yes esbuild ...`, `node ...`, `backend/.venv/bin/pytest ...`, `node --test ...`, `python3 ...`, `curl ...`. Do not install packages.

## Done when
`dist-static/` has no comments and no internal catalog fields, the build fails on a planted leak and passes clean, and the tests pass.
