# Resume: draw a dressed figure (the installs are done)

The first run stopped because a headless builder cannot write `.npmrc`. Steps 1 and 2 are now done on this branch (commit f8f9eac: `.npmrc`, `@rpbostick/figurewright` 0.1.0 and `react-native-svg` in `package.json` and the lockfile, `node_modules` installed in this worktree). Do not run `npm install`, `npx expo install`, or touch `.npmrc`. Start at step 3; the package's README is `node_modules/@rpbostick/figurewright/README.md` and its types are under `node_modules/@rpbostick/figurewright/dist/`.

## The original task

### Bike Weather: install figurewright and draw a dressed figure

Track: light

Bike Weather will show the suggested outfit on a figure drawn by figurewright, an SVG avatar library. It is installed as a private package from GitHub Packages, `@rpbostick/figurewright@0.1.0`, and its README says how to use it. This task installs it with react-native-svg and adds one component that draws a body wearing a list of garments. It does not map our garment templates (the next task does) or touch the Today screen.

## Steps

1. Add `.npmrc` at the repo root with `@rpbostick:registry=https://npm.pkg.github.com` and `//npm.pkg.github.com/:_authToken=${NODE_AUTH_TOKEN}`. Never write a token into any file. `NODE_AUTH_TOKEN` is set in your environment.
2. Run `npm install @rpbostick/figurewright@0.1.0`, then `npx expo install react-native-svg`.
3. Add `src/avatar/Avatar.tsx` and `src/avatar/drawFigure.ts`. `drawFigure(worn)` is pure: it takes a list of `{ garmentId, color }` using figurewright's garment ids, dresses one library body in the base pose through figurewright's layering (its draw order, not ours), and returns the SVG string, with `defaultFigureArt` for the head, hands and shoes. `Avatar` draws that string with react-native-svg's `SvgXml`, sized to its container, with an accessibility label listing the garments.
4. Tests: `drawFigure` draws a tee over a base top with the tee's colour on the torso, and an empty list draws the body alone. `Avatar` renders in jest.
5. Run `npx expo export --platform web` once to show the web build resolves the package and react-native-svg.

## Prior art
- react-native-svg (MIT, in Expo's SDK): `SvgXml` draws an SVG string, on web through react-native-web.
- figurewright's README: package usage, `renderFigure`, `defaultFigureArt`, the garment ids.

## Commands

`npm test`, `npx jest *`, `npx tsc *`, `npm run typecheck`, `npx expo export *`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`.

## Leave alone
`src/model/`, `src/recommend/`, `src/screens/`. Don't add skywright or figurewright as `file:` links.

## Done when
- `@rpbostick/figurewright` and `react-native-svg` are in `package.json` and the lockfile; `.npmrc` holds no token.
- `drawFigure` and `Avatar` tests pass.
- `npx expo export --platform web` succeeds (log in evidence).
- `npm run typecheck` passes, and the jest files under `src/avatar/` pass with `--runInBand` (the merge gate runs the whole suite).
