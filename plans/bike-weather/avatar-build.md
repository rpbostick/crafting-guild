# Bike Weather: the outfit avatar (figurewright body, layered 2D SVG)

**In flight right now**

**PLANNED (2026-10-09 17:27 MDT), nothing dispatched.** Waits for the budget reset on 2026-10-12. Before step 2, Patrick runs `gh auth refresh -s write:packages,read:packages` once (the token has repo, gist, read:org and workflow, not packages). About $34 in builders plus about $3 in reviews for steps 1 to 5.

## Requirements
- The Today screen shows the suggested outfit on a figurewright body. Garments are drawn in layer-role order (base, mid, outer, shell, accessory), each in the garment's own colour, and lower layers show where upper ones stop (decisions 2026-10-09 in `product.md`).
- Covering is per sub-region, as data. figurewright already has this: `GarmentCover { chain, from, to }` over the torso, neck, arm, leg, hand, foot and head chains, with draw order, dressing order and undressing order (`src/garments/order.ts`).
- bike-weather installs figurewright as a **private versioned package on GitHub Packages** (`@rpbostick/figurewright`). It is not public; going public on npm later needs its own release audit (Anny's licence, the Open Peeps CC0 credit, no reference photos).
- Native drawing uses **react-native-svg** (`SvgXml`). Web draws the same SVG.
- **Nearest shape first, then grow.** Each of bike-weather's 44 templates is drawn as the closest of figurewright's 8 garments (base top, briefs, tee, jersey, zip jacket, shorts, tights, pants) in its own colour, or not drawn. The gaps are listed, and figurewright adds real garments group by group, each one checked by Patrick.

Guesses (say if wrong): the avatar uses one library body (`libraryBody('average')` or nearest) until a body picker exists; the base pose; the head from figurewright's default art.

## Steps

1. **`fw-package`** (figurewright, `plans/figurewright/task-fw-package.md`, light, $8). figurewright becomes an installable package: `@rpbostick/figurewright`, built to `dist/` with types; `exports`; `files` limited to the runtime; the default head, hand and shoe art shipped as data a phone can load (no `fs`); `publishConfig` for GitHub Packages. A test packs it, installs the tarball into a scratch project and renders a dressed figure. Touches `package.json`, a build config, `src/index.ts` and a new art module. Safe to re-run.
2. **Publish 0.1.0** (orchestrator, after Patrick's `gh auth refresh`). `npm publish` from figurewright main with `NODE_AUTH_TOKEN=$(gh auth token)`. Check first: the package's file list has no reference photos, BodyM data or secrets.
3. **`bw-avatar-render`** (bike-weather, `task-bw-avatar-render.md`, light, $8). Install the package (`.npmrc` names the registry and reads `${NODE_AUTH_TOKEN}`; no token in the repo) and `react-native-svg` (`npx expo install`). Add `src/avatar/Avatar.tsx`: a body and a list of worn figurewright garments with colours → `SvgXml`. Jest test, plus a web export check. Touches `package.json`, `.npmrc` and `src/avatar/`.
4. **`bw-avatar-map`** (bike-weather, `task-bw-avatar-map.md`, light, $8, after 3). `src/avatar/garmentMap.ts`: each template → figurewright garment id with `exact`, `nearest` or `none`, and its colour from the user's garment. A test that every template is mapped, and one over the recommender's worked examples: draw order follows layer roles, and each covered span shows the outermost garment. `docs/avatar-gaps.md` lists what is drawn as a stand-in or not drawn. Touches `src/avatar/` (new files only) and `docs/`.
5. **`bw-avatar-today`** (bike-weather, `task-bw-avatar-today.md`, full track, $10, **gate**). The Today screen shows the avatar wearing the suggested outfit. A preview on :8801+ for Patrick before the merge. Touches `src/screens/today/`.
6. **Later, figurewright garment groups** (task files written when figurewright's body work resumes on 10/12, so they don't collide with its body tasks): warmers (arm, knee, leg: spans of the arm and leg chains); vests and shells (gilet, wind jacket, rain shell); hands and feet (gloves, socks, shoes, overshoes, toe covers); head and neck (cap, skull cap, beanie, neck gaiter, scarf). Each is a figurewright release (0.x.0) followed by a one-line bike-weather map update. Each gets Patrick's look at its render sheets.

**The token lives in the environment only.** From step 3 on, `npm install` in a builder and `npm ci` in `ws merge` read `.npmrc`, which takes `${NODE_AUTH_TOKEN}`. Builders run in a systemd scope that inherits the caller's environment. Start the chain, and any hand merge, as `NODE_AUTH_TOKEN=$(gh auth token) bin/ws --project bike-weather …`, so the token never touches a file.

Steps 3 to 5 run as a chain: `plans/bike-weather/avatar-build.queue`.

## Prior art
- `docs/research/avatar-cozybuilder.md`: one named-part library, hiding rules as data, a test over every outfit.
- `docs/research/avatar-characterstudio.md`: an integer layer per garment, higher hides lower; 2D gets this from draw order.
- figurewright's own layering engine (`src/garments/`).
- react-native-svg (MIT, in Expo's SDK).
- GitHub Packages' npm registry.
