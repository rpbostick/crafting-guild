# Bike Weather: the outfit avatar (figurewright body, layered 2D SVG)

**In flight right now**

**STEPS 1-2 DONE (2026-10-20 15:45 MDT):** fw-package merged in figurewright as ed6dfff ($2.98 + review $1.04, tsup build, `defaultFigureArt` holds DEFAULT_HEAD only); `@rpbostick/figurewright@0.1.0` published to GitHub Packages, private (7 files: dist/, LICENSE, README.md, package.json; scanned: no raster images, BodyM data, home paths or tokens). **Next: steps 3-5, `NODE_AUTH_TOKEN=$(gh auth token) bin/ws --project bike-weather chain plans/bike-weather/avatar-build.queue` under run_in_background; not started 2026-10-20 because Patrick takes the machine offline at ~16:30.** About $26 of the week's bike-weather budget left (spent ~$25).

**EDITOR SEEN (2026-10-20 17:00 MDT, Patrick): "it looks good and interesting"; the hands-on round is closed.**

**GO (2026-10-20 15:30 MDT, Patrick): steps 1-5, ~$37.** Issue draft: held, re-checked against their latest commit and batched with other upstream reports before posting. Next: publish 0.1.0, then avatar-build.queue with NODE_AUTH_TOKEN.

**HANDS-ON ROUND MERGED (2026-10-20 15:19 MDT):** bw-avatar-cozy-handson adc7f2b ($2.17 + review $0.42) and bw-avatar-cs-handson 40a1307 ($9.11 + fix $0.95 + reviews $4.93; one fix round: a body-named mesh put in the wrong slot). Reports: bike-weather docs/research/avatar-cozybuilder-handson.md (nothing harmful; coverage as one data row per garment, replace vs overlay per region, a test over every outfit, sockets for rigid gear) and avatar-characterstudio-handson.md (S1-S11 safety findings; draw order by layer role + per-sub-region coverage flags; render on demand; single-surface garments; a covering pass recomputed from the original). Waits on Patrick: the CozyBuilder editor on his desktop (runs/bike-weather/evidence/bw-avatar-cozy-handson/run-editor.sh; it failed with NoSuitableGraphicsDevice because SDL found no GLX visual for its multisample request, fixed 2026-10-20 by naming one through SDL_VIDEO_X11_VISUALID), the CharacterStudio issue draft (evidence/bw-avatar-cs-handson/issue-draft.md), and the go for steps 1-5. Carry forward to step 4: the coverage table names replace or overlay per sub-region; a test over every recommender outfit. Week's bike-weather spend so far ~$21 of ~$60.

**GATE (2026-10-09 18:16 MDT, Patrick): before any more figurewright or avatar work, a hands-on research round on CozyBuilder and CharacterStudio.** Today's reports (bike-weather `docs/research/avatar-*.md`) only read the code. This round installs and runs them, or inspects them with REA (morluto/rea, research report 16). It's for the avatar, and maybe for figurewright. CharacterStudio: install in isolation with install scripts off, run its editor, and measure its layers and culling against figurewright's garment engine. CozyBuilder (no licence): study only, nothing copied; run it or inspect its .NET build with REA. If REA is used, this is its first use: install the live version from GitHub, with our own safety checks before it runs (memory: rea-live-install). Each spike ends with what the avatar, and separately figurewright, should take or change. Tasks: `task-bw-avatar-cs-handson.md` (sandboxed install, cut and report harmful code, run the editor) and `task-bw-avatar-cozy-handson.md` (safety pass, user-local .NET, build; Patrick opens the editor on his desktop); how to dispatch: `plans/bike-weather/avatar-handson.queue` (decided 2026-10-09: install and run directly, REA kept for the eyedropper spike; GitHub issue drafts shown to Patrick before filing). Until this round is done, `fw-package`, `fw-reproduction-measure` and avatar-build steps 1 to 5 wait.

**APPROVED (2026-10-09, Patrick), nothing dispatched.** Waits for the budget reset on 2026-10-12. The GitHub token has `write:packages` (refreshed 2026-10-09), so step 2 can publish. About $34 in builders plus about $3 in reviews for steps 1 to 5.

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
