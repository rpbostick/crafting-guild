# Package the dice roller comparison as its own repository

This repository is the dice roller comparison page that used to live in another project's `spikes/dice/` folder (read `README` if any, `COMPARISON.md`, `OWLBEAR-CHANGES.md`, `owlbear/SOURCE.md`, `build.sh`, `scripts/`, `src/`, `tests/`). It compares four browser dice rollers with World of Dungeons rolls: Fantastic Dice (dice-box), dice-box-threejs, a light 2D roller (rpg-dice-roller + CSS dice), and the Owlbear Rodeo dice (GPL-3.0) as a separate page in an iframe. Make it a self-contained repository that anyone can rebuild, serve, and publish on a static site.

## Behaviour
- **Paths:** every path that says `spikes/dice/…` now means the repository root. Update scripts, docs and comments.
- **Owlbear source fetch:** `scripts/fetch-owlbear.sh` clones `https://github.com/owlbear-rodeo/dice` at the pinned commit `ccc32beceee0888c0a48129fbb23f4a636c710ee` into `vendor/owlbear-dice/` (ignored by git) and installs its dependencies (`npm install --legacy-peer-deps`). `build.sh` explains this and calls it when `vendor/owlbear-dice/` is missing (unless `--skip-owlbear`). Record the commit in `OWLBEAR-CHANGES.md` and `owlbear/SOURCE.md`.
- **One-command build:** `bash build.sh` installs the page's own dependencies if missing (`npm ci`), fetches Owlbear if needed, and writes `dist/`.
- **Licence notices in `dist/`** (a review found them missing): copy each shipped package's licence text next to what it ships, and write `dist/THIRD_PARTY_LICENSES.txt` listing every third-party package and asset in `dist/` with its licence and source URL: dice-box and its themes, dice-box-threejs with its textures and sounds (find and state their origin and licence, or say they could not be verified), rpg-dice-roller, random-js, mathjs (Apache-2.0), ammo.js (zlib, `ammo.wasm`), BabylonJS, three.js, cannon-es, the Owlbear app and everything its build bundles (React, MUI, three, @react-three/*, Rapier, zustand, etc.), using the bundlers' legal comments or `license-checker`-style output from `node_modules`. A footer link on the page opens it.
- **Owlbear corresponding source (GPL-3.0):** `build.sh` writes `dist/owlbear/owlbear-dice-source.zip` holding the exact Owlbear source used (the pinned checkout without `node_modules` and `.git`), our standalone files from `owlbear/`, `OWLBEAR-CHANGES.md`, and the GPL `LICENSE`, and the Owlbear tab shows a visible link "Source code (GPL-3.0)" to it plus a link to the upstream repository.
- **`serve.sh`**: serves `dist/` on a port (default 8810, first argument overrides) with Python's `http.server` bound to 127.0.0.1, and prints the URL. The page must run from any sub-path (e.g. `/dice-compare/`): relative URLs only.
- **`scripts/release.sh`**: after a build, writes `release/dice-roller-comparison-<YYYY-MM-DD>.zip` containing `dist/`, `serve.sh` and a short `HOW-TO-OPEN.txt` (unzip, run `bash serve.sh`, open the printed URL; double-clicking `index.html` does not work because the 3D dice and the Owlbear frame need a web server). `release/` is ignored by git.
- **README.md** (new): what the page is, a screenshot, how to build, serve and release, how to publish it on a static site under a sub-path, the licences (our code, the four libraries, the Owlbear GPL page and its source zip), and the measured sizes and load times from `COMPARISON.md`.
- Keep `COMPARISON.md` as the findings; trim spike wording that refers to the old project.

## Release audit (this will be published on a public static site)
Before finishing, check the tree and `dist/` for home paths, user names, emails other than intended credits, local ports other than the documented defaults, secrets, and development-process wording (builder, orchestrator, reviewer, spike, "the operator"); remove any found. Report what you checked and found.

## Prior art
The existing build and the bundlers' legal-comment output; `license-checker` (BSD-3-Clause) or `npx license-checker` for the notice list if it helps.

## Tests
Keep `tests/wod.test.js` passing (`node --test tests/`); make the rpg-dice-roller test fail loudly (not skip) when `node_modules` is missing, with a message saying to run `npm ci`. Add a test that every `dist/` subfolder with third-party code has a licence file and that `THIRD_PARTY_LICENSES.txt` names each package in `package-lock.json`'s shipped dependencies (skip with a clear message if `dist/` has not been built).

## Commands
`bash scripts/fetch-owlbear.sh`, `bash build.sh`, `bash scripts/release.sh`, `npm ci`, `npm install …`, `npx …`, `node …`, `cp` inside the repository, `firefox --headless …` for a README screenshot (absolute paths), `git add`, `git commit`. One command per Bash call.

## Done when
A fresh clone builds with one command, serves with `serve.sh`, carries complete licence notices and the Owlbear source zip in `dist/`, produces a release zip, has a README, passes the audit checks and its tests.
