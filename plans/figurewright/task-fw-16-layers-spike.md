# figurewright spike: real clothing layers, dressing order, and an exploded view (report and renders only)

Patrick (2026-09-28): "i want the clothing to be layered, like real clothing. so like, undergarments, base layer, over layer, top layer, coats, hats, snowpants, gloves, etc. we will want the art to be able to display multiple color-coded garments being worn at once. it would also be cool to be able to add some kind of 'get dressed' and 'get undressed' and 'remove/add layers' exploding out or in like the old win screen on Freecell (solitaire). so design with the mindset that layers of clothing should be visible under each other and should be able to be removed in tidy fashion."

Read `plans`-level context in `src/garments/` (`definition.ts`: `GARMENT_LAYERS`, pieces, bands; `fit.ts`; `dress.ts`; `svg.ts`), `spike/easing/REPORT.md` (the figure is moving to the easing pose; its garments section) and `docs/renders/garments.png`. **Work only under `spike/layers/`**; change nothing in `src/`, `test/`, `assets/` or other spikes (another builder is rebuilding `src/body` now; import from `src/` read-only and from `spike/easing/`).

## Design (the report's core)
1. **Zones and layer ranks** replacing the 7 fixed layers: torso (underwear, base, mid, insulation, shell, coat), legs (underwear, tights/base, pants/shorts, overpants/snowpants), head (cap/liner, balaclava, helmet/hat, hood from a coat), neck (buff, scarf), hands (liner, glove, mitt/overmitt), feet (sock, shoe, overshoe). Several garments per zone at once. Garments that span zones (a coat's hood, a one-piece, bib snowpants, a jacket over pants' waist) and how their draw order works across zones.
2. **Fit over layers**: each garment's ease grows with what is under it (a coat over fleece over base); how thickness per garment accumulates; how compression of a lower layer under a tight upper one works (the engine already compresses under-layers).
3. **Visibility**: what of each lower layer shows in normal wear (collar above, cuff below, hem below, a zip opening), and an optional **open / cutaway view** that reveals the stack clearly (e.g. front of each outer layer opened progressively, or a stepped cut). Keep it tidy and readable at app size.
4. **Dressing order**: a rule that says what must come off before a garment can (a base top needs the jacket and jersey off first; gloves over or under cuffs as the garment says), and the add/remove sequences for "get dressed", "undress" and "remove/add one layer".
5. **Output for animation**: `renderFigure`'s future output shape: the body plus one SVG group per garment with a stable id, layer rank, zone and anchor; and an **exploded layout** function giving each garment a target transform out and away from the body in layer order (think of an exploded technical diagram, then FreeCell's cards flying off). The app animates between worn and exploded (React Native Reanimated); the engine supplies positions, order and timing hints (stagger, direction), not frames. Make it work for hand-drawn garments too (they have the same group/anchor contract).
6. How much of today's `src/garments` survives and what changes (definitions, `dress`, `fit`, `svg`), as a migration plan.

## Prototype and renders (commit under `spike/layers/renders/`, ≤2 MB each; Patrick judges)
Prototype enough under `spike/layers/` (copy what you need from `src/garments`, new definitions for missing garments as simple parametric shapes) to render, on the **easing pose** via `spike/easing/`'s `posedFigure` machinery if you can, otherwise straight-on (say which):
- `stack.png`: one figure in a **winter outfit of at least 8 garments** (e.g. briefs, base top, base tights, fleece, insulated jacket, shell, snowpants, socks, boots, gloves, buff, beanie), **each a clearly different colour** so the layers read, in normal wear, then in the open/cutaway view.
- `exploded.png`: the same outfit exploded: body in the centre, garments out in layer order, and 3–4 in-between frames (worn → exploded) as a strip.
- `sequence.png`: "undress to base layer" as a row of steps in dressing order.

## Report (`spike/layers/REPORT.md`)
The model, fit, visibility, dressing order, output contract, exploded layout, migration plan for `src/garments` and compose (step 7), open questions for Patrick, and build steps with done-whens.

## Commands and limits
One command per Bash call. `npx tsx spike/layers/<file>.ts`, `npx tsc --noEmit -p <tsconfig>`, `node`. Do not run `npm install`. Long renders in the foreground. 4 GB memory cap: one raster at a time.

## Done when
Report and three renders committed; `git diff main...HEAD --stat -- ':!spike/layers'` is empty.
