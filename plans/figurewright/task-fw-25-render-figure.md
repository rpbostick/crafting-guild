# figurewright C3b: `renderFigure(look)` returns a layered figure

Compose, step C3b. Today a posed figure is drawn as one SVG string by `posedFigureSvg` (`src/garments/posed-svg.ts`), and its head is placed by the caller (`scripts/splash-lineup.ts`, via `src/head`). Bike Weather needs one call that takes a whole look and returns the figure **in layers**, so the app can draw, hide and later animate each garment on its own.

Read first:
- `spike/layers/REPORT.md` §5 (the output contract), §7, and build step 3;
- `src/garments/posed-svg.ts`, `src/garments/order.ts`, `src/garments/definition.ts` (`garmentDepth`, `GarmentWear`, `drawKey`);
- `src/head/render.ts` and `scripts/splash-lineup.ts`.

## Build: `src/figure/` (new, exported from `src/index.ts`)
- **`renderFigure(look, art, options?)`**.
  - `look` holds the body (measurements or slider values, as `src/body` takes them), the skin, the head (`HeadLook`), and the worn garments (`{ def, colours, wear? }`, where `wear` is a `GarmentWear`).
  - `art` holds everything drawn from files: the `HeadArt` and the extremity parts (hands and shoes). **`src` reads no files**; the caller loads the art. Put a loader for scripts and tests outside `src` (for example `scripts/art.ts`), and use it in the existing scripts.
  - It returns a **`LayeredFigure`**:
    ```ts
    const DRAW_GROUPS = ['far', 'main', 'near', 'head', 'neck'] as const;
    interface GarmentLayer {
      id: string; zone: GarmentZone; rank: string; depth: number; drawKey: number;
      anchor: { joint: 'neckBase' | 'crotch' | 'wrist' | 'ankle' | 'neckTop'; x: number; y: number };
      parts: Partial<Record<DrawGroup, string>>;
      box: Box;                 // painted extent of all its parts
    }
    interface LayeredFigure { body: Record<DrawGroup, string>; garments: GarmentLayer[]; bodyBox: Box; viewBox: Box }
    ```
  - Plus **`figureSvg(layered)`**: draws group by group (the body's markup for the group, then every garment's part in that group by `drawKey`) and returns one SVG string.
- **Refactor, don't duplicate.** Split `posedFigureSvg`'s drawing into the per-group parts `renderFigure` needs, and make `posedFigureSvg` a thin wrapper over `renderFigure` plus `figureSvg`, or retire it and move its callers.
  - The far-hand tuck, broken near-sleeve ink, seeds and far-sleeve layering must behave exactly as they do today.
  - **Every committed render stays byte-identical**, including `docs/renders/splash-easing.svg` (fw-splash-src just fixed its far sleeves). Check each with `cmp` and save the logs. If a render can't stay identical because the new grouping is more correct, show before and after PNGs and say why.
- **Head** through `renderHead(look.head, pose, art.head, idPrefix)`, placed on the neck anchor at head scale, in the `head` group.
- **The `neck` group** is drawn after the head. It is empty for today's garments, but the contract carries it so collars can go there later.
- **Depth from the wear options.** Each layer's `depth` and `drawKey` come from `garmentDepth(def, wear)` (C2).
  - Replace the hand-set depth overrides in `src/garments/basic.ts`: the tee's `depth: 27` and the base top's `depth: 20`.
  - Replace them with a rule: an **untucked** top draws over the bottoms' waistband, and a **tucked** top draws under it. Untucked is the default.
  - Today's renders must come out unchanged with the defaults. A test must show that `wear: { tucked: true }` puts the tee under the shorts' waistband.
- **Drawn parts:** hands and shoes stay in the body groups as they are today. Gloves, boots and hats as garments come later; leave a comment where they will plug in.

## Tests
- Drawing a figure with `figureSvg(renderFigure(look))` is byte-identical to today's `posedFigureSvg` output for the splash lineup's three generated figures.
- Every garment layer has a stable id (its definition's id), and its `box` lies inside `viewBox`. Its parts are only in groups that exist.
- The tucked/untucked order, as above.
- `renderFigure` with no garments draws a bare body with a head.
- `src/` imports nothing from `spike/`, `scripts/`, `fs` or `path`: a test that greps the import lines.
- Save a failing run for the tucked test before the rule exists.

## Carried from earlier reviews (do these while you are in these files)
- `scripts/render-splash-easing.ts:84`: the error message should say "expected once, or none for the tucked far hand".
- `scripts/splash-lineup.ts:2`: the header comment should say that bodies and skins still come from `spike/easing/cast`.
- Re-render the stale `docs/renders/splash.svg` in **its own commit**.

## Commands
One command per Bash call: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx scripts/<file>.ts`, `node`, `cmp`. Do not run `npm install`. Run renders in the foreground and hold one raster at a time.

## Done when
`renderFigure` returns the layered figure from `src/` only. `figureSvg` of it matches today's renders byte for byte. Tucking is a wear option, not a hand-set depth. The tests and tsc pass.
