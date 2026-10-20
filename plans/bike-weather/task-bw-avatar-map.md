# Bike Weather: map every garment template to a figurewright garment

Track: light

`src/avatar/drawFigure.ts` draws a figure wearing figurewright garments (`{ garmentId, color }`). Our 44 garment templates (`src/model/templates.ts`) each have regions and a layer role; figurewright has 8 garments for now: base top, briefs, tee, jersey, zip jacket, shorts, tights and pants (see its README for ids). Until figurewright grows its catalog, each template is drawn as the **nearest** of these in its own colour, or not drawn.

## Steps

1. `src/avatar/garmentMap.ts`: a table, one row per template id, `{ garmentId, fit: 'exact' | 'nearest' | 'none' }`. Choose by what the garment covers and how it reads from the front, not by name. Arm warmers can't be a top; until a warmer exists they are `none`. Hands, feet and head items are `none` for now. A comment on each `nearest` row names what is off (for example "no open front", "sleeves full length").
2. `wornFigure(worn: Garment[])`: our worn garments → the list `drawFigure` takes. Keep each garment's own colour, skip `none` rows, and when two garments map to the same figurewright garment and layer, keep the outer one by our layer role.
3. Tests: every template in `TEMPLATES` has a row, and every `garmentId` exists in figurewright. Across the recommender's worked examples (`src/recommend/examples.test.ts` builds them), the drawn list follows our layer-role order, and for each covered span the outermost drawn garment is the outermost worn one that is drawn.
4. `docs/avatar-gaps.md`: the `nearest` and `none` templates grouped as figurewright's next garment groups (warmers; vests and shells; hands and feet; head and neck), with what each needs drawn.

## From the hands-on reports
`docs/research/avatar-cozybuilder-handson.md` §6 and `avatar-characterstudio-handson.md` §5 (read both):
- One row per template in the map: the figurewright garment, its layer role, and per sub-region (upper arm, forearm, hand, torso, thigh, shin, foot, head, neck) whether it **replaces** what is under it (a long sleeve hides the arm) or **overlays** it (a gilet over a jersey, the jersey still drawn).
- The layer key comes from the template's layer role in `src/model/templates.ts`, never set per garment.
- The every-outfit test also checks that each covered sub-region shows the outermost garment and the body shows only where nothing covers it.

## Prior art
- `docs/research/avatar-cozybuilder.md` §5: hiding rules as data, and a test that walks every outfit the recommender can produce.
- `docs/research/avatar-characterstudio.md`: an integer layer per garment, where the higher layer hides the lower.

## Commands

`npm test`, `npx jest *`, `npx tsc *`, `npm run typecheck`, `git add`, `git commit`. One command per Bash call. Run jest with `--runInBand`.

## Leave alone
`src/model/`, `src/recommend/`, `src/screens/`, `src/avatar/Avatar.tsx`.

## Done when
- Every template has a row, and every `garmentId` exists in figurewright (test).
- The worked-examples test passes: layer order, and the outermost drawn garment per covered span.
- `docs/avatar-gaps.md` lists every `nearest` and `none` template under a garment group.
- `npm test` and `npm run typecheck` pass.
