# reactbits-kit: foundation, our own modules, and transforms for Waves, Aurora and Iridescence

This repository is new (only a README and the MIT `LICENSE`). Its job: let any of our projects apply **our customizations of React Bits components** (reactbits.dev, https://github.com/DavidHDev/react-bits) to upstream code that the project fetches itself, plus share **our own modules** that the customized components use. 

**Licence boundary (essential):** React Bits is "MIT + Commons Clause": its components may be used as part of an application, website or product, but not redistributed "alone, in a bundle, or as a ported version". So **this repository must never contain React Bits code**, not even as diff context. Our changes are expressed as **code transformations** (AST codemods) that describe what to change, applied to the upstream file the project downloads at a pinned commit. Our own modules (no React Bits code) are MIT. State this boundary in the README.

## Reference material (read by absolute path; do not copy React Bits code into this repo)
- Our customized copies on the site: `/home/patrickb/rpbostick.github.io/src/reactbits/{Waves,Aurora,Iridescence}/` and their change list `/home/patrickb/rpbostick.github.io/src/reactbits/LICENSE.md` (each numbered change describes one customization). The newest Waves changes (pointer getter, ripple field, cloth follow) are on the branch worktree `/home/patrickb/rpbostick.github.io/.worktrees/site-waves-momentum/src/reactbits/` and its `src/shared/{momentum,rippleField,clothFollow}.ts`.
- The character sheet's plug-in for ten components: `/home/patrickb/pen-paper-rpg/chargen-toybox/plugins/react-bits/` (and `vendor/reactbits/CHANGES.md` there if present), for later rounds.
- Upstream: clone `https://github.com/DavidHDev/react-bits` into `.upstream/` (git-ignored) at the commit recorded in the site's change list or the newest one, to develop and test against.

## What to build in this round
1. **Our own modules** (`src/modules/`, TypeScript, no React Bits code, MIT): `momentum` (release velocity, exponential decay), `rippleField` (local ripple-stretch and swirl spring mesh), `clothFollow` (bedsheet follow and glide), `pointerFeed` (drag-only on bare background with `data-solid`, grab/grabbing cursors), `colorDrive`/palette (the 72-stop colour loop) — taken from our own code in the reference paths (these files are ours), with their checks ported to `node --test`.
2. **Transforms** (`src/transforms/<Component>/NN-name.ts`), one per numbered customization in the site's change list for **Waves, Aurora and Iridescence** (per-frame colour/motion getters, `paused` prop, accumulated clock, IntersectionObserver pause, pointer position fix, pointer getter prop, CSS variable fix, …). Use an AST tool (ts-morph or jscodeshift; pick one and say why) so a transform matches structure, not exact text, and fails loudly with the change's name when the upstream shape no longer matches.
3. **The CLI** `rbx` (`bin/rbx.js`, published later as `@rpbostick/reactbits-kit`):
   - `rbx add <Component> --to <dir> [--commit <sha>]`: download the component's TS-default `.tsx` and `.css` from React Bits at the pinned commit (raw GitHub URLs) into `<dir>/<Component>/`, apply our transforms, and write `<dir>/<Component>/CHANGES.md` listing each applied change (our wording, no upstream code) and the upstream commit.
   - `rbx update [--commit <sha>]`: re-fetch and re-apply for every component recorded in `<dir>/reactbits-kit.json`; report changes that no longer apply.
   - `rbx check`: verify the project's copies equal a fresh fetch+apply (drift detection), exit non-zero on drift.
   - `rbx list`: components and transforms available.
   - The pinned commit lives in `reactbits-kit.json` in the project.
4. **Tests:** each transform applied to the pinned upstream file yields code that type-checks (tsc) and contains the expected API (e.g. a `paused` prop); applying the full set to Waves/Aurora/Iridescence reproduces the behaviour of our site copies (compare the exported props and key code paths, not text); `rbx add/update/check` against a temp project using a local upstream checkout (no network in tests: point `--source` at `.upstream/`); our modules' unit tests. Tests that need `.upstream/` skip with a clear message when it is absent, and `npm test` fetches it first via `scripts/fetch-upstream.sh`.
5. **Docs:** README (what, the licence boundary, install, `rbx` commands, how to add a new transform, how to use the modules), `CHANGELOG.md` (0.1.0).

## Not in this round
The other seven components and moving the site and the character sheet onto the kit come next.

## Prior art
patch-package (applies diffs to node_modules; not usable here because diffs carry upstream lines), jscodeshift / ts-morph codemods, shadcn/jsrepo-style "copy component into your project" registries (React Bits itself is distributed this way).

## Commands
`npm init`, `npm install …`, `npx …`, `node …`, `git clone --depth 50 https://github.com/DavidHDev/react-bits .upstream`, `bash scripts/<script>.sh`, `cp` inside the repo, `git add`, `git commit`. One command per Bash call.

## Done when
Our modules are in the repo with tests; transforms for every customization of Waves, Aurora and Iridescence apply to the pinned upstream and reproduce our site's versions; `rbx add/update/check/list` work against a local upstream; the repo contains no React Bits code; README and CHANGELOG written; tests pass.
