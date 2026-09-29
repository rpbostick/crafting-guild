# figurewright C2: dressing order in src/garments

Track: light

Compose, step C2 (from `spike/layers/REPORT.md` §4 and §7, build step 2). C1 is merged (`0c9b4af`), so `GarmentDef` has `zone`, `rank`, `depth`, `exit` and `drawKey`. Move the spike's dressing-order model into a new **`src/garments/order.ts`**, exported from `src/garments/index.ts`. Read `spike/layers/model.ts` and `spike/layers/check-order.ts` first.

## Build
- **Covers and exit routes**, as in `model.ts`:
  - pullover: torso above it, neck above its collar, head, arms past its sleeves, hands
  - front-open: shoulders (torso 0–0.1), arms past its sleeves, hands
  - down: legs below its leg pieces, feet
  - off: its own hand, foot or head

  Derive covers from the garment's pieces. Add the segments `hand`, `foot` and `head` for covers only, as the report says; drawn parts will declare their own covers later.
- **`blockersOf(target, worn)`**, **`canRemove`**, **`canAdd`**, **`undress(worn, keep?)`**, **`dress(worn)`** and **`removeOne(target, worn)`** (its `off` and `back` lists), with the spike's rules:
  - A traps B when A has a higher drawKey and covers part of B's exit route. The shoulders count for a front-open garment.
  - `undress` repeatedly removes the outermost garment nothing traps.
  - It **throws** when a kept garment traps one to remove, naming both.
- **Name clash:** `src/garments/dress.ts` already exports `dress(skeleton, garments)` (fitting). Name the order functions so nothing is ambiguous (e.g. `dressingOrder`, `undressingOrder`), and say in the header comment which is which.
- **Per-garment defaults (Patrick, 2026-09-28):** gloves can be under or over the cuff (depth 45 or 55), and tops can be tucked or untucked. Add these as options that change the garment's effective depth: `tucked` (a top drawn under the bottoms' waistband) and `glovesUnderCuff`. Each is a `GarmentDef` default that a worn entry can override. The order functions must use the effective depth. The garment rendering itself comes in C3; here, only the order and `drawKey` take the option into account.

## Tests (`test/garments/order.test.ts`)
- Port `check-order.ts`'s winter catalogue and its assertions: every printed sequence from the report's §4 block, exactly.
- Keeping a trapped garment throws ("keep the shell, lose the fleece").
- `dressingOrder` of every catalogue outfit, and of today's basic-garment outfits, passes `canAdd` at every step.
- Gloves over the cuff trap the sleeves; under the cuff they come off first anyway. A tucked tee comes off after the pants, an untucked one before them.
- Save a failing run on a deliberately broken rule (for example, the shoulders not counted for front-open).

## Commands
One command per Bash call: `npx jest --runInBand <files>`, `npx tsc --noEmit`, `npx tsx <file>`, `node`. Do not run `npm install`. Leave `src/garments/fit.ts`, `posed.ts`, `posed-svg.ts` and `svg.ts` alone: C3a is running in parallel and C3b will change them.

## Done when
`order.ts` is exported and tested as above, `npx jest --runInBand test/garments` and `npx tsc --noEmit` pass, and nothing any script renders changes.
