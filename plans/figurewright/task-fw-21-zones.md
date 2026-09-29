# figurewright C1: zones, ranks and depth replace the fixed layers

Track: light

Compose, step C1. Read `spike/layers/REPORT.md` sections 1, 4 and 7 and `spike/layers/model.ts` first. The spike prototyped this model. This step moves its **zones, ranks, depth and drawKey** into `src/garments` and migrates the basic garments. It changes nothing a figure draws.

## Build
- **`src/garments/definition.ts`:**
  - Replace `layer: GarmentLayer` and `GARMENT_LAYERS` with the spike's `ZONE_RANKS`. The zones are torso, legs, head, neck, hands and feet, each with its ranks and their depths, as in the report's table.
  - `GarmentDef` gets `zone`, `rank`, optional `depth` (overrides the rank's depth), optional per-piece `depth` (for a hood or gaiter later; accept and validate it now) and `exit` (`pullover | front-open | down | off`).
  - Add `garmentDepth(def)` and `drawKey(def)` as in `model.ts`: depth − 0.5 for legs + zone index / 100, so at equal depth a top draws over the bottoms' waistband.
  - `validateGarment` checks that the rank belongs to the zone and the exit is known. A definition that still has `layer` and no `zone` **throws, naming the garment and saying what replaced `layer`**.
- **`src/garments/basic.ts`:** migrate every basic garment, as the report's section 7 table says:
  - tee: torso base
  - jersey: torso mid
  - zip jacket: torso shell, exit front-open
  - base top: torso underwear
  - tights: legs base
  - shorts and pants: legs pants
  - briefs: legs underwear
  - gloves: hands glove
  - Give every other garment the rank its role implies, and list them in the commit.
- **`src/garments/dress.ts`:**
  - Sort by `drawKey`. Each garment's `over` list is every garment with a higher `drawKey` where they overlap, as today.
  - The conflict rule becomes: same zone, same depth, overlapping covers. Keep its error message's shape, naming both garments and the chain.
  - `garmentLayerIndex` and `dressInLayers`: keep their behaviour for their callers (`posed.ts`, `fit.ts`), expressed through `drawKey`. If `behind`/`front` needs a split point, derive it from depth and comment where it comes from.
- **Every caller:** update `src/`, `scripts/`, `test/` and the `spike/` files that import `src/garments` (`git grep -n "\.layer\b\|GARMENT_LAYERS"`), so `npx tsc --noEmit` passes for the root and for every spike tsconfig the scripts use. Don't change what any spike renders.

## Done when
- Every basic garment validates with its zone.
- A test shows an old-shape definition (with `layer`) throws with the message above.
- **The drawing order is unchanged:** a test records `drawOrder` for today's outfits (the four in `scripts/render-posed-garments.ts` and the splash lineup's three) and checks it matches the old order. Run it on the old code first and save that log.
- `npx tsx scripts/render-posed-garments.ts` and `npx tsx scripts/render-splash-easing.ts` produce **byte-identical SVGs** to `main`'s. Save a `cmp` log for each.
- `npx jest --runInBand test/garments` and `npx tsc --noEmit` pass.

## Commands
One command per Bash call: `npx jest --runInBand <files>`, `npx tsc --noEmit [-p <tsconfig>]`, `npx tsx scripts/<file>.ts`, `node`, `cmp`. Do not run `npm install`. Commit messages describe only the files in their diff.
