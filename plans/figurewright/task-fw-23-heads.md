# figurewright C3a: colorwright heads in src, every face on the easing head

Compose, step C3a. Today every posed figure's head is drawn by spike code (`spike/easing/easing-art.ts`: `poseHeadSvg` and `easingHeadSvg`; `spike/vendored.ts`: `headLayers`, `item` and `styleViewBox`). The spike code sits on top of the ported composition logic in `src/colorwright/` (slots, colour roles, draw order, hat/hair covering). Move head drawing into **`src/head/`** (a new module exported from `src/index.ts`), so the upcoming `renderFigure` (C3b) uses only `src/`.

## Build
- **`renderHead(look, pose)`**. `look` holds the colorwright slots (head-style, hair, face, facial-hair, hat, accessory; each an item id or none) with their colours, plus the skin tone.
  - It returns the head's markup in the pose's head canvas, plus the transform data needed to place it on a posed body's `neckAnchor` at `headScale` (both already in `src/body/head.ts`).
  - Use `src/colorwright`'s draw order, colour roles (`recolorSvgText`), hat-covers-hair and hides-hair rules, and the catalog in `vendor/colorwright/manifest.json`. Don't re-derive any of them.
- **Every face on every head (Patrick, 2026-09-29).** The easing pose has 3 faces, and other poses have up to 6 (`vendor/colorwright/parts/<pose>/face/`). Make every face from every pose drawable on the easing head.
  - First find how colorwright does this. Search `vendor/colorwright/` for cross-family or cross-pose faces: its tests, notes and manifest fields.
  - If the mapping isn't vendored, derive it: fit each borrowed face into the easing head by the pose's head canvas (`styleViewBox`) and the face's placement relative to the head-style outline, the same way for every face.
  - De-duplicate faces that are the same drawing in several poses (compare the markup). The picker should list each distinct face once, with a stable id.
- **Callers:** point `scripts/render-splash-easing.ts`, `scripts/render-posed*.ts` and `src/garments/posed-svg.ts` (if it draws heads) at `src/head`. `spike/` may keep its own copies. Every committed render must stay **byte-identical**: check each with `cmp` and save the logs.

## Evidence
- A **contact sheet** at `docs/renders/heads.png`: every distinct face on the easing head at two skin tones, labelled with their ids. Also every head style × one hair, and every hat over a long hair (hat covering). Patrick will look at it.
- 3× close-ups of two borrowed faces next to a native one.

## Tests
- A test that every face id renders on the easing head with no missing shapes: `recolorSvgText` throws on a missing role.
- Hat covering: a hat that hides hair leaves no hair shapes above the brim.
- Skin reaches every skin-role shape.
- Save a failing run on a broken mapping.

## Commands
One command per Bash call: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx scripts/<file>.ts`, `node`, `cmp`. Do not run `npm install`. Leave `src/garments/order.ts` alone (C2 is running in parallel). Run long renders in the foreground and hold one raster at a time.

## Done when
`src/head` draws every head from `src/` only. Every face renders on the easing head and appears on the contact sheet. The committed renders are byte-identical, and the tests and tsc pass.
