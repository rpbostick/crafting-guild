# Toybox: momentum, ripple, sheet glide and spin for the backgrounds; a reproducible build

Read `README.md`, `NOTES.md`, `src/background/`, `scripts/`, `build.sh`, `tests/`.

## 1. Drag dynamics for every background (from reactbits-kit)
The public kit **reactbits-kit v0.3.0** (`github:rpbostick/reactbits-kit#v0.3.0`, MIT, no React Bits code; README in its repo or `/home/patrickb/reactbits-kit/README.md`) exports our modules: `momentum`, `rippleField`, `clothFollow`, `sphereSpin`, `pointerFeed`. These give the figurewright hero its feel: a local ripple-stretch and swirl under the pointer, the field stretching toward the drag like a sheet and gliding on after release (3–9 s, no spring back), and a gentle inside-of-a-ball spin (scale 0.1). Bring that to `<toy-background>`:
- Depend on the kit's **modules only** (import from `@rpbostick/reactbits-kit/modules/*`; do not use `rbx` or anything React Bits); bundle them into the background chunk.
- `pointerFeed` (the seam left for this) becomes inertial: after release, a coasting pointer per `momentum`.
- Each of our own backgrounds gets what fits it: line/field backgrounds (waves-like, ripple grid) take the ripple field, sheet follow and sphere spin as the figurewright waves do; shader backgrounds (aurora, iridescence, plasma, galaxy) take the coasting pointer and a sheet-like offset/rotation of their sampling coordinates. Say per background what it uses.
- Plug-in backgrounds (`registerBackground`) receive the inertial pointer and, optionally, the field/offset/spin state through the API (document it).
- Constants match the figurewright tuning by default (follow 30% capped 12%, glide 3–9 s, ripple and swirl at the doubled strength, spin 0.1); attributes on `<toy-background>` to turn each off (`ripple`, `sheet`, `spin`, `momentum`).
- Reduced motion: none of these.

## 2. A reproducible build
A clean checkout's `bash build.sh` writes chunk files with different names than the committed `dist/`. Stop committing generated output: git-ignore `dist/` (keep any hand-written file it held, e.g. the demo `index.html` source, under `src/` or `demo/` and copy it in at build time), make `scripts/release.sh` build and zip, and make tests that read `dist/` build it first (or skip with a clear message). If anything consumes committed `dist/` files (the README's install section, the subpath test), update it. Pin esbuild exactly so release builds repeat.

## Tests
Inertial pointer feed (coasts and decays after release, none under reduced motion); each background receives the dynamics it claims; the attributes turn them off; plug-ins get the documented state; a clean `npm ci && bash build.sh` from a fresh copy of the repo (`git clone` of the working tree into a temp dir) succeeds and produces the files the README lists; the licence list includes reactbits-kit (MIT). Firefox e2e: drag and fling on the demo page's background, see it coast. CHANGELOG 0.5.0.

## Commands
`npm ci`, `npm install …` (including `github:rpbostick/reactbits-kit#v0.3.0`), `npx …`, `node …`, `bash build.sh`, `bash scripts/<script>.sh`, `git clone <path> <tmp>`, `git rm --cached`, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
Every background has the figurewright-style dynamics (switchable), plug-ins get them, `dist/` is a build product only and a fresh clone builds reproducibly, version 0.5.0, tests passing.
