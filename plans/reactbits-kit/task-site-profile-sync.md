# reactbits-kit: bring the site profile up to the live figurewright Waves

Track: light

The site's Waves (`/home/patrickb/rpbostick.github.io/src/reactbits/Waves/`, change list `/home/patrickb/rpbostick.github.io/src/reactbits/LICENSE.md`; read by absolute path, never copy React Bits code into this repo) gained changes after the kit's site profile was written: the pointer getter for drag-only feeding, the ripple-field displacement getter, the sheet follow, the sphere-spin sampling with wrapping periodic noise (`src/reactbits/Waves/noise.ts` if it is a modified upstream file), and anything else numbered since. The site's own modules `/home/patrickb/rpbostick.github.io/src/shared/{momentum,rippleField,clothFollow,sphereSpin}.ts` are ours.

## Build
- Transforms for every Waves change in the site's list not yet in the kit, so `rbx add Waves --profile site` reproduces the site's current Waves (compare as the existing compare script does).
- Our modules: update `momentum`, `rippleField`, `clothFollow` to the site's current versions and add `sphereSpin` (with its checks ported to `node --test`).
- The React adapter gains options for ripple, sheet follow and sphere spin (with the site's constants as defaults), so the site's Hero wiring can become a few lines.
- CHANGELOG 0.3.0, tag-ready.

## Tests
The site profile reproduces the site's current Waves; module tests for the updated and new modules; the licence boundary test passes.

## Commands
`npm ci`, `npm install …`, `npx …`, `node …`, `bash scripts/<script>.sh`, `git add`, `git commit`. One command per Bash call.

## Done when
`rbx add Waves --profile site` matches the live site's Waves, the modules match the site's, sphereSpin is in the kit, the adapter exposes them, and tests pass.
