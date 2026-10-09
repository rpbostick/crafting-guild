# figurewright: make it an installable package for GitHub Packages

Track: light

Bike Weather (an Expo / React Native app) will draw its avatar with figurewright, installed as a private package from GitHub Packages' npm registry under the name `@rpbostick/figurewright`. Today `package.json` is `"private": true`, `"main": "src/index.ts"`, and the head, hand and shoe art a figure needs (`FigureArt` in `src/figure/render.ts`) is loaded by the scripts, not shipped by the library. Make the package installable and usable on a phone. Do not publish it; that happens after the merge.

## Steps

1. Measure before choosing the build: compare plain `tsc` emitting `dist/` (ESM plus `.d.ts`) with `tsup` on build time, output size and whether the type declarations resolve for a consumer. Pick one and say why in the PR summary.
2. `package.json`: name `@rpbostick/figurewright`, version `0.1.0`, drop `private`, `main`/`types`/`exports` pointing at `dist/`, `files` limited to `dist/`, `LICENSE` and `README.md`, `publishConfig: { "registry": "https://npm.pkg.github.com" }`, `repository` set to the GitHub repo, a `build` script, and `prepack` running the build.
3. Ship the default art: a module exported from `src/index.ts` (for example `defaultFigureArt`) that gives the `FigureArt` the sheets use for the default head and the hands and shoes, as imported data (JSON or TS), with no `fs`, `path` or other Node-only import. Only CC0 Open Peeps art and figurewright's own drawings may go in; nothing from reference photos or BodyM.
4. A test (`test/package/pack.test.ts`, or a script the suite runs) that runs `npm pack`, installs the tarball into a scratch directory under the system temp dir, imports the package from there, renders a library body wearing a tee and shorts with `defaultFigureArt`, and checks the SVG is non-empty and matches the in-repo render of the same figure. A second test checks that nothing reachable from `src/index.ts` imports a Node built-in.
5. README: replace "Status: not started" with what the package does now and how to install it (an `.npmrc` with `@rpbostick:registry=https://npm.pkg.github.com` and a token in `NODE_AUTH_TOKEN`).

## Prior art
- GitHub Packages' npm registry docs (scoped name, `publishConfig`, `.npmrc` auth).
- tsup (MIT) and plain `tsc`: step 1 measures both.
- The package layout of react-native-svg or another TS library that ships `dist/` with `exports`, for the field set.

## Commands

`npm test`, `npx jest *`, `npx tsc *`, `npm run typecheck`, `npm run build`, `npm pack *`, `npm install *`, `npx tsup *`, `node *`, `git add`, `git commit`. One command per Bash call.

## Leave alone
Body, pose, garment and render code under `src/` (only `src/index.ts` and the new art module change). Goldens and the scorecard baseline.

## Done when
- `npm pack` produces a 0.1.0 tarball containing only `dist/`, `LICENSE`, `README.md` and `package.json`; the file list is in the evidence.
- The pack test installs the tarball in a scratch project and renders a dressed figure equal to the in-repo render.
- No module reachable from `src/index.ts` imports a Node built-in (test).
- `npm test` and `npm run typecheck` pass.
