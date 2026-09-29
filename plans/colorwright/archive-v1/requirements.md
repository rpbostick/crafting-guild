# Colorwright — Requirements

## Current state (v1.0, 2026-09-27)

The app as it is now is described in the top-level `README.md`. Against
the phases below:

- **Phase 1** (black-and-white part-swapping across the standing poses):
  met. All 30 standing samples, 9 body styles, every part on every body
  style where a part can go.
- **Phase 2** (colorization): met, and wider than planned. Every outfit,
  head style, hair, facial hair and hat has colour regions read from Open
  Peeps' own design source; one Skin control; hair and facial-hair picks
  that carry over switches; hats that clip the hair; prosthesis colours;
  saved looks that keep the colours; mirroring.
- **Phase 3** (sitting and bust poses, the wider Gumroad library): not
  built. The Gumroad library was used for the cross-body-style heads,
  faces, facial hair, accessories and hats; the sitting and bust SVGs are
  downloaded locally (`pipeline/fetch_extra_poses.py`) but not in the
  pipeline.
- **§4, the artist / designer tutorial**: not written. §4's own condition,
  a working demo of the whole project, is now met, so it can start.
- **Open questions** below: see each one's dated answer; they are kept as
  they were decided.

Everything after this section is the dated record, unchanged.

---

Status: first requirements pass, written 2026-09-11 against the real
research in `plans/open-peeps-research-2026-09-11.md` and
`plans/open-peeps-research/`. Where that research leaves a real
technical question unanswered, this document says so explicitly rather
than assuming an answer — see "Open questions" at the end. Nothing here
should be read as promising a shipped feature; it's a scope proposal.

**Sign-off: the operator confirmed 2026-09-11** — the phasing (Phase 1
black-and-white part-swapping only; Phase 2 colorization gated behind a
real segmentation spike, not committed to a schedule up front; Phase 3
sitting/bust/Gumroad, unresearched; tutorial written after Phase 2's
spike, not before) matches what he had in mind, no changes requested.
Phase 1 is cleared to start. **Sequencing sharpened 2026-09-11** (after
Phase 1 shipped): the tutorial specifically waits for a working demo of
the whole project, not just the spike — see §4's ending note.

## 1. Framing

**What this is.** Colorwright is an unofficial, CC0-licensed Open Peeps
avatar editor and toolkit: given Open Peeps' hand-drawn black-and-white
line art, it lets someone assemble a figure from swappable parts —
catalog slots `head` (hairstyle), `face`, `facial-hair`, `hat` (since
2026-09-25, "Hats as a layer" at the end of this file), `accessories`,
`outfit` (whole body+clothing) — and recolor those parts
independently, head to toe, across Open Peeps' full pose range (standing,
sitting, bust) rather than a headshot-only subset. It is not affiliated
with or endorsed by Pablo Stanley or Open Peeps (openpeeps.com) — that
stance is already stated in `README.md` and this document doesn't change
it.

This project will be used in a future app. No detail about that app
belongs in this document or anywhere else in this repo — the toolkit is
scoped and justified on its own terms below.

**Who it's for.** `paper-doll-workshop`'s own framing named three
audiences: indie game devs, embedding app/web devs, and hobbyists. That
framing is reused here, but re-decided rather than inherited by default:

- **Indie game devs** — still fits. A CC0, recolorable, full-body peep
  catalog is exactly the kind of placeholder/production art an indie
  game benefits from, and Open Peeps' license makes it safe to ship in a
  commercial game without attribution obligations.
- **Embedding app/web devs** (avatar pickers, onboarding flows, profile
  UIs) — still fits, arguably fits *better* than it did for the pilot's
  placeholder art, because Open Peeps is a recognizable, already-popular
  illustration style people choose specifically for this use case
  (it's already why DiceBear built an avatar generator around it).
- **Hobbyists** (people who just want to make a peep and export it) —
  still fits as a lightweight use case, unchanged from the pilot.

Kept the same three; the shift from placeholder shapes to real, licensed,
recognizable art strengthens the first two more than it changes the
third.

## 2. Asset scope, phased

The research is unambiguous that a real engineering task stands between
"30 downloadable standing-pose SVGs" and "a catalog of independently
colorizable parts" (see §7 and the research doc's own "What this means
for scoping this project"). This section proposes a sequence that
doesn't promise the hard part up front.

### What "swappable" already means for free, today

Direct inspection of `sample-peep-standing-30.svg` (not just the
research doc's prose) confirms each of the 30 standing SVGs is built as
a small number of **named, whole-component groups**, each internally
just two flat compound paths (a white `🎨-Background` fill shape and a
black `🖍-Ink` outline shape):

```
pose/standing/shirt-1   (the entire body + that sample's outfit, fused)
head/Long-Curly
face/Smile
facial-hair/*-None
accessories/Glasses-4
```

Swapping a whole group between files that share the same coordinate
space (e.g. dropping `head/Long-Curly` from sample #1 in favor of
`head/Afro` from sample #7) is the kind of operation Open Peeps' own
naming convention was clearly designed to support, and is a much smaller
claim than "these compose and align" — see the alignment open question
in §7. **This is the only granularity confirmed usable without further
authoring**: hairstyle, face, facial hair, and accessory swapping across
the 30 standing samples (pending the alignment check in §7), all still
in flat black-and-white.

### What "independently colorizable" requires that doesn't exist yet

Within `pose/standing/shirt-1`, skin and clothing are **not separate
shapes** — the entire body-plus-outfit silhouette is one compound
`🎨-Background` path and one compound `🖍-Ink` path. There is no
existing seam to tag "this sub-region is skin" vs. "this sub-region is
shirt." DiceBear's proven colorization technique (template placeholders
per shape, fed by a hex-array schema) only works because DiceBear's
Figma-exported bust components were already segmented into separate
skin/clothing/headContrast shapes upstream, in Figma — work nobody has
done for the standing or sitting poses. Producing that segmentation for
even one standing pose's clothing means manually splitting one large
compound path into per-color-region sub-paths — real vector editing
work, not a metadata/tagging exercise, and not something this
requirements pass can size precisely without a prototype (§7).

### Phase 1 (MVP) — black-and-white part-swapping, all 30 standing samples

- Harvest `head` (hairstyle) / `face` / `facial-hair` / `accessories` as
  independently swappable catalog items from all 30 standing SVGs
  (bounded, known
  count: however many distinct named variants actually appear across
  the 30 files — a concrete inventory task, not a research question).
- Ship these uncolorized (flat black-and-white), proving the
  extraction + cross-file recombination pipeline end to end before
  colorization is attempted at all.
- Whole-outfit swapping (swap the entire `pose/standing/shirt-N` group
  between samples, not just its sub-parts) is in scope for Phase 1 —
  it requires the same cross-file alignment check as hair/face, not the
  harder skin/clothing segmentation problem.

### Phase 2 — colorization, prototyped on a narrow slice first

- Before committing to a schedule: hand-segment **one** standing pose's
  clothing (skin vs. one or two clothing regions) as a spike, to get a
  real per-item time cost. Until that spike exists, no numeric scope
  ("N items colorizable by date X") should be treated as a commitment.
- Once the segmentation technique is validated on that one item, extend
  it outfit-by-outfit across the 30 standing samples. Skin color is
  likely shareable across all outfits once segmented once per pose
  (skin shape doesn't change with outfit, in principle) — flagged as an
  assumption to verify during the spike, not stated as fact.
- Hair, face, and accessory pieces likely need the same per-shape
  segmentation treatment as clothing (e.g. distinguishing hair color
  from skin color in a beard, or lens tint vs. frame color in glasses)
  — scope each category's colorization independently; don't assume
  "clothing solved" implies "hair solved."

### Phase 3 — full ambition

- Extend Phases 1–2 to the Sitting and Bust pose categories (confirmed
  to exist as real, separate download sets on openpeeps.com, not yet
  inventoried the way the 30 standing SVGs have been).
- Investigate whether Open Peeps' Gumroad library (if the operator has or
  obtains it) contains more raw material than the free CDN samples —
  explicitly not researched yet; do not assume it's a superset, a
  paid-only variant set, or anything else without checking.

## 3. Shape-tagging / colorization data model

**Proposal: keep the SVG as the geometry source of truth; add a sidecar
manifest per part that maps shape identity to a color role.**

Rationale, against the two real constraints this project actually has
(not the pilot's, which didn't face a pre-fused source format):

- The raw art is externally sourced (openpeeps.com) and CC0-licensed;
  keeping edits to a separate manifest rather than rewriting the SVGs
  in place preserves an unmodified copy of the source art alongside the
  derived, tagged version — useful for re-verifying provenance later
  (the v1 review checklist's existing "Art assets / license" rule already
  requires traceability to a real source) and for re-doing the
  segmentation differently later without re-fetching.
- Inline SVG attributes (e.g. custom `data-color-role="skin"` attributes
  on `<path>` elements) were considered and rejected as the *only*
  mechanism: they'd require every segmented path to carry the
  attribute, coupling the tagging convention to hand-edited SVG markup
  that an artist following the tutorial (§4) would need to edit
  correctly by hand in a text/code editor, not just in their normal
  vector tool. A sidecar manifest referencing shape IDs (SVG element
  `id` attributes, which Open Peeps' source already uses heavily and
  distinctly per shape) keeps the tagging step separate from the
  geometry-editing step.
- Proposed manifest shape (illustrative, not final field names):

  ```json
  {
    "part_id": "standing/shirt-1/clothing-primary",
    "source_svg": "peep-standing-1.svg",
    "shape_id": "🎨-Background-shirt-region-1",
    "color_role": "clothing-primary"
  }
  ```

  One manifest entry per *segmented sub-shape*, not per whole component
  — a single clothing item will need multiple entries once its compound
  path is split (e.g. `clothing-primary`, `clothing-secondary` for a
  two-tone shirt).
- Color roles needed, at minimum, per the research's confirmed DiceBear
  precedent: `skin`, `hair`, `clothing-primary`, `clothing-secondary`,
  and likely `accessory-primary` for tinted accessories (sunglasses
  lenses vs. frames) — exact final set is a Phase 2 spike output, not
  decided here.

**A "look" (chosen parts + chosen colors) is a small, serializable
structure**: a list of selected `part_id`s (one per catalog slot: `head`,
`face`, `facial-hair`, `hat`, `accessories`, `outfit`) plus a map of `color_role` to a
chosen hex value. This mirrors the pilot's session-token model in
spirit — a look is data, not a stored image — but the *catalog* it
references is Colorwright's own (parts harvested from Open Peeps, not
the pilot's placeholder shapes). Whether persistence is a server-side
session token (as in the pilot) or a client-side serialized string is a
stack/architecture decision, not a requirements one — deferred to
implementation, but the *shape* of what gets persisted (part selections
+ a color-role-to-hex map) is a real requirement stated here so it isn't
silently redesigned later.

## 4. Artist / designer tutorial

A real deliverable, scoped now rather than deferred to "write docs
later," because Phase 2's entire colorization scope depends on someone
other than the original engineer being able to prepare new segmented
parts correctly. It must teach, concretely:

1. **The shape-tagging convention** from §3: how to take a compound path
   from a raw Open Peeps SVG, split it into per-color-role sub-paths in
   a vector tool, assign each a stable `id`, and write the manifest
   entries that map those IDs to color roles.
2. **How to verify a new piece works with the engine** — not just "does
   it look right alone" (the v1 review checklist already flags this
   exact failure mode from the pilot: an item that's fine in isolation
   but wrong when composited). The tutorial needs a checkable procedure:
   render the new part inside at least one full look (combined with an
   existing body/outfit/other parts) and visually confirm registration
   (position/scale alignment) and that no unintended region picked up
   the wrong color role.
3. **What NOT to do** — e.g. don't hand-edit the raw downloaded SVG's
   existing `id`s that Open Peeps' own convention already uses
   (`head/...`, `pose/standing/...`), since the harvesting/extraction
   tooling built in Phase 1 will likely key off those; add new `id`s
   for newly-split sub-shapes instead of renaming existing ones.

This tutorial cannot be fully written until Phase 2's spike (§2)
produces at least one real worked example — the tutorial's own
usefulness depends on documenting a technique that's been proven once,
not a hypothetical one.

**Sequencing, sharpened 2026-09-11 (the operator's own call):** don't start
the tutorial until there's a working demo of the whole project, not
just after Phase 2's spike. His reasoning: too much could still change
between a one-item spike and a working demo, and a tutorial written
against an interim state risks needing a rewrite once the real shape
settles. So the spike still has to happen first (it's what the tutorial
would document), but "spike done" is necessary, not sufficient — the
tutorial itself waits for a working demo.

## 5. Stack decision

Python remains the operator's default lean, and nothing here rules it out —
but this project's actual bottleneck is different from a typical CRUD
app's, and the decision should be justified against that bottleneck
rather than defaulted into:

- The core unsolved work (§2 Phase 2, §3, §4) is **SVG path
  manipulation and segmentation tooling** — parsing compound path `d`
  data, splitting it into sub-paths, reassigning `id`s, validating the
  result renders correctly. This is a real, standalone deliverable
  (arguably more valuable than the eventual editor UI, since it's the
  part nobody else has published), not incidental app glue.
- Python has mature, well-known SVG/path libraries (`svgpathtools`,
  `svgelements`, `lxml` for the XML/manifest side) and is a reasonable
  fit for a segmentation/extraction *pipeline* — a batch tool an artist
  or engineer runs, not a browser runtime.
- The **rendering/interactive editor** side (click-to-equip/unequip,
  live recoloring preview) is a different concern from the pipeline: SVG
  recoloring at runtime is natively a browser/DOM operation (swap `fill`
  attributes live), which argues for a JS/web frontend for that part
  regardless of what the pipeline is written in — this mirrors the
  pilot's own Toolkit/demo split (a backend/toolkit package plus a
  demo consuming it) rather than contradicting it.
- **Proposed split**: Python for the offline extraction/segmentation/
  tagging pipeline and manifest generation (the real, novel engineering
  this project is actually contributing); a JS/web frontend (framework
  choice deferred) for the interactive editor that consumes the
  manifest + tagged SVGs at runtime. This is a decision to make now in
  principle (pipeline vs. runtime are different problems needing
  different tools) even though specific framework/library choices
  within each side are implementation detail, not requirements.
  - **Update, 2026-09-24:** the frontend's framework question is settled.
    The editor shipped as plain HTML/JS with no framework:
    `frontend/index.html` loads `logic.js` and `app.js` directly, plus
    `style.css`. See open question 7 in §7.

## 6. Out of scope (explicitly)

Stated so it isn't silently designed in later, matching
`paper-doll-workshop`'s own discipline:

- **No detail about the future app** this toolkit will be embedded in —
  not its name, its users, its business logic, nothing. This document
  and this repo only cover the toolkit itself.
- **No automatic/AI-assisted segmentation** of compound paths into
  color regions. Phase 2 assumes manual (tool-assisted, but
  human-driven) segmentation per the tutorial in §4; automating that
  segmentation is a plausible future idea but is not scoped, sized, or
  assumed here.
- **No Gumroad-sourced (paid) assets** until and unless someone
  explicitly acquires and researches that library (§2 Phase 3) — this
  document does not assume it exists, is a superset, or is needed.
- **No non-Open-Peeps art sources.** This is an Open Peeps toolkit, not
  a general paper-doll engine that happens to start with Open Peeps —
  unlike the mothballed pilot, which used placeholder shapes precisely
  because it wasn't committed to one art source.
- **No commitment to a specific number of Phase 2/3 colorizable items by
  a specific date** — see the Phase 2 spike requirement in §2; any such
  number stated before the spike runs would be invented, not derived.
- **No animation, posing beyond the pose swaps Open Peeps itself
  ships, or any dynamic/generative art** — this is a recoloring and
  part-recombination engine over static hand-drawn line art, not an
  animation or generative-art tool.

## 7. Delivery / done-when, and open questions

### Done-when, Phase 1

- All (or a documented subset, with reasons for exclusions) of the 30
  standing-pose SVGs have their head/face/facial-hair/accessories/outfit
  groups extracted into a catalog.
- At least one real cross-file recombination has been rendered and
  visually verified (e.g. sample #7's hairstyle placed onto sample #1's
  body) — proving alignment, not assuming it (see open question below).
- The extraction is scripted/repeatable (not a one-off manual edit),
  since Phase 3 needs the same process applied to sitting/bust poses
  later.

**Correction, 2026-09-12: the above "visually verified" render never
covered feature visibility, only silhouette/alignment.** Found while
tuning Phase 2's colorization, not by any Phase 1 check: most
`face`/`facial-hair`/`accessories` items across the whole catalog
rendered as blank/invisible (a raw source file sometimes puts
`fill="#000000"` on a slot's own wrapper `<g>` rather than on the path
inside it, and `pipeline/extract.py` dropped that when stripping the
wrapper). Fixed (`group_own_style`, `assets/catalog/BUILD_NOTES.md`'s
"second real bug" section has the full mechanism); rebuilding changed
35 of 105 items' SVGs. The lesson generalizes the same one
`BUILD_NOTES.md`'s first bug already drew: a render that checks
alignment/shape is not the same control test as one that checks every
layer is actually visible — this session's "visually verified" claims
going forward mean both were checked, not just alignment.

### Done-when, Phase 2

- The spike (§2) has produced one real segmented, colorizable clothing
  item, rendered with at least two different chosen colors, verified by
  an actual screenshot per the v1 review checklist's existing rule (not
  a DOM/structure check).

**Spike done, 2026-09-11.** `plans/phase2-colorization-spike/` (script,
manifest, segmented SVG, two real rendered PNGs, and an honest
`README.md` of what worked and what didn't). Segmented
`resting/outfit/resting-1`'s one visible bare-skin patch (an ankle) out
of its single, un-split `Background` silhouette via a Shapely boolean
cut (approximating what a real vector-tool cut would do — see the
README's "What a real tutorial needs to teach instead" section, this is
explicitly not the production technique). Rendered with two independent
color choices, both correct. Real time cost recorded: ~2 hours, ~75% of
it spent finding a workable target and technique (two earlier attempts
on hand/finger regions failed for structural reasons, not code bugs)
rather than on the segmentation itself — a flat "N items × time" estimate
would be wrong; see the README's actual breakdown.

**Extended to a second outfit, 2026-09-11: `resting-2`** (the
color-inverted sibling of `resting-1`, same sub_family, same pose).
Confirms — not just carries forward — the "skin color shareable across
outfits" assumption from §2, for real: `resting-1`'s exact cut
coordinates, reused unchanged (not re-derived) on `resting-2`, produced
a skin region of identical area (2058.9331 both times, persisted in
`manifest.json`'s `region_area` field) and rendered
correctly with both color variants, despite `resting-2`'s `Background`
path being structurally different (2 subpaths, not 1 — this item's
ink/background color assignment is inverted). Confirmed for this one
same-pose pair, not yet generalized to every sub_family/pose — see the
spike README's "Remaining open items" for what would still need
checking (a pose where a limb's visible length/position actually
differs between same-sub_family outfits).

The tutorial (§4) is *not* a Phase 2 exit criterion (corrected
2026-09-11 — it was listed here in the first requirements pass, before
The operator sharpened the sequencing): it waits for a working demo of the
whole project, which Phase 2 alone doesn't constitute. See §4's
sequencing note.

**Curated set wired into the live app, 2026-09-11.** Rather than scale
the spike's technique to the full 105-item catalog next, the 10
already-segmented curated items (one outfit per reachable sub_family;
`crossed_arms` confirmed unreachable, see the spike's
`crossed_arms_unreachable.py`) were applied directly to the real
catalog and served by the actual running app — not left as a standalone
spike. `pipeline/colorize_curated_set.py` overwrites those 10 items'
real `assets/catalog/parts/**/*.svg` files in place and adds each
one's `color_regions` to `assets/catalog/manifest.json` (verified
byte-identical to the spike's own already-reviewed segmented SVGs).
The backend (`toolkit/validation.py`'s `_validate_colors`) accepts an
optional `colors` dict on `POST /api/looks`, filling in any
unspecified role from that item's own manifest default and rejecting
colors entirely for a non-colorizable outfit; `GET /api/catalog` and
`GET/POST /api/looks` round-trip `color_regions`/`colors`. The frontend
renders a colorizable outfit as inline SVG (fetched text, recolored by
string replacement on `id="<shape_id>" fill="..."`) instead of `<img>`,
with one `<input type="color">` per region shown only when the
equipped outfit has any; a non-colorizable outfit still renders as a
plain `<img>` with no picker shown. Verified live end-to-end with a
real headless-Chrome pass (`scripts/colorize-e2e-check.js`,
screenshots in `scripts/evidence/`; that check broke with plan 19
step 3a (category rows) and step 3c-1's Skin group, and was rewritten
in plan 19 step 3a-2, runs in `scripts/evidence/3a-2/`): picker changes visibly recolor
the live preview, and a saved look's colors persist through a full
page reload and re-load from the server. This full-stack wiring caught
one real bug no unit test on either side had already covered:
`frontend/logic.js`'s `equipItem`/`unequipItem` silently dropped the
`colors` field from state entirely when a non-outfit slot was equipped
after a color was set, crashing the color-picker render — fixed, and
now covered by dedicated `node --test` regression tests. Scaling
colorization beyond these 10 items to the rest of the catalog remains
future work, not started here.

**Box-fit tuning, 2026-09-12.** Direct feedback that colorization
"isn't very accurate": the box-cut technique's rectangular skin region
sometimes bled well past the hand into what should stay clothing-colored
(`blazer-1`, `easing-1` — the box's excess area happened to fall
*inside* the jacket's own undivided fill, not off the silhouette
entirely, unlike the ankle/leg items). Diagnosed by rendering each
curated item large with its cut box drawn over the actual linework
(not just trusting the coordinates), then re-fit both boxes to hug the
real hand outline: `blazer-1` (105,178,210,262) → (110,200,198,262);
`easing-1` (80,210,170,300) → (83,245,148,292). The other 8 items
(`resting-1/2`, `shirt-1`, `walking-1/2`, `pointing_finger-1`,
`polka_dots`, `robot_dance-1`) were checked the same way and already
fit well — left unchanged. This is still the same box-cut technique,
tuned, not replaced: a rectangle still can't perfectly hug a curved or
angled seam, so some approximation remains inherent to it. Genuinely
precise regions still need real path-tracing along the artwork's own
contours, which is a bigger, separate piece of future work.

**Regenerated from the real library data, 2026-09-12 (the operator:
"regenerate the 10 existing items from the library data") — the
box-cut approximation above is gone, not tuned further.**
`plans/sketch-source-extraction-spike/color_roles.py` found that
`open-peeps.sketch` already defines exact, non-rectangular per-garment
regions with real palette-derived default colors (see that script's
README). `pipeline/regenerate_curated_colorization.py` (which replaces
and removes `pipeline/colorize_curated_set.py` — re-running the old
script is no longer possible, and would have silently regressed this
work) rebuilds all 10 curated items' SVGs and `color_regions` directly
from this source: `blazer-1`'s jacket and pants are now two
independently-colored regions instead of one merged, eyeballed
`clothing-primary`, and every item's default colors are the actual
`Skin/Chromatic` palette values Pablo Stanley chose (e.g. `Skin/03`
&rarr; `#D08B5B`, not the old shared `#E8A16D` no real swatch matched).
Region count and names now vary per item, matching what that specific
pose's own artwork actually separates (`shoes` and, for `shirt-1`
specifically, `prosthesis`, are now colorable too, where they weren't
before).

Technical approach: each item's own per-pose coordinate transform
(Sketch's full-body pose canvas, e.g. 1645×2500, into this project's
own per-family `canonical_viewbox` -- a value that has since moved
more than once as real positioning/clipping bugs were found and fixed
post-launch, e.g. blazer's is `-12 -23 270 714` as of 2026-09-13's
catalog-wide canvas-bounds fix, not the `249×686` this technical
approach was originally derived against, immaterial to the point being
made here since the TRANSFORM derivation itself doesn't depend on the
canvas size staying fixed) is derived
once by `plans/sketch-source-extraction-spike/calibrate_curated_colorization.py`
by comparing the Sketch-derived Ink bounding box against the
*pre-regeneration* committed Ink shape (`git show 06fe176:...`, the
last commit before any regeneration existed) for that same pose — not
assumed to share a scale with the head/face/facial-hair/accessories
atoms-canvas calibration from `plans/head-crossfamily-spike/`, which is
a different source canvas entirely. This is deliberately NOT derived
live from "the current committed file" on every run: an earlier draft
did that and was caught, by this project's own byte-diff regression
test, silently drifting further off on each re-run once the "current
committed file" became the script's own prior output rather than the
pristine original — the fixed version persists the one-time result to
`curated_colorization_calibration.json` and `pipeline/regenerate_curated_colorization.py`
reads it as a constant.

Verified for real, not just claimed: `plans/sketch-source-extraction-spike/verify_all_ten_ink_alignment.py`
renders each of the 10 items' pre-regeneration Ink silhouette (red) and
post-regeneration Ink silhouette (blue) from the same two sources
above, overlaid, for all 10 poses — committed at
`plans/sketch-source-extraction-spike/output/ink-alignment-montage.png`
(and one `ink-alignment-overlay-<item>.png` per item, individually
opened and checked, not just the montage thumbnail glanced at whole —
a first pass of this exact paragraph skipped that per-item check and
undersold what the images actually show, caught by the post-commit
review of `689e5dc`). 8 of the 10 (`easing-1`, `pointing_finger-1`,
`polka_dots`, `resting-1`, `resting-2`, `robot_dance-1`, `walking-1`,
`walking-2`) show only a small, localized red sliver at an internal
region-boundary seam (e.g. a hand-pocket notch, where one old merged
fill is now split into two adjacent new ones). The other 2 are more
pronounced: `blazer-1` has a thin but continuous red line the full
length of its front leg/shoe outline, and `shirt-1` has a much more
visible continuous red gap along its entire prosthetic-leg outline (a
newly-independently-colorable region this regeneration introduced) —
the most visually prominent artifact in the whole set. Neither is a
real misalignment: both were cross-checked against a real, live
in-app composited render at full size — `blazer-1` against the
already-committed `scripts/evidence/regen-colorization-before.png`,
`shirt-1` against the newly-committed
`scripts/evidence/regen-colorization-shirt1-live-render.png` — and both
show a crisp, single, artifact-free Ink outline with no visible gap or
doubling anywhere, including at the specific spots the overlay flags.
The red fringing is therefore a rasterization artifact of this
verification method itself (isolating and independently rasterizing
two separately-authored SVG documents — the pre-regeneration hand-cut
file and the freshly Sketch-extracted one — accumulates tiny
sub-pixel boundary differences that read as a visible line once
stretched along a long, mostly-straight edge like a leg outline),
not evidence the transform is wrong; the real shipped asset in both
cases renders correctly. Only blazer-1 was additionally checked by
hand during development before trusting the same code path for the
other 9; the montage is what closes that gap for the rest, replacing
an earlier, uncommitted `/tmp` dry-run render that was viewed once
in-session but never saved as durable evidence — a real gap the
post-commit review of `ff70b3d` (`reviews/log/ff70b3d.md`, Finding 3)
caught.

**Shared skin color, head included, 2026-09-12 (the operator, after the
head-rendering fix above: "hair doesnt ruin faces anymore. next to
make all skin colors the same, including the face. and then be able to
switch them with a button.").** Until now, an outfit's own "skin"
color_region only reached the hands/neck patches the outfit's own SVG
draws — the head/face's own visible skin area (the head's white
head-silhouette shape, previously fixed white always) never matched.
`pipeline/add_skin_region_to_heads.py` gives every one of the 279 head
items its own "skin" color_region, pointed at that same white shape
(every real head SVG had exactly one when this shipped, confirmed by
survey, not assumed; since 2026-09-24 the 18 `hat-beanie`/`hat-hip`
heads also have a separate, always-white hat shape that is not skin,
see `pipeline/split_hat_fill_from_skin.py`; 2026-09-24, backlog-plan-18
step 1b: the 18 `Turban`/`Hijab` heads got the same split, after the whole
Turban wrap and Hijab's two white fabric-highlight strips were measured
rendering skin-coloured in all 9 sub_families,
`scripts/evidence/hat-beanie-fill/turban-hijab/README.md`; since
2026-09-25 those hat and cloth shapes have their own colour roles, see
"Hats as a layer" at the end of this file) with a `#FFFFFF` default — deliberately not a skin tone, so
a non-colorizable outfit's head renders exactly as before (no "skin"
value ever enters `state.colors` for it). At the time this shipped, 13
real outfit items had no color_regions and would have hit this
fallback; all 23 are colorizable now
(`pipeline/scale_colorization_to_all_outfits.py`, 2026-09-12 —
corrected here, `reviews/log/5b7fd7e.md`), so this fallback is
currently unexercised by any real catalog row, but stays correct for a
hypothetical future non-colorizable outfit. No rendering-engine
changes were needed at all: `frontend/app.js`'s `renderPreview()`
already loops over every equipped slot generically and applies the one
shared, flat, role-keyed `state.colors` dict to whichever item declares
matching `color_regions` — confirmed by reading it, not assumed —so
giving the head the same "skin" role name an outfit's regions already
use was enough for the exact same chosen color to reach both.

Also added the "switch them with a button" ask: a "Switch skin tone"
button (`frontend/logic.js`'s `SKIN_PALETTE`/`cycleSkinTone`,
`frontend/app.js`'s `renderColorPickers()`) that steps through Open
Peeps' own real `Skin/00`-`Skin/05` swatches (from
`plans/sketch-source-extraction-spike/color_roles.py`'s style catalog,
not picked by hand) via the same `setColor()` path the per-region
`<input type="color">` pickers already use — shown only when the
equipped outfit has a "skin" role. A real bug this caught before
shipping: `renderColorPickers()`'s early return for a non-colorizable
outfit hid the whole `<section>` but never reset the button's own
`hidden` attribute, so switching colorizable → non-colorizable → back
left it in a stale state invisible only because its container was
hidden — fixed, and pinned by a live e2e check
(`scripts/skin-tone-feature-e2e-check.js`) that specifically exercises
that exact switch sequence, with screenshots in `scripts/evidence/`.
(Since 2026-09-24 the button sits in the Colors section's one Skin group
and is built with it, so there's no separate `hidden` state to go stale:
see "One skin control" at the end of this file. That check no longer
tests the switch sequence above: it was rewritten the same day to check
one visible button in the whole page, inside the Skin group, across
body switches, and head, outfit and swatch agreeing on each tone; log
`scripts/evidence/skin-control-3c1/skin-tone-e2e-run.log`.)

**Robot_dance's default outfit fixed to match easing's, 2026-09-12
(the operator: "the easing pose looks quite good, with multiple color swap
options that work well. use it as the template for how they should
look.").** Investigated whether the poses with fewer color regions
(`pointing_finger-1`/`resting-1`/`robot_dance-1`/`walking-1`, 3 regions:
skin/shoes/top) were missing a real, extractable "pants" region --
checked directly against the `.sketch` source via
`color_roles.py`'s `find_colored_regions()`: each of those symbols
genuinely has only 4 labeled shapes total (Skin, Shoes, Top, Ink) —
their pants are baked into the black Ink shape itself in the original
artwork, not a separate Chromatic-colored piece our extraction missed.
`easing-1` has 4 colorable regions because its outfit design genuinely
has an extra garment layer (a jacket over a top), not because of
anything this project chose — there's nothing to "fix" at the
region-count level for the sparser poses; they're already exposing
every real colorable shape their own art has.

The one real, fixable gap found: `robot_dance` was the only
colorizable sub_family whose curated, colorizable outfit
(`robot_dance-1`) sorted LAST in the manifest, behind two
non-colorizable outfits (`robot_dance-2`, `-3`) — clicking the
"robot_dance" body-style button defaulted to a non-colorizable outfit
and showed zero color pickers, unlike every other colorizable
sub_family (where the curated item happens to sort first, by
coincidence, not design). Fixed with a new `frontend/logic.js` function,
`defaultOutfitForSubFamily()`, which prefers a sub_family's own curated
outfit over plain manifest order — used only at the one call site that
picks a body-style button's default outfit
(`frontend/app.js`'s `renderBodyStyleOptions()`); `firstItemForSlot()`
itself is untouched and still plain-order for every other caller
(head/face defaults), since only the outfit default needed this
preference. Verified live for all 8 colorizable sub_families, not just
robot_dance (`scripts/default-colorizable-outfit-e2e-check.js`).

**Correction, 2026-09-12 (`reviews/log/fe6ddf2.md`):** the paragraph
above described `defaultOutfitForSubFamily()` as picking "a
sub_family's own curated outfit," but the shipped logic actually picked
"the first colorizable outfit in manifest order" — still order-
dependent, just over a narrower (colorizable-only) list. This didn't
matter for `robot_dance` (only one colorizable candidate), but `resting`
and `walking` each have TWO colorizable outfits
(`resting-1`/`resting-2`, `walking-1`/`walking-2`), and the real fix
never distinguished which one is canonical — `resting-2`/`walking-2`
were winning by manifest-order luck, the same failure mode this fix
was meant to eliminate, just not yet visibly broken. Fixed for real:
every curated item across the whole catalog is named either
`<sub_family>-1` or bare `<sub_family>` (confirmed against the live
manifest, not assumed), so `defaultOutfitForSubFamily()` now prefers
that specific naming pattern among colorizable candidates, falling
back to manifest order only if no candidate matches it. Re-verified
live: `resting`/`walking` now default to `resting-1`/`walking-1`, not
`-2`. Added a regression test using a two-colorizable-candidate
fixture (`frontend/tests/logic.test.js`), the exact case the original
tests never exercised.

**Real bug fixed, 2026-09-13 (the operator, live in the app: "the head on
crossed arms is broken").** Root cause, confirmed before writing any
fix: the `.sketch` source draws "skin" not as a small neck/hand patch
but as a full-body base-fill layer, correctly hidden everywhere a
garment (or, in the real Sketch composition, a head) draws on top of
it — `blazer-1`'s own "skin" region has the exact same
whole-figure-spanning bounding box, it just happens to be fully
covered by its own head placement, so nothing was ever visibly wrong
there. For `crossed_arms` specifically, every real head style
(checked against all of them, not just the default) reaches down less
far than this pose's own "skin" layer extends up to, exposing a
disconnected-looking sliver above the head — confirmed independent of
which specific head style is equipped (both a native head, Cornrows,
and a cross-family one, Afro, showed it) and independent of whether
the outfit renders as `<img>` or inline `<svg>` (an early, wrong
hypothesis — reverting the outfit to plain `<img>` rendering was
tried first and didn't fix it, ruling that out before looking further).
Fixed by adding an optional `region_clip_min_y` parameter to
`pipeline.regenerate_curated_colorization`'s `generate_one()` (`None`
for every item by default — zero effect on the original 10 or the
other 11 of the 13 scaled-up items, confirmed byte-identical) that
clips one named region to a Y floor via a native SVG `clipPath`, no
shapely/manual bezier math needed. `pipeline/scale_colorization_to_all_outfits.py`
applies this to `crossed_arms-1`/`crossed_arms-2`'s "skin" region at
y=105 — a few units below the shortest-reaching real head style for
this sub_family (`Shaved-2`, reaching to y=112.8, checked against
every crossed_arms head style's own Ink bounding box). Verified live
across multiple head styles including the worst case
(`No-Hair-1`/`Shaved-2`, both bald/short) and re-confirmed recoloring
the "skin" role still works correctly post-clip.

**This "verified live" claim was false, not just optimistic — corrected 2026-09-13
(later the same day).** The live check described above apparently
looked at whether a color change applied at all (it does), not whether
the region was fully, correctly visible — it was not. The operator, live,
several hours later: "crossed arms has half a white hand and a white
neck." Measured directly: this clip didn't just trim a sliver, it
removed the entire face, the entire neck, and roughly the top half of
the crossed-hands geometry (the "skin" shape's real Y-range is
-1.27..583.59; y=105 sits 106 units into a ~585-unit shape, not near
its edge). `REGION_CLIP_MIN_Y` has since been emptied and this
mechanism retracted — full incident write-up in this file's own
"Correction, 2026-09-13 (later): the entry above badly understated
this" section, further down. Left standing here, corrected rather than
deleted, per this file's own convention — but flagging plainly: this
paragraph's own verification was not as thorough as it claimed to be,
and that gap is exactly what let a severe regression ship same-day
without being caught until a live user report.

### Open questions — genuinely unresolved, not decided here

1. **Cross-file alignment (the headline risk) — resolved for real, all
   30 files, 2026-09-11.** First narrowed to just the `shirt` sub-family
   by `plans/alignment-spike/` (a 6-file manual spike), then fully
   closed by Phase 1 step 1's actual pipeline (`assets/catalog/`,
   `pipeline/render_check.py`): all 30 real downloaded files pass a
   self-reconstruction control test, and all **9** real pose sub-families
   (`shirt`, `blazer`, `crossed_arms`, `easing`, `pointing_finger`,
   `polka_dots`, `resting`, `robot_dance`, `walking` — the spike's guess
   of 2 sub-families was wrong, corrected here) got a genuine cross-file
   head swap, real rendered PNGs, actually looked at (8/9 also got a
   genuine cross-file outfit swap — `polka_dots` only has one outfit
   variant among its 2 files, honestly not faked). Cross-*family* swaps
   (e.g. a `shirt` head on a `blazer` body) remain untested and are not
   assumed to work — the product decision (§backlog-plan-1.md's shared
   contract) is that a look never mixes sub_families, so this isn't
   blocking Phase 1.
2. **Segmentation cost (Phase 2's real driver).** No data exists yet on
   how long it takes to hand-segment one compound path into color
   regions, or how consistent that process is across different
   artists/tools. The Phase 2 spike (§2) is meant to answer this, but
   until it runs, any statement about how many items can be colorized
   in a given timeframe is a guess.

   **Potentially changed, 2026-09-12 — flagged here explicitly, not
   left only in the spike's own README (per `reviews/log/53887b4.md`'s
   finding that a strategic implication like this belongs in this
   tracking document, not just a sibling directory).**
   `plans/sketch-source-extraction-spike/color_roles.py` found that
   Open Peeps' own `.sketch` source already has real, per-shape
   skin/hair/clothing segmentation and color-role data (named Sketch
   shared styles, resolved via each shape's `sharedStyleID` — see that
   script's README for the full finding). If this generalizes cleanly
   across the library, "segmentation cost" may drop from "hand-tag each
   item's regions" to "read the region + role directly from the source
   file" for items reachable this way — a fundamentally different cost
   structure than what this open question originally assumed.

   **Confirmed as the real replacement for the 10 curated items,
   2026-09-12 (the operator: "regenerate the 10 existing items from the
   library data").** `pipeline/regenerate_curated_colorization.py`
   integrated this into `pipeline/` for real, replacing and removing
   `pipeline/colorize_curated_set.py` (re-running the old script is no
   longer possible). All 10 curated items now come from this source
   directly, with real per-garment regions instead of one merged
   hand-cut region. Still not confirmed to generalize beyond these 10
   poses to the rest of the ~105-item catalog — that remains future
   work, not started here — but the "read from the source instead of
   hand-tagging" cost structure is now proven for real, live-checked
   items, not just a hypothesis.

   **Generalized for real, 2026-09-12 (the operator: "do the scaling
   colorization. we dont need to build beyond the three tiers, we are
   good on body diversity.").** The "~105-item catalog" figure above
   was already stale by this point — the real, live catalog has 23
   outfit items, not ~105 (that count was for the pre-head-scale-up
   catalog's total across every slot, not outfit specifically; the
   422-item catalog's actual outfit count was never re-checked here
   until now). `pipeline/scale_colorization_to_all_outfits.py` reused
   `generate_one()` unchanged for the remaining 13 outfit items, with a
   new one-time calibration derivation
   (`plans/sketch-source-extraction-spike/calibrate_remaining_colorization.py`)
   reading each item's own currently-committed (untouched, pristine)
   Ink shape as ground truth, the same technique
   `calibrate_curated_colorization.py` used but without needing to
   reach into git history, since these 13 were never previously
   overwritten. All 23 real outfit items are colorizable now — the
   "generalize beyond these 10 poses" question this paragraph raised is
   answered: yes, cleanly, with the exact same per-shape-segmentation
   technique and no new per-item hand-tuning needed. Also resolves item
   4 below's `crossed_arms`-unreachable finding: that was a limitation
   of the old box-cut geometric technique specifically (no boundary-
   detectable edge between crossed hands and the torso), not the real
   source art — the real `.sketch` data has `crossed_arms`' skin as its
   own explicitly labeled, independently-colored shape, reachable the
   same way every other pose's skin region is. Verified live for all 8
   affected sub_families, both via DOM/attribute assertions and a real
   rendered screenshot per sample
   (`scripts/scaled-colorization-e2e-check.js`, retired in plan 19
   step 3a-2, see `scripts/RETIRED.md`; all 8
   `scripts/evidence/scaled-colorization-*-skin-recolored.png` files,
   each opened and visually confirmed correct — an earlier draft only
   saved one of the 8 screenshots while the accompanying prose implied
   all 8 were rendered-checked, caught by `reviews/log/5b7fd7e.md`) —
   and with regression tests mirroring
   `pipeline.regenerate_curated_colorization`'s own suite
   (`pipeline/tests/test_scale_colorization_to_all_outfits.py`),
   including a byte-diff test confirmed (not just claimed) to catch a
   real regression via a deliberate calibration-offset injection, then
   restored — a real, committed transcript of the fail/restore/pass
   sequence is at
   `plans/sketch-source-extraction-spike/output/scale_colorization_bytediff_regression_confirmation.txt`
   (`reviews/log/5b7fd7e.md` flagged this exact claim as unverified by
   its own sandboxed review, since it couldn't execute the test
   itself).

   **Correction, 2026-09-13 (`reviews/log/8886e42.md`):** "visually
   confirmed correct" above was wrong for `crossed_arms` specifically —
   The operator caught a real, reproducible bug in the live app the next day
   ("the head on crossed arms is broken") that this same evidence
   should have shown. It didn't, because that check only equipped one
   default head style per sample and looked at the outfit's own
   recoloring in isolation, not specifically at the head/neck boundary
   — the bug (a disconnected skin-colored sliver above the head) is
   real regardless of which head style is equipped, but easy to miss
   at a glance when not specifically looking for it. Root cause and fix
   are in the "Real bug fixed, 2026-09-13" entry earlier in this
   document (right before this Open Questions section starts).
3. **Skin-color reuse assumption — confirmed AND shown to break,
   2026-09-11, corrected general rule now stated.** §2 Phase 2 assumed a
   peep's skin shape is stable across different outfits (so skin
   segmentation done once per pose might be reusable across all outfits
   for that pose). `plans/phase2-colorization-spike/` confirmed this for
   two same-pose pairs on two different limbs (`resting-1`/`resting-2`,
   ankle; `walking-1`/`walking-2`, forearm) — reusing one item's exact
   cut, unchanged, against its sibling produced an identical-area skin
   region both times, rendering correctly. But a deliberate search for a
   same-sub_family pair where garment coverage actually differs — asked
   for specifically: a sleeve-length difference — found none exist
   anywhere in this catalog. Confirmed across all 7 sub_families with
   multiple outfits, not 5: a first pass claimed the check was
   exhaustive while actually missing 2, caught by review and corrected
   (see the spike README's "Searching for a sleeve-length difference").
   The search found a real analog in leg coverage instead: `shirt-1`
   (shorts, exposed leg) vs. `shirt-3` (full
   pants, no exposed skin at all), same sub_family, same canonical pose.
   Reusing `shirt-1`'s cut on `shirt-3` produces a visibly wrong
   render — a fake skin patch where the real art has none — proving the
   assumption is **not** a general property of "same sub_family."
   **Corrected rule:** a cut is safe to reuse across outfits only when
   the target region's actual coverage is confirmed the same in both,
   never merely because they share a sub_family or canonical pose.

   **Generalized from a single pair to the norm, 2026-09-12 — checked
   for real, not assumed** (`plans/phase2-colorization-spike/sibling-reuse-check/`):
   tried reusing each curated item's `cut_box` on all 11 of its sibling
   outfits across `blazer`, `easing`, `pointing_finger`, `robot_dance`,
   `shirt`, and `walking`. **Zero reused cleanly.** Not just garment
   coverage (more `shirt`-shaped full-pants siblings found) — arm/hand
   *position itself* differs freely between sibling outfits in the same
   sub_family (`blazer-2/3/4`, `pointing_finger-2`, `robot_dance-2/3`,
   `walking-3` all have a different pose than their curated sibling, not
   just different clothing on the same pose). Real, rendered evidence
   for all 11 in that directory. This means head/face/facial-hair/
   accessories sharing one canonical anchor per sub_family (extensively
   confirmed, e.g. `plans/head-crossfamily-spike/`) is a fact about
   *those specific slots*, not evidence the outfit layer's pose is
   shared too — each outfit is its own independent illustration.
   Concrete consequence: scaling colorization beyond the 10 curated
   items has no shortcut via box reuse; every additional item needs the
   same per-item visual check and (usually) per-item box tuning the
   original 10 each got — confirmed, not just assumed to be slow.
4. **Curated demo set built, 2026-09-11 (the operator's own call): 9 of 9
   reachable sub_families now have one segmented, colorizable item,
   not the full 105-item catalog.** Deliberate scope decision: colorize
   enough for a working demo to look real, and defer full-catalog
   coverage until the demo direction is validated (see
   `plans/backlog-plan-1.md`'s tutorial-sequencing note for the same
   reasoning applied to the tutorial). `blazer-1`, `easing-1`,
   `pointing_finger-1`, `polka_dots`, `robot_dance-1` added alongside
   the three already-done items — each a hand hanging free from the
   torso, the one shape this box-cut technique reliably reaches.
   `crossed_arms` has no reachable item: its only exposed skin (crossed
   hands) sits directly on the torso with no boundary-detectable edge
   separating it from the chest, confirmed by direct path-boundary
   sampling, not assumed — a real, structural limit of this technique,
   not a skipped attempt (**resolved 2026-09-12 by abandoning this
   box-cut technique in favor of reading the real per-shape Sketch
   data directly — see Open Question 2's "Generalized for real"
   update, above; `crossed_arms` is colorizable now**). This same pass caught and fixed two real bugs
   in the already-shipped code: a multi-subpath polygon-construction bug
   that silently corrupted `resting-1`/`resting-2`/`shirt-1`'s exact
   region areas (invisible in their renders, only surfaced by a
   3-subpath item), and a non-uniform aspect-ratio stretch affecting
   every rendered item except `resting`. See the spike README's "Curated
   demo set" section for the full writeup, including why neither bug
   was caught by this project's own "verify by looking at the render"
   standard until now.
5. **Sitting/bust pose structure — re-confirmed for real, 2026-09-12,
   with saved artifacts.** All 30 Standing, 49 Bust, and 14 Sitting SVGs
   directly downloadable from openpeeps.com's own CDN were fetched for
   real (`pipeline/fetch_extra_poses.py`, URLs committed at
   `plans/open-peeps-research/openpeeps-{bust,sitting}-svg-urls.txt`,
   every URL spot-checked live). Real samples of each saved and
   rendered as evidence, not just prose: `sample-peep-bust-7.svg/.png`,
   `sample-peep-sitting-1.svg/.png` (alongside the pre-existing
   `sample-peep-standing-30.svg/.png`). Confirmed by direct inspection:
   busts have **no leg/pants group at all** (`viewBox="0 0 240 324"`,
   a headshot-to-mid-chest composition, only a single fused
   `body/<style>` group — no separable lower body exists to attach
   clothing items to; busts are structurally unusable for full-figure
   work without drawing genuinely new lower-body art, not adapting
   anything). Sitting poses ARE full figures with legs, same
   Background+Ink/head+face+facial-hair+accessories+pose group shape as
   Standing, confirmed by direct inspection of `sample-peep-sitting-1.svg`.
6. **Gumroad library contents — researched for real, 2026-09-12.** The
   "Get All Combinations" link on openpeeps.com goes to
   `pablostanley.gumroad.com/l/openpeeps` (pay-what-you-want from $0,
   CC0) — the Sketch/Figma/XD/Studio *source* component library (not a
   pre-rendered bundle of the stated "584,688 possible combinations").
   Downloaded and inspected (kept locally at `assets/openpeeps-source/`,
   git-ignored — 117MB, not pushed). Two real findings from actually
   opening it:
   - `Separate Atoms/pose/standing/*.svg` and `Separate Atoms/body/*.svg`
     looked promising as a possibly-separable body/clothing split, but
     inspection showed `pose/standing/*` is still the exact same fused
     Background+Ink body+clothing shape as every other source (just a
     bigger native Sketch export scale) — no reusable, separate "body"
     component for full figures exists anywhere in this library either.
     (`Separate Atoms/body/*` is the *bust* torso+shirt set specifically,
     e.g. "Turtleneck.svg", "Hoodie.svg" — same no-legs limitation as
     item 5, just organized under a "body" folder name that reads as
     more separable than it is; sample committed, not just described —
     `plans/open-peeps-research/sample-gumroad-atoms-body-Whatever.svg/.png`.)
   - `Separate Atoms/head/*.svg` (46 styles, sample committed at
     `plans/open-peeps-research/sample-gumroad-atoms-head-Buns.svg/.png`)
     and `.../face/*.svg` (30) each share one uniform viewBox per
     category (all heads:
     `viewBox="0 0 473 567"`) — a real, consistent per-category
     coordinate space that the combined pose files don't expose. But
     the flat SVG export strips out *where* a head attaches to a given
     body — that placement only exists as symbol-instance offsets
     inside the proprietary `.sketch`/`.fig`/`.studio` files, which
     nothing in this project can parse yet. So this library has more
     head/face *style* variety than what's already extracted, but does
     not by itself solve cross-pose or cross-body head placement —
     confirming that remains real, unstarted engineering (per item 1
     and open question 8's body/outfit/pose-orthogonality discussion),
     not something a bigger asset download unlocks for free.
   - Bonus, not investigated further: `Templates/covid-19/` (mask-
     wearing variants) and higher raw counts than the CDN-scraped set
     for Sitting (18 vs. 14) and Bust (105 vs. 49) in `Templates/`,
     suggesting the homepage's own "Grab and go" tabs show a curated
     subset, not the library's full count — not pursued further since
     it doesn't change the structural findings above.
   - Also checked while doing this: Blush (blush.design/collections/open-peeps),
     the "Use with Blush" link's destination, is a separate company's
     web tool hosting Open Peeps as one of several licensed illustration
     packs, with a free (PNG, limited selection, no attribution needed)
     and paid (full selection + SVG) tier. No evidence found of body-
     build/bust-size variety there either — every description found
     lists the same customization categories (hair, face, clothing,
     accessories, pose) as raw Open Peeps; the live JS customizer itself
     couldn't be directly inspected by an automated fetch, so this is
     "no evidence found," not a from-the-UI-confirmed absence.
7. **Runtime framework choice for the interactive editor** (§5) — a
   JS/web frontend is the right *category* of tool for live SVG
   recoloring, but no specific framework is chosen here; deferred to
   whoever scopes Phase 1's actual build.
   - **Settled, 2026-09-24:** the app is plain HTML/JS in `frontend/`
     (`index.html`, `logic.js`, `app.js`, `style.css`) with no framework
     and no build step. `frontend/tests/` runs with `node --test`. This
     is no longer an open question.
8. **Full avatar/outfit orthogonality — the real end goal, stated
   2026-09-12, not yet achievable.** the operator's stated direction: any
   avatar (body/face/hair) should wear any outfit, pose changes should
   leave the current outfit on, and outfit changes should leave the
   current avatar intact. One piece of this already works today and is
   what the frontend's body/wardrobe-area split (this date) delivers:
   swapping outfits *within one pose family* already leaves head/face/
   hair untouched, since those are independent catalog items scoped to
   the same sub_family. The other two pieces do not work and can't
   with the current assets: each outfit is hand-drawn art for one
   specific pose only (there is no "blazer jacket drawn in the
   robot_dance pose" asset — a fact about this catalog's actual source
   art, not the same claim as item 1 above, which is specifically about
   cross-*family* head/outfit swaps being untested), and heads are
   baked to a specific pose's neck angle the same way. Reaching the
   real end goal needs one of: (a) commissioning/
   creating outfit art for every pose x outfit combination it should
   support — a content problem, sized by however many combinations are
   wanted, not a code change; or (b) a genuinely different technique
   (rigging/deformation over the existing flat art) that can adapt one
   outfit's art to an arbitrary pose — its own research effort, not
   attempted or scoped here. Not a blocker for the current
   body/wardrobe UI split, which is deliberately built to keep "avatar"
   and "outfit" as separate concepts so it doesn't need re-architecting
   if (a) or (b) is pursued later — but full orthogonality itself
   remains unsolved, and no timeline or specific approach is committed
   to here.

   **A scoped-down alternative, raised 2026-09-12: pick a handful of
   existing body types (i.e. sub_families/poses) and make any head,
   hair, or accessory work on each of them, rather than solving full
   orthogonality across all of them.** This is genuinely more tractable
   than the full goal — it's a bounded version of the same problem, not
   a different one — but it's not free either: heads/faces/accessories
   are already freely swappable *within* one sub_family today (that's
   existing, working behavior), but making a head from a *different*
   sub_family fit a *chosen* one still requires solving the per-family
   neck-anchor placement item 1 above says is untested, just for a
   handful of families instead of all of them.

   **Solved for real, 2026-09-12 — `plans/head-crossfamily-spike/`.**
   Not just the offset for one pair: the *scale* needed to map the
   atoms library's per-category canvas (head/face/facial-hair/
   accessories each have exactly one shared viewBox, confirmed across
   every file, not assumed) onto a sub_family's own space turned out to
   be **universal across every sub_family**, identical to 6 decimal
   places wherever tested. Only the offset differs per sub_family, and
   it's derivable from bounding-box comparison against any one style
   that already exists in both the catalog and the atoms library — no
   access to the proprietary `.sketch`/`.fig` files needed after all.
   Verified by actually rendering 11 genuinely-new (previously
   nonexistent) placements — one new head per sub_family (all 9), one
   new face, one new accessory — and looking at every one; all attach
   correctly. Full methodology, the cross-validated calibration data,
   real renders, and the honest list of what this does *not* solve
   (full-body outfits are still fused; no rotation modeled; facial-hair/
   accessories have partial coverage where a sub_family's only real
   catalog item is `*-None`) are in `plans/head-crossfamily-spike/README.md`.
   *(Superseded 2026-09-24: facial hair and accessories now cover all 9
   poses, placed from each pose's faces. See "Facial hair and
   accessories on every pose" at the end of this file.)*
   **Shipped for real, same day: `pipeline/add_crossfamily_heads.py`**
   adds exactly one new head style per sub_family (9 total: `blazer`+
   Afro, `crossed_arms`+Mohawk, `easing`+Turban, `pointing_finger`+
   Bantu-Knots, `polka_dots`+Bear, `resting`+Pomp, `robot_dance`+
   Shaved-2, `shirt`+Mohawk-2, `walking`+Cornrows-2) directly into the
   real, live catalog (105 → 114 items) — matching this project's
   "curated set, not everything at once" precedent from
   `plans/phase2-colorization-spike/`. Verified live in the actual
   running app, not just the spike's isolated renders
   (`scripts/crossfamily-heads-e2e-check.js`, screenshots in
   `scripts/evidence/`): every new head is a selectable option and
   renders correctly attached for its sub_family.

   **Correction, 2026-09-12 (the operator, live in the app: "most of the
   heads are completely black, the same color as their hair"):** the
   "renders correctly attached" claim above was wrong for most
   cross-family heads, in this module and in
   `pipeline/add_all_heads_to_all_families.py` below. Both built each
   generated head SVG from "the first `<path>` element" in the atoms
   source file; every real `atoms/head/*.svg` has 2+ real paths (a
   white head-silhouette shape plus the black hairline/texture shape)
   in inconsistent order across files, so that grabbed the white shape
   for most (not all) styles and rendered it filled solid black,
   covering the whole head. All 9 of this module's own styles hit this
   (`Afro`, `Mohawk`, `Turban`, `Bantu-Knots`, `Bear`, and, checked
   directly, the rest too) -- and the "verified live" claim's own cited
   evidence already proved it, unnoticed:
   `scripts/crossfamily-heads-e2e-check.js` only ever asserted the
   right item got equipped and its `<img>` decoded without erroring, it
   never inspected what the screenshot actually showed, so the already-
   committed `scripts/evidence/crossfamily-head-blazer-Afro.png` (and
   its 8 siblings) sat in the repo showing this exact solid-black-head
   bug the whole time, unremarked. Fixed for real in both modules
   (`reviews/log/ce5570a.md`), all 250 already-shipped cross-family
   head assets regenerated in place, and regression tests added at both
   the `generate_one()` and live-catalog level that assert the white
   shape's path data differs from the black Ink shape's — a check on
   the actual SVG structure, not just "did an image decode," closing
   the exact gap the e2e check left open. Re-ran
   `scripts/crossfamily-heads-e2e-check.js` after the fix and replaced
   its 9 stale (pre-fix, solid-black-head) screenshots in
   `scripts/evidence/` with fresh ones — each opened and visually
   confirmed correct by eye, not just re-saved on faith.

   **Extended to face, same day: `pipeline/add_crossfamily_faces.py`**
   adds one new face style ("Cute") per sub_family the same way (114 →
   123 items), reusing the spike's already-verified face calibration
   (full 9/9 coverage, same as head). Same live-verification treatment
   (`scripts/crossfamily-faces-e2e-check.js`). A real bug was caught
   and fixed while building this: a first draft's regression test
   called `generate_one()` directly, but that function also contained
   the "does this already exist" guard, so testing it against the
   now-already-modified live manifest always raised — fixed by moving
   that guard to `add_face()` (the side-effecting caller), leaving
   `generate_one()` as pure, testable transform logic only.

   **Correction, same day (`reviews/log/d4b4f92.md`):** the paragraph
   above, and this commit's own message, originally claimed this
   pure-transform/wrapper split "match[ed] `add_crossfamily_heads.py`'s
   existing split" -- false; a direct read of that file at the time
   showed only a single `add_head()` doing everything, no
   `generate_one()`. Rather than just correcting the sentence,
   `add_crossfamily_heads.py` was actually refactored to have the same
   split for real -- so the claim is now true of the code, not just the
   prose.

   **Correction #2, same day (`reviews/log/c7f33c8.md`):** the
   paragraph above originally described the byte-identical/test-catches-
   breakage verification in prose only, with nothing committed that
   would actually re-check either claim later -- the review's own
   attempt to verify it was blocked by sandbox permissions, and rightly
   flagged the gap rather than accepting the prose. Fixed for real:
   `test_generate_one_matches_committed_output_byte_for_byte` (in both
   `pipeline/tests/test_add_crossfamily_heads.py` and its
   `test_add_crossfamily_faces.py` sibling, added the same day for the
   same reason) diffs `generate_one()`'s live output against the actual
   committed SVGs -- confirmed, by deliberately shifting the offset
   calculation by 1 unit and re-running, to actually fail on a subtle
   regression the old assertions (non-empty content, contains the
   sub_family string) would have missed entirely.

   **Extended to facial-hair and accessories, same day:**
   `pipeline/add_crossfamily_facialhair.py` (4 new styles: `polka_dots`+
   Goatee-1, `robot_dance`+Goatee-2, `shirt`+Full-2, `walking`+Chin) and
   `pipeline/add_crossfamily_accessories.py` (6 new styles: `blazer`+
   Eyepatch, `easing`+Glasses, `polka_dots`+Glasses-4, `resting`+
   Sunglasses, `robot_dance`+Glasses-2, `shirt`+Eyepatch) ship for real
   (105 → 133 items), covering only the sub_families with partial
   calibration coverage as documented above (4/9 and 6/9 respectively —
   the other sub_families lack a real, non-`*-None` catalog item for
   that slot to calibrate an offset from, and aren't addressed here).
   *(Superseded 2026-09-24: all 16 facial-hair and all 8 accessory
   styles are on all 9 poses, and both modules are deleted (in git:
   `git show ce0454a:pipeline/add_crossfamily_facialhair.py`). See "Facial
   hair and accessories on every pose" at the end of this file.)*
   Both modules had the `generate_one()`/wrapper split and the byte-
   for-byte comparison test from the start, not retrofitted after a
   review finding, learning directly from `reviews/log/d4b4f92.md` and
   `reviews/log/c7f33c8.md`'s findings on the sibling head/face modules.

   A real visibility gotcha was caught and resolved during this work,
   not a placement bug: the first render of `walking`+Chin against the
   family's own default (a large dark "Long-Afro"/"Long" hairstyle)
   made the black facial-hair shape functionally invisible, blending
   into the adjacent dark hair right at the jaw. Verified the true
   position was correct all along by re-rendering with the atom filled
   solid red instead of black, confirming it sits exactly on the
   jawline as expected — then confirmed the same for all 10 new
   facial-hair/accessories items this way before shipping any of them,
   rather than trusting a black-on-black thumbnail glance.

   **Known, honestly-disclosed limitation, not fixed here:** that same
   `walking`+Chin item is real, correctly placed, and equips
   successfully (all confirmed by the live e2e check,
   `scripts/crossfamily-facialhair-accessories-e2e-check.js`), but is
   still practically **invisible in `walking`'s own default head/
   accessory combination** — its default head is exactly the dark, low-
   hanging "Long-Afro" style responsible for the red-vs-black finding
   above (`scripts/evidence/crossfamily-facial-hair-walking-Chin.png`,
   inspected at the time of shipping, not just the DOM-level "equipped"
   check). Choosing any lighter/shorter head style for `walking` makes
   it clearly visible (confirmed the same way the other 3 facial-hair
   items were — `scripts/evidence/crossfamily-facial-hair-polka_dots-Goatee-1.png`,
   `-robot_dance-Goatee-2.png`, and `-shirt-Full-2.png` all show clear
   contrast against their own defaults). Not fixed because there's no
   single right fix here that isn't a separate, undecided product
   choice: change `walking`'s default head, change `Chin`'s color/
   shape, or accept the ambiguity as expected "your specific
   combination of choices can look different" behavior, the same way
   any two real physical people's dark hair and beard can blend
   together in silhouette art. Left to a future decision.

   **Scaled to every existing head style, 2026-09-12 (the operator: "I want
   each of the heads to work on each of the bodies").**
   `pipeline/add_all_heads_to_all_families.py` generalizes the head
   technique from "one new curated style per family" to every one of
   the 31 distinct head styles that exist anywhere in the catalog,
   placed onto every sub_family missing it — 241 new items (133 → 374
   catalog items total). No new calibration research needed (the head
   slot already had full 9/9 coverage); the only new logic is resolving
   a catalog style name to its atoms-library filename. Verified: the
   generate_one()/wrapper split and a byte-for-byte comparison test
   existed from the start (not retrofitted, learning directly from
   `reviews/log/d4b4f92.md` and `c7f33c8.md`'s findings on the sibling
   modules); a representative visual sample spanning very voluminous
   (Long-Afro), very compact (No-Hair-1), and several culturally
   distinct styles (Hijab, Turban, Bantu-Knots, Twists, Mohawk), each
   placed on a family that never had it before, all attach correctly
   (`plans/head-crossfamily-spike/output/all-heads-scaleup-sample/montage.png`);
   confirmed live in the running app via
   `scripts/heads-scaleup-e2e-check.js` (retired in plan 19 step 3a-2,
   see `scripts/RETIRED.md`; screenshots in `scripts/evidence/`; its
   sample moved to
   `scripts/crossfamily-heads-e2e-check.js`). This closes the "heads" part of this open
   question's original ask; face already had 9/9 native + 9/9
   crossfamily coverage before this, so didn't need scaling.

   **Correction, 2026-09-12 (`reviews/log/b898c02.md`):** the "all
   attach correctly"/"confirmed live" claim above was also false, for
   the same root-cause bug documented in the correction above this
   module's sibling passage — this module shares the exact same
   shape-loading helper `pipeline/add_crossfamily_heads.py` had, fixed
   the same way in the same commit (`reviews/log/ce5570a.md`). A prior
   pass at correcting the sibling passage stopped there and didn't
   extend the same treatment here, even though it named this module as
   also affected — the cited montage and all 8
   `scripts/evidence/heads-scaleup-*.png` files still showed the
   pre-fix solid-black-head bug at the time that correction was
   written. Rebuilt the montage from fresh, corrected screenshots via a
   new `plans/head-crossfamily-spike/output/all-heads-scaleup-sample/build_montage.py`
   (no such script existed before -- the original montage had been
   built ad hoc and was consequently never rebuilt when the underlying
   bug was fixed) and re-ran
   `scripts/heads-scaleup-e2e-check.js` (retired in plan 19 step 3a-2,
   see `scripts/RETIRED.md`) against the live, fixed app; both re-checked by eye, not re-saved on faith.

   **Facial-hair and accessories scaled the same way, same day, across
   each slot's own calibrated families only.**
   `pipeline/add_all_facialhair_to_calibrated_families.py` (16 new
   items, across the 4 sub_families facial-hair has real calibration
   for) and `pipeline/add_all_accessories_to_calibrated_families.py`
   (32 new items, across the 6 sub_families accessories has real
   calibration for) — 133 → 374 → 422 catalog items total. The other 5
   sub_families for facial-hair and 3 for accessories are still not
   addressed — reaching them needs new calibration research (no real,
   non-`*-None` item exists there to derive an offset from), not batch
   generation, and isn't attempted here. *(Superseded 2026-09-24: the
   research was the face. Facial hair and accessories sit at a constant
   offset from each pose's native faces, so all 9 poses now have every
   style, and both modules are deleted. See "Facial hair and accessories
   on every pose" at the end of this file.)* Same discipline as the heads
   scale-up: the `generate_one()`/wrapper split and a byte-for-byte
   comparison test existed from the start, and a real mistake was
   caught and fixed before shipping — the first draft's byte-diff test
   samples included `easing/accessories/Glasses-3`, a *native*
   `pipeline.build` item (with its own internal `<g transform>` baked
   in from the original combined file) that can never byte-match
   `generate_one()`'s flattened-absolute-coordinates output; fixed by
   checking each sample's `source_file` before trusting it as a
   cross-family comparison point, not assuming every pre-existing item
   of a given style was cross-family-sourced. Verified with a
   representative visual sample
   (`plans/head-crossfamily-spike/output/facialhair-accessories-scaleup-sample/montage.png`)
   and live in the running app
   (`scripts/facialhair-accessories-scaleup-e2e-check.js`, retired in
   plan 19 step 3a-2, see `scripts/RETIRED.md`; its sample moved to
   `scripts/crossfamily-facialhair-accessories-e2e-check.js`).

9. **Body-build diversity — the operator's stated requirement (2026-09-12,
   mid-session): full-figure poses across multiple body styles, not
   just the one default build every Open Peeps pose ships with —
   feminine bodies at 3 builds (slender/average/thick) x 3 bust sizes
   (small/medium/large) = 9 combinations, plus masculine bodies at 3
   builds (slender/average/thick). 12 body types total. Not addressed
   in any of this session's shipped work so far (the crossfamily-head/
   face spike solves swapping head/face/accessories across pose
   *families*, not swapping body *build* within a pose — a different
   axis entirely).

   **Checked against the real Gumroad library, 2026-09-12 — not
   reachable by recombining existing assets** (rendered evidence in
   `plans/body-diversity-scoping-check/`). Investigated whether
   `assets/openpeeps-source/flat-assets/Flat Assets/Separate Atoms/body/`
   (30 files) or `.../Separate Atoms/pose/` (23 standing + 11 sitting
   files) contain any body-shape/build variation to build from. They
   don't:
   - Every one of the 30 files in `Separate Atoms/body/` shares one
     uniform 818x733 viewBox — checked with a `grep` loop over all 30,
     not sampled. Rendered (`body/Tee 1.svg` inspected directly), a
     file from this folder turns out to be just the garment's collar/
     shoulder-line outline — a neckline-style swap for the one existing
     body, not an alternate body shape.
   - Every one of the 23 files in `Separate Atoms/pose/standing/`
     shares one uniform 1645x2500 viewBox, and every one of the 11
     files in `Separate Atoms/pose/sitting/` shares its own uniform
     1534x1856 viewBox — both checked with the same all-files `grep`
     loop. Rendered (`pose/standing/shirt-1.svg` inspected directly),
     a file from the standing folder is the exact same fused
     body+outfit content already known from `Templates/Standing/` — a
     re-export of the same single body build, not a second one.
   - No file anywhere in the downloaded library varies torso width,
     limb thickness, or bust size. Open Peeps' entire illustrated
     universe is one body build per pose, dressed differently and
     posed differently — the diversity it does offer (visible in these
     very renders — see `plans/phase2-colorization-spike/sibling-reuse-check/`'s
     evidence images, which show a recurring prosthetic-leg variant) is
     in accessories/adornment, not in body proportions.

   **What this means:** reaching 12 distinct body builds is a genuine
   content problem, not a code or recombination problem — the same
   category of gap item 8 above already identified for full outfit/pose
   orthogonality (art has to exist for a combination before it can be
   shown), just on a different axis (body shape instead of pose). None
   of Open Peeps' CC0 art covers it. Options, none attempted here:
   (a) commission/draw 12 new body-build variants x however many poses
   they need to support (a large, multiplicative content cost — 12
   builds x 9 sub_families x however many outfit variants each has,
   unless outfit art can be shared across builds, which would need its
   own per-build fit-checking the same way `sibling-reuse-check/`
   proved outfit art doesn't reuse cleanly even *within* one existing
   build); (b) find or license a different, separately-illustrated
   figure-diversity library and build the same calibration/placement
   technique from `plans/head-crossfamily-spike/` on top of it, if its
   proportions and pose set are compatible enough; (c) scope down to
   fewer builds than 12 as a first cut. No commitment made to any of
   these here — this is a scoping finding, not a decision.

   **Option (b) checked for real, 2026-09-12 — no compatible candidate
   found.** Searched for a CC0/permissively-licensed, *modular*
   (separate head/body/clothing SVG parts, not one fused illustration)
   figure library that varies body build/weight as a customization
   axis, the same shape of thing Open Peeps itself is for pose/clothing.
   None found. Full quoted evidence (license text, README excerpts,
   URLs) for every claim below is in
   `plans/body-diversity-scoping-check/option-b-alternative-libraries-evidence.md`
   — corrected here, per `reviews/log/56dfa01.md`'s finding, from an
   earlier version of this paragraph that stated these as prose-only,
   uncited assertions:
   - **Humaaans** (Pablo Stanley): CC0, confirmed by its own site's
     license text. Modular head/hair/top/pants parts, but explicitly
     **one body form** — its own page lists only hair, tops, and pants
     as customizable, no body-build axis, the identical gap this
     question is about.
   - **Blush** (already researched this session, `plans/requirements.md`
     item 6): hosts Open Peeps itself as one of several packs; its own
     customization categories (hair, face, clothing, accessories, pose)
     match raw Open Peeps exactly — no evidence of body-build variety
     there either.
   - **DiceBear's `open-peeps` collection is Open Peeps' own art, not a
     different source** — corrected from an earlier draft that wrongly
     called it "a completely different visual identity": this repo
     already has `plans/open-peeps-research/dicebear-open-peeps-LICENSE.txt`,
     naming Open Peeps/Pablo Stanley/CC0 as its design source. The real
     reason it doesn't help is that it's **bust-only**: the
     already-committed `dicebear-open-peeps-types.d.ts`'s `Options`
     interface has no `body`/`weight`/`bust`/`torso` field at all
     (checked by `grep`, zero matches) — same source art, wrong axis.
   - **Boring Avatars**: real open-source (MIT), but its own README
     confirms all six of its visual variants are geometric/abstract
     patterns (marble, beam, pixel, sunset, ring, bauhaus) — not human
     figures at all, let alone ones with a body-build axis.
   - **Multiavatar**: weaker evidence than the other three, disclosed
     as such rather than overstated — a direct fetch of a sample avatar
     was blocked by a Cloudflare challenge, so this project could not
     inspect one directly. The closest available detail (via search,
     not a primary source) is that each avatar has 6 parts —
     Environment, Clothes, Head, Mouth, Eyes, Top — suggestive of a
     head-and-shoulders format but not confirmed here.
   - **Icons8 "Ouch"**: has genuinely modular, customizable illustration
     parts, but is attribution/paid-tier licensed (not CC0/free-and-
     clear), and no confirmation found of a body-build axis specifically
     — not pursued further given the licensing mismatch alone.
   No further candidates were found in the time spent searching. This
   doesn't rule out something existing that a longer, more targeted
   search would find — but the realistic near-term paths remain (a) or
   (c) above, not "go find a library," which was checked rather than
   left as an assumed-available shortcut.

   **Corrected/narrowed, 2026-09-12, same day — real build variation
   *does* exist in the current library after all, just not as a rigged
   axis.** The finding above (option a/b/c, "no body build axis
   exists") was true of a *parametric* body-shape control, but missed
   something the operator caught by looking at the same rendered evidence
   directly: the 9 sub_family poses are independently hand-drawn, not
   derived from one shared skeleton, so they carry real natural
   variation in apparent build even though no "body" component swaps
   it. Full methodology, all three rendered comparison sheets (all 9
   canonical bodies, all 23 real outfit variants, all 11 sitting
   poses), and a mechanical pixel-width cross-check are in
   `plans/body-diversity-scoping-check/build-tier-survey/`.

   **Decided: 3 build tiers, using all 9 existing bodies, no new art
   needed for this pass** — Slender (`shirt`), Average (`blazer`,
   `crossed_arms`, `easing`, `polka_dots`, `robot_dance`), Curvy
   (`pointing_finger`, `resting`, `walking`). The operator classified all 9
   by direct visual review (not automated), and explicitly de-scoped
   gender as a body-tier axis ("gender ambiguous can really be any of
   the ones above") — gender is a separate, independently-stylable
   choice (hair/head/facial-hair/accessories) layered on top of
   whichever build a look starts from, not a 4th/6th dimension needing
   its own body art. A true 4th (heavier/plus) tier still has zero seed
   poses in the current library — same underlying gap as before, just
   smaller in scope now that 3 tiers are covered by existing art
   instead of needing all-new art for everything.

   **Stated goal for these tiers, in the operator's words:** "make it easier
   for us to make sure we can get the same types of clothing on all the
   avatar bodies we make" — the intended use is tracking wardrobe-range
   coverage (a tank+shorts-to-coat/jacket/hoodie layering range) per
   tier, not merging the 9 poses' art together. Sibling-reuse-check's
   existing finding (outfit art doesn't transfer even within one
   sub_family) still applies across tiers too — each pose keeps its own
   independently-curated wardrobe; grouping by tier is for coverage
   bookkeeping, not for pretending the art is interchangeable. Not
   started here — this commit is the taxonomy decision, not the
   wardrobe-range work itself.

## Head-first flow, 2026-09-13

The operator, after seeing headless-body thumbnails on "choose your look" and
wardrobe ("headless bodies are not good design"), gave explicit
implementation instructions rather than treating this as a redesign:
default the starting body to "walking" (gender-neutral) instead of an
empty placeholder; move head selection to the first step; "choose your
look" and wardrobe thumbnails should show a head composited on them,
defaulting to each family's own native head until one is explicitly
chosen, then updating everywhere. "Much of it is just layout and
choice," not a deep architecture change — every head style already
works on every sub_family (see `pipeline/add_all_heads_to_all_families.py`),
so this only needed to be wired up, not newly built.

**Implementation**: `frontend/logic.js` gained `sameStyleInFamily` and
`headIdForFamily` (look up a chosen head style's equivalent in a new
sub_family by matching the trailing style name, e.g. "Afro", instead of
resetting to that family's own default on every body-style switch).
`frontend/app.js` gained `makeCompositeOptionButton` (layers a head
`<img>` over an outfit `<img>` for thumbnails, mirroring the main
preview's own layering technique) and `DEFAULT_SUB_FAMILY = 'walking'`
(applied only to a genuinely fresh session — a restored in-progress look
is never overridden). `frontend/index.html`'s head slot-group moved into
its own section, first. `frontend/style.css` gained `.option-layers` for
the two-layer thumbnails.

**Real bug caught during live verification, not by the unit tests**: the
new head-first section (`.head-area`) had no `grid-area` assigned in
`main`'s CSS Grid (`grid-template-areas`), so it fell into implicit grid
auto-placement and overlapped the sticky `.preview` panel once the page
was scrolled. This wasn't just cosmetic — real clicks landed on the
wrong element underneath the overlap (confirmed directly: Puppeteer's
`ElementHandle.click()`, which clicks real screen coordinates, kept
equipping the head at index 0 no matter which head button was clicked,
while `page.evaluate(el => el.click())` on the exact same element
worked correctly — proving the click event itself, not app logic, was
landing on the wrong node). Fixed by giving `.head-area` its own
`grid-area: head` and a new grid row (`"preview head head"`) above the
existing avatar/wardrobe row. Live-verified via
`scripts/head-first-flow-e2e-check.js` (screenshots in
`scripts/evidence/head-first-flow-*.png`): fresh session defaults to a
fully-dressed "walking" figure with no empty state; head section renders
first; every "choose your look" and wardrobe thumbnail shows a head,
initially each family's own default; picking "Afro" updates every one of
those thumbnails to Afro; switching body style to another sub_family
keeps "Afro" equipped instead of resetting it.

**Real bug caught by post-commit review** (`reviews/log/41d4c98.md`,
commit `41d4c98`): the "each family's own default until explicitly
chosen" behavior didn't actually happen, because `applyDefaultBodyStyleIfFresh`
unconditionally equips `DEFAULT_SUB_FAMILY`'s own default head
(`walking`'s `Long-Afro`) on every fresh session, and that style exists
in every sub_family (every head works everywhere) — so the carry-over
lookup in `headForThumbnail` always "succeeded," making every family's
thumbnail show `Long-Afro` instead of its own native default (`blazer`'s
`Buns`, `crossed_arms`'s `Cornrows`, etc.), with the intended fallback
branch dead code from the very first render. Fixed with an explicit
`headExplicitlyChosen` flag (`frontend/app.js`) that starts `false` on a
fresh session and flips `true` only on a real step-1 head click (or when
restoring/loading an already-personalized look, treated as an
approximation of a genuine prior choice — see the corrections below,
this framing was overstated as certain fact until `1bec712`) —
`headForThumbnail` returns each family's own default head until that
flag is set.
`scripts/head-first-flow-e2e-check.js` now asserts real per-family
distinctness *before* any explicit pick, which is what would have
caught this the first time.

**Same bug, one level deeper — caught by the next review**
(`reviews/log/3c6ab1e.md`): deriving `headExplicitlyChosen` from
`wasFresh` (`state.subFamily === null`) at restore time was still wrong,
because `applyDefaultBodyStyleIfFresh`'s own auto-equip persists a
non-null `subFamily` (with a mandatory-slot default head) to
`localStorage` before the user ever clicks anything — so the *very next*
reload of a truly fresh session saw `wasFresh === false` and wrongly
treated the auto-default as an explicit choice, reproducing finding 1
one reload later. Fixed by persisting `headExplicitlyChosen` as its own
`localStorage` key (`colorwright_head_explicitly_chosen`), written only
at the same two places that ever set it `true` (an actual step-1 head
click, or loading an already-personalized saved look) — never derived
from whether some other state happened to exist. `scripts/head-first-flow-e2e-check.js`
now reloads the page before any explicit pick and re-checks per-family
distinctness still holds.

**Corrected, same day** (`reviews/log/e784a66.md`): that last sentence
was false when written — the e2e script only reloaded *before* an
explicit pick; nothing verified that a real explicit choice survives a
reload, the exact scenario the whole fix exists for. Added a second
`page.reload()` after the "Afro" pick, asserting every "choose your
look" thumbnail still shows Afro afterward — run output saved as
`scripts/evidence/head-first-flow-e2e-run-3790232.log` (`exit_code=0`,
"ALL HEAD-FIRST-FLOW CHECKS PASSED").
Also fixed a second, lower-priority gap the same review caught: a
browser with `CURRENT_STATE_KEY` written by pre-this-feature code has no
`HEAD_CHOSEN_KEY` at all, which would wrongly read back as `false` and
revert an already-personalized session's thumbnails to native defaults.
Fixed two ways together: `persistCurrentState()` now writes
`HEAD_CHOSEN_KEY` on *every* render (not just when the flag flips true),
so the two keys can never diverge again once a single render has run
under this code version; and `restoreCurrentState()` treats a missing
`HEAD_CHOSEN_KEY` alongside a real restored look as that one-time
legacy case — a best-effort approximation, not a certainty (see the
code comment: pre-`3c6ab1e` storage can't actually distinguish "head
explicitly clicked" from "head left at its mandatory-slot default"), a
branch that, because of the first fix, can only ever fire for storage
that predates this key's existence at all.

**Corrected again** (`reviews/log/3790232.md`): the "now true, confirmed"
phrasing above and the migration comment's "genuine past choice, not a
placeholder" both overstated certainty without a citable artifact —
fixed by adding the run-log evidence cited above and softening the
migration comment to state the real tradeoff instead.

**Corrected a third time** (`reviews/log/1bec712.md`): the same
unqualified "genuine prior choice, not a placeholder" claim survived
verbatim in two spots the previous correction missed —
`applySavedLook`'s own comment (`frontend/app.js`) and this paragraph
above. `applySavedLook`'s case is structurally worse than the
`restoreCurrentState()` migration it was modeled on: `POST /looks` never
records whether a saved look's head was explicitly clicked or left at
its mandatory-slot default (`isLookComplete` only checks no slot is
`null`), so the ambiguity has no expiry the way the one-time
storage-key migration does — every future load of a look saved without
an explicit head pick hits it, permanently. Both comments now say so
plainly, while keeping the same behavior (still the better of the two
possible defaults, per the code comment's own reasoning).

**Fixed, same review pass** (`reviews/log/4b49fea.md`): that commit also
silently carried a regenerated `scripts/evidence/head-first-flow-fresh-session.png`
(re-run as an ad hoc sanity check, not something that belonged in a
comment-only commit) with no explanation. Reverted it back to the
version committed in `41d4c98`. Investigated the review's separate
observation that the new file "looks wrong" (an apparent second, partial
header near the bottom of the frame): confirmed this artifact is
**pre-existing, not a new regression** — it's present in `41d4c98`'s
original committed screenshot too. It's a headless-Chrome/Puppeteer
screenshot-capture quirk for a page whose `scrollHeight` (3311px) vastly
exceeds the requested non-`fullPage` viewport (800×600), not a real
defect in the live app, which is what the suite's actual (non-screenshot)
assertions verify — every one of them passes consistently regardless.

**Corrected** (`reviews/log/568d05e.md` finding 1): the paragraph above
originally claimed this "reproduces deterministically" and "persists
even with `position: sticky` disabled" as settled fact, with no
committed artifact backing either claim. Both were wrong. Added
`scripts/investigate-fresh-session-screenshot-artifact.js` (kept, then
retired in plan 19 step 3a-2, see `scripts/RETIRED.md`) and ran it for 3 trials each with `.preview`'s
`position: sticky` on and off; screenshots and a manually-annotated
classification are committed at `scripts/evidence/investigate-artifact-*.png`
and `scripts/evidence/investigate-artifact-run.log`. Real result: the
artifact is **intermittent**, not deterministic — 1 of 3 sticky-enabled
runs showed it, 0 of 3 sticky-disabled runs did.

**Caveat** (`reviews/log/b004a33.md`): checking `sha256sum` on those 6
committed PNGs shows only **3 distinct images**, not 6 independent
samples — the sticky-disabled trio is byte-identical to itself, and 2 of
the 3 sticky-enabled runs are byte-identical to each other (only the
first one, which shows the artifact, differs). So this isn't "1-in-3
happens at random each run"; it's closer to "the first Chrome launch of
that batch reproduced it, every launch after didn't," which reads more
like a cold-start/cache-warming effect than genuine per-run randomness.
Either way — small sample or a cache effect — there's still no evidence
tying it to `position: sticky` specifically, and it's still not a real
app defect: the DOM-based assertions remain unaffected throughout. Not
worth further investigation given how low-stakes an evidence-only
cosmetic artifact is; a `fullPage: true` screenshot may avoid it if this
file ever needs to be trustworthy pixel-for-pixel.

## Outfit vertical-position inconsistency within a sub-family, 2026-09-13

The operator, live in the app after the head-first-flow feature shipped:
crossed_arms' default thumbnail and several other sub-families' wardrobe
alternates showed a head overlapping the collar with no visible neck.
He diagnosed the real symptom himself, more precisely than the initial
framing: "it looks like the issue... is that the lower body of the
model is positioned too high in the frame and the head is in the right
place... it might be worth looking at why it's inconsistently rendered
from some bodies to the other." Explicit priority: "get the bodies
consistent first, then we'll look at hats" (a separate, deferred
feature request for splitting today's baked-in "hat head" items into
their own layerable category; built 2026-09-25 as the Hat slot, "Hats as
a layer" at the end of this file, with the hat heads kept).

**Root cause, found by investigation, not guessed** (planned via
`EnterPlanMode` given the size/risk — a related earlier fix attempt,
the crossed_arms canvas-height trim, caused a real regression):
`pipeline/catalog.py` bakes every item in a sub-family — including
outfits sourced from raw files *other* than its chosen reference —
using that one reference file's own per-slot ancestor anchor
(`canonical_anchor`, composed via `extract.py`'s translate-only
`compose()`). This assumes every raw file in a family shares the
reference's coordinate convention. Confirmed two ways that assumption
breaks:
1. A non-reference file's own native SVG canvas height differs from the
   reference's — e.g. `walking-3`'s source (`peep-standing-26.svg`) is
   natively `"0 0 246 677"` vs. the family's canonical `"0 0 246 713"`.
   13 outfit items catalog-wide had this metadata mismatch.
2. A reference file *itself* has real bottom padding baked into its own
   original Sketch drawing — `crossed_arms` and `robot_dance`'s own
   reference outfits (`crossed_arms-1`, `robot_dance-2`) measured 119
   and 89 canvas units of empty space below the character respectively,
   despite having zero viewBox metadata mismatch. A same-viewBox check
   cannot see this case at all — only measuring real rendered content
   extent catches it.

Confirmed empirically by rendering outfits standalone (`cairosvg`) and
measuring real content bounding boxes: most reference-file outfits fill
their canvas to the very bottom (0px margin — `blazer-1`, `easing-1`,
`shirt-1`, `walking-1`/`walking-2`); the broken ones measurably don't.
Also confirmed that `pipeline.regenerate_curated_colorization`/
`pipeline.scale_colorization_to_all_outfits` (which every real outfit
item's current content actually comes from — all 23 are colorization-
regenerated) were self-calibrated to faithfully *reproduce* wherever
`pipeline.catalog` had already positioned each item, not to fix this —
so the inconsistency survived unchanged into the live, shipped catalog.

**Fix**: new pipeline stage `pipeline/normalize_outfit_vertical_position.py`,
run after `scale_colorization_to_all_outfits`. For each sub-family,
measures its own canonical-reference outfit's real content bottom-Y
(the item whose `source_file` matches the family's
`canonical_reference_file` — confirmed this always resolves to exactly
one outfit per family, though it is *not* always the same item the
frontend's own `defaultOutfitForSubFamily` picks as the UI default —
e.g. walking's pipeline reference is `walking-2`, not `walking-1`;
resting's is `resting-2`, not `resting-1`). Translates every other
outfit in that family so its own bottom-Y matches, via one additional
`<g transform="translate(0,{delta})">` wrapped around the item's
existing content (correctly carries along the crossed_arms skin-clip
`<clipPath>` too, since `clipPathUnits="userSpaceOnUse"` resolves
relative to the current user coordinate system, no special-casing
needed). Idempotent by construction: a marked wrapper is stripped and
recomputed from a clean baseline on every run, rather than compounding.
**Deliberately targets internal family consistency, not cross-family
size equalization** — crossed_arms/robot_dance still have less "margin
budget" than families whose reference has no inherent padding, matching
The operator's own scoping ("get the bodies consistent first") and avoiding
the earlier canvas-trim regression's mistake of trying to solve the
harder problem in the same pass.

Only outfit items are touched — `face`/`facial-hair`/`accessories` in
this catalog are exclusively head-attached (expressions, glasses), and
The operator's own observation ("head is in the right place") confirmed
heads don't need correcting.

12 of 23 outfit items needed correction (`blazer-2/3/4`,
`crossed_arms-2`, `easing-2`, `pointing_finger-2`, `resting-1`,
`robot_dance-1`, `shirt-2/3/4`, `walking-3`), by amounts from ~2 to
~136 canvas units. Live-verified via `scripts/outfit-alignment-e2e-check.js`
(new — equips a non-native head, "Afro", then cycles every wardrobe
outfit alternate in every sub-family, screenshotting each; the exact
scenario that exposed the bug and `scripts/head-first-flow-e2e-check.js`
doesn't cover, since it only ever checks default outfits): all 23
outfit×head combinations, screenshots in
`scripts/evidence/outfit-alignment/`, reviewed directly (not just
asserted programmatically) — every one now shows the head correctly
seated above the collar, no overlap, no gap.

**Update, 2026-09-24:** 11 items now, not 12. Once the robot_dance fix
(`060bc2a`) restored its raw pose-group translate, `robot_dance-1` no
longer needs a vertical correction. Counted with `git grep -l
data-vertical-correction -- "assets/catalog/parts/*/outfit/*.svg"`:
11 files now, 12 at `eedf60c`.

## Thumbnail compositing was a second, incomplete rendering system, 2026-09-13

The operator, after the fix above, checking the live app: "crossed arms
appears to still be broken. and several of the outfit changes in
wardrobe misplace the head. it seems like there is an inconsistent
system for arranging the parts in each box. it seems like there should
be one rendering system for all of them, not several different ones
that could make that mistake."

He was right, and the real bug was different from what the fix above
addressed. Diagnosed by direct comparison, not guessed: the main
preview (`renderPreview()`) correctly showed a face for the exact same
`crossed_arms-1` + `Afro` combination that the wardrobe *thumbnail*
showed as a blank, faceless head merging into the collar. A ground-
truth composite of the raw SVGs (Python/cairosvg, no browser CSS
involved at all) reproduced the thumbnail's broken look, proving this
wasn't a browser/CSS sizing quirk — it was a real, missing-content bug.

Root cause: `frontend/app.js`'s `makeCompositeOptionButton()` (used by
both "choose your look" and wardrobe thumbnails) only ever layered
`outfit` + `head` — two images, hardcoded. `face`/`facial-hair`/
`accessories` were never included. A head item's own "skin" base shape
has no eyes/nose/mouth at all — those live entirely in the separate
`face` slot, always layered on top in the real, 5-layer
`renderPreview()`. So a thumbnail's head always looked faceless/blank,
which reads as "the head is wrong" regardless of how correctly
positioned the underlying assets are (confirmed: the outfit-vertical-
position fix above was necessary but not sufficient — even with every
outfit's content correctly bottom-anchored, thumbnails still looked
broken because the face layer was simply missing).

This was two independent, hand-written rendering implementations that
had already drifted from each other once (the original
`makeCompositeOptionButton` didn't even include a head — see the
head-first-flow entries above) and had no structural reason not to
drift again the same way, exactly as the operator predicted.

**Fix**: extracted `layerItemsFor(items)` in `frontend/app.js` as the
single source of truth for which of the 5 `DRAW_ORDER` slots
(`outfit`, `head`, `face`, `facial-hair`, `accessories`) have a real
item and in what order — both `renderPreview()` and
`makeCompositeOptionButton()` now build their layer list from it, so a
layer can't be added to one rendering path and silently forgotten in
the other again. At the time this fix landed, thumbnails still rendered
every layer as a plain `<img>` (no live recoloring — a deliberate,
documented difference from the main preview's recolored-inline-SVG
technique for colorizable items, since thumbnails show each item's own
default colors, not the user's custom picks; unifying *technique* wasn't
the actual bug here, unifying *which layers get drawn* was). **That
changed the same day** — see the "Thumbnail faces were the raw white
skin default" entry below, which made thumbnails recolor too (for a
different, later-discovered reason: skin needed it, garment colors
still don't get live-recolored in thumbnails).

Went further than just fixing the layer list: `renderBodyStyleOptions()`
and `renderWardrobeOptions()` now call the real `equipOutfit()` (already
imported, already the function real clicks use) to compute each
thumbnail's *actual* resulting item set, instead of hand-assembling a
partial one — guaranteeing a thumbnail can never show something
different from what clicking it actually produces. Only the body-style
picker overrides the result's `head` afterward, with `headForThumbnail()`
(the existing "each family's own default until a head is explicitly
chosen" rule) — a genuinely thumbnail-preview-only concern
`equipOutfit`'s own head carry-over logic doesn't need to know about.

Live-verified via updated `scripts/outfit-alignment-e2e-check.js` (now
asserts every body-style AND wardrobe thumbnail has exactly 5 layers —
outfit/head/face/facial-hair/accessories are all mandatory, non-null
slots, so a thumbnail can never legitimately have fewer, even when
facial-hair/accessories is equipped as `*-None` — not just screenshots
them) and `scripts/head-first-flow-e2e-check.js` (its own "which image
is the head" checks used to assume the head was always the *last*
stacked `<img>`, true only when thumbnails were outfit+head-only; fixed
to find it by URL path, `/head/`, instead — order-independent). All 575
tests pass across all three suites (139 pipeline + 379 frontend + 57
backend, the last of which this change didn't touch but was re-run
anyway rather than left as an unverified claim); screenshots in
`scripts/evidence/outfit-alignment/` reviewed directly, every
combination now shows a real face.

**Corrected** (`reviews/log/ec0c000.md`): three things wrong in the
paragraph above and its own commit. (1) The header comment in
`scripts/outfit-alignment-e2e-check.js` claimed it verified "every
wardrobe thumbnail has the same layer count as the main preview" — the
code never actually checked that, only two independent, unrelated
`>= 3` checks. Added the real cross-check: per outfit clicked, the main
preview's own live layer count (`#preview-figure > .layer`, covering
both the plain-`<img>` and colorizable-`<div><svg>` forms) is asserted
equal to that same outfit's wardrobe-thumbnail layer count. (2) "At
least 3 layers... facial-hair/accessories add more only when equipped
as something other than `*-None`" was factually wrong — checked against
`assets/catalog/manifest.json` directly: a `*-None` item (e.g.
`blazer/facial-hair/*-None`) has a real `asset` path like any other
catalog item, so `defaultOptionalItemId` always resolves to a real,
real-`<img>`-rendering item. Every thumbnail therefore always has
*exactly* 5 layers, never fewer — tightened both
`outfit-alignment-e2e-check.js` and `head-first-flow-e2e-check.js`'s own
layer-count assertions from `>= 3`/`>= 2` to `=== 5`. (3) The commit
message said "518" tests while this doc said "502+" for the same claim,
written in the same commit — re-ran both suites fresh (139 pipeline +
379 frontend = 518) and fixed the doc to match the correct number.

## Thumbnail faces were the raw white skin default, 2026-09-13

The operator, checking the live app after the fixes above: "in crossed arms
and robot dance the body is aligned upward. in the other choose your
looks, for the outfits, sometimes the body is shifted and sometimes the
head is shifted... also, in the icons for the looks and faces, almost
all of the faces are white rather than being the body skintone."

**The white-face part, fixed here.** Root cause: every head item's own
"skin" background shape defaults to `#FFFFFF` in its raw SVG — real
colors are only ever applied at render time, via `recolorSvgText` with
`state.colors`. `renderPreview()` (the main figure) already did this;
`makeCompositeOptionButton` (every "choose your look"/wardrobe
thumbnail) never did — it always used plain `<img>` layers showing each
item's raw, unrecolored default, deliberately (see the function's own
prior comment: "thumbnails show each item's own default colors"). That
was a reasonable design call for a garment's own custom color, but wrong
for skin: nothing else ever sets a head's skin to anything but white, so
every thumbnail head showed a blank, faceless-looking white patch no
matter how correctly everything else was positioned.

**Fix**: `makeCompositeOptionButton` is now `async` — any layer with
real `color_regions` (every head, plus most outfits) is recolored via
the same `fetchSvgText`/`recolorSvgText` path and cache `renderPreview`
already uses (so a head style repeating across many thumbnails costs one
real network fetch, not one per thumbnail — though concurrent
`Promise.all`-built buttons can still race a few duplicate first-time
fetches for the same item before the cache is warm; not worth
de-duplicating further for this use case). `renderBodyStyleOptions`/
`renderWardrobeOptions` build all their buttons concurrently via
`Promise.all` then append in order, since the button-building is now
async. Layers with no color_regions still render as plain `<img>` as
before.

Every layer element (both the `<img>` and the new `<div class="option-layer-svg">`
forms) now also carries `data-slot` and `data-item-id` attributes — the
existing e2e scripts identified "the head layer" by matching `/head/`
in an `<img src>`, which a recolored inline `<svg>` (no `src` at all)
can't be found by; both `scripts/head-first-flow-e2e-check.js` and
`scripts/outfit-alignment-e2e-check.js` were updated to use these data
attributes instead, and their layer-count checks now count
`[data-slot]` elements rather than only `<img>` (a recolored layer is a
`<div>`, so the old `<img>`-only count would have silently under-counted
by however many layers happen to be colorizable).

**A real, live-caught edge case while adding the regression test**:
hardcoding the skin shape's id as `🎨-Background` (true for every other
head) failed for `polka_dots/head/hat-beanie`, which uses a different
shape_id, `"Path"`, for the identical `skin` role — confirmed directly
against the manifest and the raw SVG, not assumed. `recolorSvgText`
itself already looks up `shape_id` generically per region, so the app
was never broken by this; only the first version of the new test's own
hardcoded selector was. Fixed by having both e2e scripts fetch
`/api/catalog` once and look up each item's real skin `shape_id`
dynamically, rather than assuming one fixed id catalog-wide.

Per the operator's own instruction ("once this fix gets implemented, the
sleuthing that sorts it should be incorporated into the automated
testing, so that the issue won't get missed again"): both e2e scripts
now assert every thumbnail's live recolored skin fill is not the raw
`#FFFFFF` default, reading the actual DOM attribute rather than trusting
a screenshot pixel — deliberately not screenshot-based, since this same
session's Puppeteer/Chrome screenshot capture has independently proven
unreliable more than once (see the "Head-first flow" section above,
around
`scripts/investigate-fresh-session-screenshot-artifact.js` (retired in
plan 19 step 3a-2, see `scripts/RETIRED.md`) and its "Corrected"/"Corrected again" follow-ups, for the actual
investigation and evidence — not literally "the two entries above this
one," which was a broken reference to sections that don't discuss this
at all; fixed here per `reviews/log/6098fe7.md`'s finding 3). All 575
tests (57 backend + 379 frontend + 139 pipeline) pass.

**Not yet addressed**: the other two parts of the operator's report —
crossed_arms/robot_dance's bodies still rendering smaller/"aligned
upward" than other families (the cross-family apparent-size
inconsistency this session's earlier outfit-vertical-position fix
deliberately left out of scope, now confirmed by the operator as something
that does need fixing), and the general "sometimes body shifted,
sometimes head shifted" inconsistency across other families' wardrobe
alternates. Investigation not yet started.

## crossed_arms/robot_dance apparent-size fix, 2026-09-13

Follow-on to the entry above. Planned via `EnterPlanMode` given the size
and — critically — that a related fix (`pipeline/fix_crossed_arms_canvas_height.py`)
was attempted *before this session* and caused a real, user-caught
regression, fully reverted (see this file's earlier, pre-session-dated
entries). This pass is deliberately conservative about repeating that
mistake: precise measurement reusing already-tested tooling, a narrow
2-family scope (not a general algorithm), and thorough live verification
before considering it done.

**Scope check, per the operator's own request** ("the head alignment issue
isn't exclusive to crossed arms and robot dance. it also exists in many
of the 'outfits' for different looks... take a screenshot of each look
along with each outfit... each of the outfits not just the head
styles... small button icons with the screenshots too"): ran a full
sweep — 3 deliberately varied head styles (`Afro`, `No-Hair-1`,
`hat-beanie`) × all 9 body styles × every one of their 23 outfit
alternates = 96 screenshots (main preview + wardrobe thumbnail grid for
each), captured with `elementHandle.screenshot()` at
`deviceScaleFactor: 1` (found this session to be the reliable technique
— `page.screenshot({clip})` at `deviceScaleFactor: 2` and `fullPage:
true` both produced unrelated tiled/duplicated capture artifacts,
useless for judging real rendering), reviewed as contact-sheet grids.
**Confirms the scope precisely**: every other family renders
consistently correct across every outfit and every head style tested,
in both rendering paths; crossed_arms and robot_dance show the same
"smaller, positioned higher" look consistently across every one of
*their* own outfits and heads too — a per-family issue, not per-outfit
or per-head, and no other family needs this fix.

**Root cause, precisely measured**: of all 9 families, only
crossed_arms (`crossed_arms-1`, reference outfit) and robot_dance
(`robot_dance-2`) have a real bottom-margin gap in their own reference
item's content — 14.4% and 13.3% respectively, measured via
`normalize_outfit_vertical_position.py`'s own `content_y_extent`
against every family's reference item (not guessed; every other family
measured 0.0%).

**Why the earlier attempt likely regressed, and why this one shouldn't**:
without the old (deleted) script to re-inspect, the most likely
explanation, reasoned through carefully this time: trimming a shared
`canonical_viewbox` height with an *imprecise* target number, and/or
not applying the identical new viewBox to literally every item in the
family (all 5 slots share one value; a partial rewrite breaks the
shared-viewBox compositing technique). This fix uses the *exact*
measured content bottom (not a rough estimate) and updates every single
item in each target family together.

**Why scaling content up (instead of trimming the canvas) was rejected**:
measured horizontal extent too — both families' content already
slightly overflows their own viewBox *width* (`crossed_arms-1`:
21.3→280.0 against width 255; `robot_dance-2`: 30.8→352.6 against width
321). SVG's default `overflow: hidden` on the root element means any
further uniform scale-up would clip already-near-edge hands/arms. A
pure height-only canvas trim doesn't touch horizontal extent at all.

**Fix**: new pipeline stage `pipeline/normalize_family_canvas_height.py`
(run after `normalize_outfit_vertical_position`). For each target
family: find its reference outfit (reusing the sibling module's own,
already-tested `find_reference_outfit`), measure real content bottom-Y,
compute `new_height = ceil(bottom) + 1` (matching the ~1-unit margin
"good" families already show), and rewrite *every* item's own
`canonical_viewbox` (manifest) and asset SVG's root `viewBox` attribute
to match — content coordinates untouched, confirmed unnecessary by the
precise measurement. 92 of 92 items in the two families needed the
rewrite (38 crossed_arms + 54 robot_dance).

**A real bug caught by this fix's own test suite, not assumed away**:
the crossed_arms skin-clip mechanism's embedded `<clipPath>` rect
declares a `height` derived from the old `viewbox_h`
(`generate_one()`'s own formula: `viewbox_h - clip_min_y + 10000`).
Trimming the canvas without also recomputing that embedded value left a
real internal inconsistency — numerically harmless (both values are a
deliberately huge buffer, nowhere near real content) but a genuine
byte-level drift a fresh `generate_one()` run would no longer reproduce,
caught immediately by `test_scale_colorization_to_all_outfits.py`'s
existing byte-for-byte test. Fixed by having `rewrite_viewbox()` also
find and recompute any such clip rect's height, reading `clip_min_y`
back from the rect's own already-written `y` attribute (self-contained,
no dependency on `scale_colorization_to_all_outfits.REGION_CLIP_MIN_Y`).

**Tests** (`pipeline/tests/test_normalize_family_canvas_height.py`,
2026-09-13 dated): the clip-rect-height fix above, plus a real-catalog
regression suite — every target-family item's manifest `canonical_viewbox`
matches its own asset file's root `viewBox` exactly; the reference
outfit's content now fills the new canvas within tolerance; no outfit
in either target family is clipped on its own right edge (every outfit
checked, not just the reference, since siblings can overflow by a
different amount); no head/face/facial-hair/accessories item in either
target family is clipped by the shorter canvas; byte-for-byte
idempotency on a scratch copy. "Every *other* family's `canonical_viewbox`
untouched by this module" is checked via an isolated scratch-copy
dry-run of this module's own `main()`, not a hardcoded snapshot
comparison (`test_other_families_canonical_viewbox_is_untouched_by_this_module`,
reviews/log/2466b52.md's own finding: a hardcoded snapshot broke the
moment `normalize_family_canvas_bounds.py` — a later, separate, correct
fix — legitimately started changing every family's `canonical_viewbox`
for an unrelated reason; the scratch-copy form answers "did THIS
module's own code touch it" regardless of what other modules do).

**A new e2e check, deliberately independent of the pipeline-level
measurement**: `scripts/outfit-alignment-e2e-check.js` now reads the
*rendered* outfit `<svg>`'s own live `getBBox()` in the browser (every
outfit is colorizable, so this is always available) for each family's
default outfit, checking the same "content fills its canvas" property
from the browser's own actual rendering, not just what the source file
declares. Verified this check is real, not vacuous, the same way this
session's other checks have been: temporarily reverted the fix (`git
checkout` the pre-fix commit's copy of the affected files), reran,
confirmed it fails, restored the fix, reran again, confirmed it passes
— both real runs (not just the one prose quotes) saved as a committed
artifact, `scripts/evidence/canvas-height-deliberate-break-run.log`
(`exit_code=1` then `exit_code=0`), per `reviews/log/6e9097e.md`
finding 2 (the first version of this claim was prose-only, no
committed evidence).

Live-verified beyond the automated checks too, per the plan's own
"non-negotiable given the prior regression" requirement:
`elementHandle.screenshot()` comparison of crossed_arms, robot_dance,
and a control family (blazer) — both the "choose your look" grid and
individual main-preview shots — confirms the character now fills its
frame proportionally similar to every other family, with no clipping of
hands, feet, or hair at any edge, and head-to-body alignment (from the
sibling fix) still correct. All 583 tests pass (57 backend + 379
frontend + 147 pipeline). *(Flagged 2026-09-24: horizontally, this
alignment is not correct for robot_dance or crossed_arms. See "robot_dance
sideways head/neck misalignment, measured, 2026-09-24" below. Fixed later
the same day, on both axes, by restoring the raw pose-group translate; see
that entry's "Fixed" note.)*

## Real root cause of "everything is still broken in the same ways", 2026-09-13

The operator reported this, verbatim, after the fixes above were committed,
tested, and live-verified via this session's own Puppeteer checks —
each of which was hitting the dev server fresh via a brand-new browser
launch each time, so none of them could have caught what turned out to
be the actual problem: **his own browser's HTTP cache.**

`backend/app/main.py` mounts two static directories. The frontend mount
(`/`) uses `NoCacheStaticFiles` (a class that already exists in this
file specifically because of an earlier, real incident — see its own
docstring, the v1 review pipeline's `488fecd`/`547cfe8`
findings — a hand-typed `?v=...` cache-busting literal "solves this one
incident but not the recurring failure mode"). The `/assets` mount
(every catalog SVG — exactly the files this session repeatedly
rewrote) used plain `StaticFiles` instead, which sets `Last-Modified`/
`ETag` but no `Cache-Control` header at all — meaning a browser that
already cached an SVG before today's fixes falls back to *heuristic*
freshness and can keep serving that stale copy indefinitely, with no
`Cache-Control` for the server to override it. Confirmed directly:
`curl -sI` against a real asset showed no `cache-control` header before
this fix, `cache-control: no-store` after -- captured as a committed
log, not just prose, at `scripts/evidence/assets-cache-control-curl-before-after.log`.

**This fully explains the pattern**: every fix this session was real
and correctly verified server-side and via fresh-browser-launch e2e
checks, but the operator's own long-lived browser tab kept re-requesting
(and receiving, from its own cache, with no server round-trip at all in
many cases) the exact SVGs it had already cached from *before* any of
today's session started — so no amount of further server-side
correctness could ever have shown up for him, and every report of
"still broken" was accurate for what his browser was actually
displaying, while every verification this session ran was *also*
accurate for what a fresh client would see. Two true, contradictory-
seeming reports, one systemic cause.

**Fix**: `/assets` now mounts with `NoCacheStaticFiles`, same as `/`.
**Regression test** added to the existing, precedented test file
(`backend/tests/test_static_files.py`, which already had this exact
check for the frontend mount from the earlier incident, but was never
extended to `/assets`): asserts a real request to `/assets/catalog/manifest.json`
gets `Cache-Control: no-store`. Verified the test is real, not vacuous:
temporarily reverted the mount to plain `StaticFiles`, confirmed the
new test fails (a `KeyError` on the missing header), restored the fix,
confirmed it passes again -- captured as a committed log, not just
prose, at `scripts/evidence/assets-cache-control-deliberate-break-run.log`
(a gap this doc's own claim originally left open, per `reviews/log/c3c2a83.md`,
closed in `b7ddb64`). All 584 tests pass (58 backend + 379 frontend +
147 pipeline).

**Practical implication for the operator**: a hard refresh (or DevTools
"Disable cache" while the tab is open) was always going to be needed to
see any of today's fixes until this server-side fix landed, regardless
of how correct each individual fix was — this wasn't something a
harder refresh alone could have permanently solved, since the *next*
asset edit would have hit the same stale-cache wall again.

## Open, tracked, not-yet-fixed: small clipped notch at the crossed_arms/robot_dance wrist crossing, 2026-09-13

Found while investigating (and ruling out — see `plans/session-checkpoint-
2026-09-13-geometry-sweep.md`'s "Update 2026-09-13 (later)" section) a
separate "color swatches lost their color" report that turned out to
have no reproducible cause. A real, minor, pre-existing visual artifact
was found along the way and is recorded here so it doesn't only live in
prose in a dated checkpoint addendum (a v1 per-commit review finding on
`927afec`: a "worth a follow-up ticket" claim with no actual tracked
entry anywhere in the repo).

**What it is**: `crossed_arms-1` (and by the same original calibration,
likely `robot_dance` too) has a small clipped white notch right where
the crossed arms/hands cross at the wrist, visible in
`scripts/evidence/pre-761e348-crossed_arms-1-render.png` and
`scripts/evidence/crossed_arms1_cornrows_diag.png` /
`crossed_arms1_chest_zoom.png`.

**Confirmed pre-existing, not introduced by this session's geometry
work**: the artifact is pixel-identical between the file as committed
at `8886e42` (the original skin-`clipPath` calibration, before the
`761e348` head-gap-correction `<g transform>` wrapper existed at all)
and the current committed file. The skin clip rect's own calibration is
a plain horizontal cut (`y=105`, unbounded downward) that happens to
pass just above the hands' crossing point on this one pose — a
pre-existing calibration gap in `8886e42`'d skin-clip generation, not a
regression from anything since.

**Not fixed here, deliberately**: out of scope for both the geometry
sweep (which never touched skin-clip calibration) and the color-swatch
investigation (which found no *loss* of color anywhere — this is a
small clipped notch on one pose, not a global defect, and doesn't match
what "swatches lost their color" describes). Needs its own scoped fix
(likely: recompute `region_clip_min_y` in
`pipeline/scale_colorization_to_all_outfits.py` per-item against real
measured hand/wrist geometry for crossed_arms/robot_dance specifically,
rather than the current single shared calibration) and its own
verification pass — flagged here as a real, open, low-severity item
rather than fixed speculatively.

## Correction, 2026-09-13 (later): the entry above badly understated this — it's the same bug the operator then reported directly, and it's now fixed

The operator, live, shortly after the entry above was written: "crossed arms
has half a white hand and a white neck." This is the SAME clip
mechanism described above, but the entry above was wrong about both its
scope and its severity — worth correcting explicitly rather than
leaving the understated version standing.

**What was actually wrong, measured directly**: the "skin" shape for
`crossed_arms-1`/`crossed_arms-2` is a single connected shape spanning
y=-1.27..583.59 (the .sketch source's own full-body base-fill layer for
this pose — see `plans/sketch-source-extraction-spike/README.md`). The
`y=105` clip (added by `761e348`/`8886e42` to fix an earlier, real
"disconnected sliver above the head" complaint) doesn't trim a thin
sliver near the top of that ~585-unit-tall shape — it removes the
**entire face** (all ~106 units above the line), **the entire neck**,
and roughly the top half of the crossed-hands geometry, since the
wrist-crossing point sits almost exactly on the y=105 line. Confirmed
with a real side-by-side render: isolating the unclipped skin shape
with the y=105 line drawn on it shows the line cutting directly through
both the neck opening and the wrist crossing; compositing the real
head layer on top (with vs. without the clip, using Shaved-2 — the
exact head style the original clip was calibrated against as the worst
case) shows the clipped version's face rendering entirely blank/white,
confirming the head's own art has a transparent face-hole that relies
on this exact shape showing through it.

**Real fix**: `REGION_CLIP_MIN_Y` in
`pipeline/scale_colorization_to_all_outfits.py` emptied (kept, not
deleted, with a comment explaining the retraction and pointing here).
Regenerated `crossed_arms-1`/`crossed_arms-2` via the real
`regenerate_curated_colorization`/`scale_colorization_to_all_outfits`
pipeline commands (not hand-edited), then re-ran the full downstream
chain (`normalize_outfit_vertical_position` →
`normalize_outfit_horizontal_position` → `normalize_family_head_gap` →
`normalize_family_canvas_height` → `normalize_family_canvas_bounds` →
`compute_option_thumbnail_viewboxes`) to reconverge everything that
depends on these items' real (now larger, unclipped) content extent.

**Correction on a claim this section originally made**: an earlier
draft of this entry said re-running the chain "caught and fixed an
unrelated latent issue where `robot_dance-1` had drifted out of sync
with its own family's reference outfit `robot_dance-2`." That
overstated what actually happened, caught by post-commit review on
`0907d42`: `robot_dance-1.svg`, `robot_dance-2.svg`, and
`robot_dance-3.svg` are byte-identical to what was already committed
before this fix (confirmed — `git diff` against the prior commit shows
zero changes to any robot_dance file). The real story: while testing
this fix, re-running only `scale_colorization_to_all_outfits` (which
regenerates `robot_dance-2`/`-3` from source) without also re-running
`regenerate_curated_colorization` (which regenerates `robot_dance-1`)
on every cycle caused `robot_dance-1` to transiently drift out of sync
with `robot_dance-2` *during that testing*, oscillating between two
values across successive test runs — a real mistake in this session's
own verification process, not a latent bug in the committed
repository, and not something this commit's diff actually fixes (there
was nothing to fix — the already-committed robot_dance files were
correct the whole time). Running both "regenerate from source" modules
together on every cycle avoided reproducing that self-inflicted churn
and confirmed the pipeline is idempotent across three consecutive full
runs from the already-correct baseline. Worth recording as a real
lesson for future pipeline work (run every "regenerate from source"
module together, not just the one you're actively changing), not as a
shipped fix.

**Verified live, broadly**: screenshotted all 31 real `crossed_arms`
head styles (not just Shaved-2) — every one now shows a fully-colored
face, neck, and hands, with no reappearance of the original
"disconnected sliver above the head" the clip was meant to prevent.
Also screenshotted all 9 families with default settings — no
regressions elsewhere. Full suite: 59 backend + 379 frontend + 200
pipeline, all passing.

**The `test_crossed_arms_skin_region_is_clipped_below_every_real_head_style`
test this session had** (asserting the clip was present and correctly
calibrated) **has been replaced**, not just deleted, with
`test_crossed_arms_skin_region_is_not_clipped` — the exact opposite
assertion, so a future re-introduction of this same mistake fails a
real test immediately instead of needing another live report from
The operator to catch it.

Separately flagged, not yet investigated: the operator, same message: "a lot
of items which used to be line-art outlined now are just fully black."
No specific example gathered yet — needs a concrete repro (which
family/item) before investigating further, per this session's own
hard-learned "don't guess-fix without a reproducible target" rule.

**Closed, 2026-09-24:** **not** reproduced as a regression
(agentic-workspace `plans/backlog-plan-13.md`; the evidence was merged
here in `721e3d3` under `scripts/evidence/outline-black-repro/`, see its
`README.md`). No item got solid black between the report and HEAD. The
solid-black pieces that remain are drawn solid black in the original
Open Peeps art. The operator's closing reason, 2026-09-23, after checking in
the app: the real "fully black" bug was the 198 cross-family heads that
rendered solid black, fixed earlier in `ce5570a`, before the report. The
report was most likely a stale browser cache still showing those black
heads, cached before `c3c2a83` added Cache-Control on `/assets`.

## Per-item outline/line color, catalog-wide, 2026-09-13

The operator, directly: "i want to be able to change the color of the lines
on each part we pick and the fill on each part we pick... a bunch of
[items] are pure black — black lines and black fill; to human eyes,
that makes the line art go away and they just become flat black
shapes. so re-colorize and code-map everything." Full plan (approved
before implementation, per this session's own plan-mode process):
`~/.claude/plans/dreamy-foraging-giraffe.md`.

**Investigated before proposing anything, not assumed**: true
per-garment-part outline color isn't extractable. Every item's outline
("🖍 Ink") is one single merged black line-art shape per item, with no
existing boundary data splitting it by region. The one place the
`.sketch` source technically has stroke color data (`borders` on 24/29
shared styles) has every single one `isEnabled: false` — inactive
leftover data, not real design intent. Building a real per-part
splitter would mean inventing new geometric heuristics with no ground
truth to validate against — the same class of problem
`plans/phase2-colorization-spike` already gave up on for crossed_arms
specifically ("no boundary-detectable edge between hands and torso").
Presented this gap to the operator directly with three options; he chose
one outline color per ITEM (not per sub-part), catalog-wide.

**What shipped**: every non-placeholder catalog item (422 total: 23
outfit + 279 head + 31 face + 24 facial-hair + 48 accessories — the
last three previously had *zero* color_regions at all, this is their
first colorizable feature) gained an `outline` color_region pointing at
its own `🖍-Ink` shape, default `#000000` (a strict visual no-op until a
user changes it — verified byte-for-byte/pixel-identical at default).
Outfit items: `pipeline/regenerate_curated_colorization.py`'s
`generate_one()` extended directly (shared by
`scale_colorization_to_all_outfits.py` too, so one change covers all
23). Head/face/facial-hair/accessories: new
`pipeline/add_outline_region.py`, modeled directly on the existing
`pipeline/add_skin_region_to_heads.py` precedent. That new script also
had to normalize 35 SVGs (22 face, 4 facial-hair, 9 accessories) whose
Ink fill lived only on a wrapping `<g fill="#000000">` rather than the
path itself — `frontend/logic.js`'s `recolorSvgText` can't recolor
that (its regex requires `id="..." fill="..."` adjacent on the same
element) — fixed by injecting the fill directly onto the path, a
strict visual no-op (inheritance already rendered it that color).

**No frontend code changes were needed at all** —
`renderColorPickers`/`recolorSvgText` already operate generically over
whatever's in `color_regions`; confirmed live, not assumed, before
declaring this done.

**Directly resolves the "flat black shape" complaint for cases like
crossed_arms' pants** (baked into Ink geometry, no separate Chromatic
shape exists for them in the source — see this file's own "crossed_arms
skin-clip" entries above for how that was discovered): changing the
item's outline color now visibly recolors that geometry too, since it
literally *is* Ink — not a true independent pants color, but no longer
an undifferentiated flat black mass either. Screenshotted before/after
as direct evidence.

**Verified**: 212 pipeline + 59 backend + 482 frontend tests passing
(up from 200/59/379 — the jump reflects both new dedicated tests and
existing parameterized tests now covering many more real colorizable
items). Full downstream geometry chain re-run and confirmed unaffected
(0 rewrites). All 5 existing live e2e scripts re-run; 2 needed updates
for now-stale hardcoded exact region-count/list assertions
(`scaled-colorization-e2e-check.js`, since retired, see below, and
`colorize-e2e-check.js` — the latter's "non-colorizable outfit" scenario also fully removed, since no
real outfit item has been non-colorizable since `scale_colorization_to_all_outfits`
shipped; that code path is still tested via
`backend/tests/test_validation.py`'s
`_add_synthetic_noncolorizable_outfit`; both scripts broke with plan 19
step 3a (category rows) and step 3c-1's Skin group:
`scaled-colorization-e2e-check.js` was retired in plan 19 step 3a-2, see
`scripts/RETIRED.md`, and `colorize-e2e-check.js` was rewritten in plan
19 step 3a-2).
Broad screenshot check across
all 9 families at default settings: pixel-identical to before this
change.

**Explicitly out of scope, per the operator's own decision**: true
per-garment-part independent outline color. **Also out of scope,
deliberately sequenced after this**: the broader UI/UX redesign of the
parts/clothing selector the operator also asked for — the real swatch-count-
per-item distribution this change produces (some items 0→1 color
controls, others 4→5) should inform that design rather than guessing
at it beforehand.

## Per-part color state was bleeding across every equipped item, 2026-09-13 (later)

The operator, live, after the outline feature above shipped: "when [outline
editing] happens, it recolors all the 'look' icons, and then they
won't go back. more testing is needed to make sure things can keep
changing predictably." Full plan (plan-mode approved before
implementation): `~/.claude/plans/dreamy-foraging-giraffe.md`.

**Root cause, confirmed live**: `frontend/app.js`'s `renderColorPickers()`
only ever showed swatches for the equipped *outfit* — never head/face/
facial-hair/accessories, even though the outline feature above gave
every one of them real `color_regions`. `state.colors` was a single
flat `{role: hex}` dict shared across every rendered layer regardless
of slot. Since every item now declares an `"outline"` region with that
exact name, one edit to the only visible outline swatch (the outfit's)
wrote `state.colors.outline`, which every OTHER layer — every other
equipped slot, and every unequipped option icon for anything sharing
that role — read from too, with equipItem's own "carry colors over
unchanged" design (originally there specifically to keep `"skin"`
synced) never resetting it back.

**Fix**: `state.colors` nested by slot (`{slot: {role: hex}}`).
`"skin"` stays the one explicitly-synced exception (now an explicit
sync in `setColor`/`equipOutfit`/`equipItem`, not an accidental side
effect of key collision) — every other role, including `"outline"`,
is genuinely independent per slot. `equipItem`/`unequipItem` now reset
*that slot's own* colors to its own item's defaults instead of
carrying the whole dict over unchanged. `renderColorPickers()` rewritten
to show every currently-equipped part as its own labeled group (the operator's
own choice among three presented layout options), all expanded at
once. (Since 2026-09-24, skin is its own single Skin group instead of a
swatch in each part's group: see "One skin control" below.) Backend's `colors` API shape (`LookIn`/`LookOut`,
`toolkit.validation._validate_colors_for_item`) updated to match,
nested the same way — validated per-slot against that slot's own
equipped item, not just the outfit's.

**A second, related bug found live while verifying the first fix**: on
the very first equip of a session, there's no "previous" skin value to
carry forward, so outfit and head each independently kept their own
raw manifest default (the outfit's real skin tone vs. head's own
deliberately-`#FFFFFF` placeholder, see
`pipeline/add_skin_region_to_heads.py`) — visibly mismatched from the
very start, not just after the first edit. Fixed: on every
`equipOutfit`, the new outfit's own skin default becomes the look's
authoritative starting point when there's no previous custom value to
carry forward instead, synced to every slot immediately.

**Verified**: real repro sequence (set outfit outline, switch heads,
confirm no bleed and correct reset, confirm skin still synced
throughout) scripted as a permanent regression check,
`scripts/per-part-color-independence-e2e-check.js`, not a throwaway.
(Rewritten 2026-09-24 for the category rows and the one Skin group,
keeping the outline-bleed checks over head switches and adding the
reverse direction, head outline to outfit; log
`scripts/evidence/skin-control-3c1/per-part-color-independence-e2e-run.log`.)
New/updated unit tests in `frontend/tests/logic.test.js` for
`setColor`/`equipOutfit`/`equipItem` covering the sync and
non-bleeding behavior directly. Backend tests updated for the nested
`colors` shape end-to-end (create/update/round-trip through the real
HTTP API). Every existing live e2e script that queried the Colors
panel re-run and fixed where it queried `[data-color-pickers]`
unscoped (now matches every equipped part's swatches together, not
just the outfit's) rather than the new `[data-color-picker-group="outfit"]`
scope. Full suite: 212 pipeline + 59 backend + 488 frontend, all
passing.

**Also reported live, same message, tracked but not fixed in this
pass** (see this file's own "Add a per-item outline/line color..."
entry above for the identical, already-decided root cause): "it isn't
consistent which color areas are editable" across an outfit family's
own alternates (e.g. `crossed_arms-1` has a colorizable `top` but no
`pants` region; `crossed_arms-2` has the reverse) — this is the same
"some garments are baked directly into the merged Ink linework, with
no separate shape in the `.sketch` source at all" limitation already
found and accepted when scoping the outline feature, now also visible
on the fill side for the specific items affected. Not new, not
arbitrary, and not something a UI/state fix can address — would need
the same kind of risky, unvalidated geometric splitting work already
declined. The stale "Phase 2 — 10 curated outfits" UI text the operator also
flagged (`frontend/index.html`) was fixed alongside this.

## robot_dance sideways head/neck misalignment, measured, 2026-09-24

The operator, live: on robot_dance the head is shifted sideways relative to the
body, on every outfit, and easiest to see at the neck while switching
outfits. This entry records a measurement only, nothing is fixed yet
(agentic-workspace `plans/backlog-plan-18.md` step 2). The full method,
data and crops are in `scripts/evidence/robot-dance-neck/README.md`.

**Measured in the real app** (Chrome, 131 outfit×head combinations
across all 9 families). Each result compares the chin-to-neck-top x
offset with the same offset in the artist's raw source file. For all 3
robot_dance outfits, the neck sits **16.25 units (8.84 preview px) right
of where it was drawn**. That is one constant for the family: every head
sits exactly where its raw file puts it. The 15 measurable baseline
combinations (blazer, easing, pointing_finger, resting, shirt, walking)
are within ±1.75 units. crossed_arms has the same bug at −9 units.

**Cause**: `5b7fd7e`'s colorization regeneration of the "remaining"
outfits dropped the raw pose-group translate (x −30.736217 for
robot_dance). Families whose reference outfit is a curated item got
that back from `normalize_outfit_horizontal_position`. robot_dance's
and crossed_arms' reference outfits are themselves "remaining" items,
so those two families never got it back. `normalize_family_head_gap`'s
heuristic dx (−14.536219 for robot_dance, since `446967e`) restores only
about half of it.

**Claims this makes false** (flagged here first, while the task was
measurement only; each has since been corrected in place by the fix below):
- `pipeline/normalize_family_head_gap.py`'s module docstring, point 2,
  says the X shift was measured as +11.6 and corrected. The measured
  residual after its correction is 16.2 units. *Corrected: the docstring
  now opens with a dated retirement note saying so.*
- `plans/session-checkpoint-2026-09-13-geometry-sweep.md`, item 4:
  "crossed_arms/robot_dance had a real horizontal head-vs-outfit offset
  (X) — fixed." Only partly fixed. *Corrected there with a dated note.*
- The "crossed_arms/robot_dance apparent-size fix, 2026-09-13" entry
  above says head-to-body alignment is "still correct". Flagged in place.

~~**Open question for the operator**: which fix? One option restores the
exact lost pose-chain translate for the affected families. That would
also change crossed_arms, which has the same bug but wasn't reported.
The other replaces only head-gap's heuristic X. Either way the
canvas-bounds and thumbnail stages need re-running afterwards. Y (head-gap
dy 92.866176 against a lost chain y of 96.264357) wasn't measured.~~
**Resolved 2026-09-24:** the operator chose the first option (restore the
exact translate, crossed_arms included).

**Fixed, 2026-09-24 (later the same day).** `pipeline/scale_colorization_to_all_outfits.py`'s
new `effective_calibration()` adds back the translate that
`pipeline.catalog` baked each outfit at, computed from the raw files the
same way `catalog.py` does. It does this for the remaining items in the
families whose reference outfit is itself a remaining item: crossed_arms
translate(−23.736217, 101.264357), robot_dance translate(−30.736217,
96.264357). It doesn't estimate anything. `normalize_family_head_gap` is
retired (`TARGET_FAMILIES = []`, so it only strips its old wrapper) because
its estimate would move these outfits off the raw placement again.
`normalize_outfit_horizontal_position.main()` had a separate bug: it only
rewrote items that still needed a correction, so robot_dance-1 kept its
stale +30.736209 wrapper. It now also removes wrappers that are no longer
needed. The whole chain was re-run (scale → vertical → horizontal →
head-gap → canvas height → canvas bounds → thumbnails). Only crossed_arms
and robot_dance files and their manifest `canonical_viewbox` changed:
crossed_arms `0 -36 271 720` → `-5 -36 267 728`, robot_dance
`0 -41 340 735` → `-1 -41 324 738`. No `option_thumbnail_viewbox` changed.
A second full run changed nothing.

**Y was real too.** `measure-neck.js` now also measures chin-bottom minus
neck-top against the raw file. Before the fix: robot_dance +3.5, +3.5 and
+3.75 units (the outfit sat that much too high), and crossed_arms-1 +7.5.
These match the head-gap dy falling short of the translate's y: the
regression test's pre-fix run (`regression-test-prefix.log`) measures
the Ink top edge 3.398 units too high for robot_dance-2/-3 and 7.289 for
crossed_arms-1. Both are fixed by the same restoration.

**Measured after the fix** (same script, same 131 combinations,
`measurements-before.csv` / `measurements-after.csv`): error vs raw
(x / y), robot_dance-1, -2, -3: 0 / 0 each; crossed_arms-1: 0.25 / 0.25
(crossed_arms-2's own head has no raw ground truth). Only the 28
crossed_arms and robot_dance rows differ between the two CSVs (`git diff
--no-index`). The other 103 rows (`expr 131 - 28`) and `raw-reference-*.csv`
are byte-identical. Regression test:
`pipeline/tests/test_scale_colorization_to_all_outfits.py`'s
`TestRawPoseTranslateIsRestored`, which failed on the pre-fix catalog
(`regression-test-prefix.log`, exit 1) and passes now.

**Not changed, noted for later:** the baseline families' y errors
aren't all within ±1.75 the way x is. blazer-3/-4 are −3.5/−3.25 and
shirt-3/-4 are +4.25/+4.25, both before and after this fix. Not
investigated, so the cause is unknown; this fix doesn't touch those
families. Nobody has reported them.

## Side-scrolling 5-icon category rows in the real app, 2026-09-24

agentic-workspace `plans/backlog-plan-19.md` step 3a: the operator's approved
mock (`scripts/evidence/carousel-mock/`) is now the real `frontend/`.
Every category (head, body style, face, facial hair, accessories,
outfit) is one row of 5 icons with ‹ › (1) and « » (5) that wrap around,
a "6–10 of 31" indicator, arrow keys and swipe. The preview is on the
left. Each row keeps its selected item in view. The order is the same on
every body style: alphabetical, None first, and the default outfit first.
None has a crossed-out icon, and the Clear buttons are gone. Names are one
line with a tooltip, the selected item has a 3 px outline, and nothing
moves the layout: rows have fixed heights, a None-only category is
greyed out with a note, and the status message is one line. The README's
"Interface" section has the details.

**Catalog change:** polka_dots had no facial-hair `*-None` (its raw
files only draw a Full beard). That made it the only body style that
couldn't remove facial hair and the only one that started with a beard
(audit finding #13). `pipeline/add_missing_none_items.py` adds an empty
`*-None` item to any facial-hair/accessories group without one, the same
shape as the build-made ones. Today that's only
`polka_dots/facial-hair/*-None`, so the catalog had 423 items, up from 422
(567 since "Facial hair and accessories on every pose", at the end of
this file; 594 since "Hats as a layer"). polka_dots now defaults to None like every other body style. The
backend's "null needs a *-None item" rule is unchanged. No real pair
exercises its rejection path any more, so
`backend/tests/test_validation.py` now covers it by deleting that row
from the test database.

**Evidence:** `frontend/tests/rows.test.js` (26 tests) fails 26 of 26
against master's `logic.js` and catalog
(`scripts/evidence/rows-3a/unit-tests-against-master.log`, exit 1).
`scripts/rows-e2e-check.js` checks all 9 body styles in Chrome against
the real backend: `scripts/evidence/rows-3a/rows-e2e-run.log` is the
passing run, and `rows-e2e-against-master.log` is the same check against
master's frontend, which fails. The e2e check found one real bug of its
own. A long rightward swipe on a row triggered the browser's
back-navigation gesture and left the page, so the row viewport now has
`touch-action: pan-y`.

**Not in 3a** (steps 3b/3c): thumbnail framing and crops, the colour
swatches, and which choices carry over on a body switch all behave as
before. (The swatches changed in 3c-1, 2026-09-24: see "One skin
control" below.)

## Hair colour, part 1: the 7 region styles and the bandanas, 2026-09-24

agentic-workspace `plans/backlog-plan-18.md` step 5b-1. The operator: "every
hair needs a color option … a color and an outline color". The hair
spike (`agent/cw-hair-spike`, `scripts/evidence/hair-colour-spike/`)
found 7 styles whose hair is a Sketch "Hair" fill region inside the
head's one white shape. That shape is the `skin` region, so Cornrows,
Gray-Bun, Gray-Short, Medium-Bangs-2, Mohawk, Mohawk-2 and Short-4 had
skin-coloured hair. Bun's and Bun-2's bandana was skin-coloured too.
The operator chose Option A and these defaults:

- **Roles.** Head items get `hair` and `hair-outline`, separate from the
  face `outline`. Bun and Bun-2 get `bandana`.
- **Defaults.** Each hair and bandana starts at its Sketch source colour
  (listed in the README's "Hair colour" section). The hair outline starts
  black.
- **Carry-over.** Chosen colours stay across head and body switches.
  They're stored per slot and role, as every colour is, so there's no
  database change. (Superseded by part 2, below: in-progress picks are
  now kept on their own in `state.chosenHeadColors`. Since plan 18 step
  5b-3 a saved look stores them too, as `carried_colors`, next to the
  per-slot colours: "Saved looks keep the carried hair picks", below.)
- **Hats** keep their own colours (plan 18 step 4).

**Built:** `pipeline/split_hair_from_head.py` cuts all 81 affected head
items (7 hair styles and 2 bandana styles, `expr 9 \* 9`). It works from
the Sketch regions pinned in `pipeline/head_hair_regions.json`, mapped
by the white-shape bbox fit that the hat split uses. The fit is exact on
all 81 items: white-shape IoU 1.0000, ink IoU ≥ 0.9999.
- The hair outline is the ink within 14 atom units of the hair region.
- The ink is cut per subpath. Face lines that don't cross the cut stay as
  the source curves.
- The rewritten SVGs are 1.04–4.4× their old size, measured with
  `git cat-file -s` against HEAD. The range runs from polka_dots Bun to
  blazer Gray-Bun (4,429 → 19,317 bytes). All 81 together went from
  2,145,345 to 2,941,860 bytes.
- Re-running the whole chain changes no file, including
  `fix_crossfamily_head_backgrounds`, which regenerates all 250
  cross-family heads (`chain-rerun.log`).

`frontend/logic.js`'s `carriedHeadColors` treats a value still at the
current head's own default as not chosen. So switching from an untouched
Mohawk to Gray-Bun shows Gray-Bun's grey, not Mohawk's pink.
(Superseded by part 2, below: `carriedHeadColors` now reads only
`state.chosenHeadColors`, and the comparison with the head's defaults
moved to `chosenFromHeadColors`, for a loaded look or older stored
state.)

**Open** (all four closed by part 2, below):
- A head with none of these roles in between drops the choice. That's
  the other 24 styles until part 2 gives the 18 solid-ink styles the
  roles too.
- The 14-unit rule also puts Medium-Bangs-2's ear contour into the hair
  outline.
- It leaves a thin black edge outside the left of Short-4's hair outline
  (`after.Medium-Bangs-2.png`, `after.Short-4.png`).
- Bun's hair is solid ink, so it's part 2.

**Evidence** (`scripts/evidence/hair-colour-5b1/README.md`, exit statuses
there):
- **Chrome renders.** Before: every hair and bandana sample is skin
  `#D08B5B`. After: source colours, and they recolour.
- **New tests against master.** They fail against master's catalog and
  `logic.js`.
- **e2e.** `scripts/hair-colour-e2e-check.js` passes (148 checks) on a db
  seeded from master's manifest before the change. It fails
  (56 of 148) against master's frontend. (Since part 2 it runs part 2's
  checks; rewritten 2026-09-24 for step 3c-1's Title Case captions and
  Skin group, see "One skin control" below.)
- **Live db.** That seeded db got the roles on startup, and its saved
  look was unchanged.

## Hair colour, part 2: the 18 solid-ink styles, separate carried colours, 2026-09-24

agentic-workspace `plans/backlog-plan-18.md` step 5b-2. The operator's
decisions:
1. The 18 styles that draw their hair as solid black ink (the spike's
   class b2) get `hair` and `hair-outline`, the hair outline a **derived
   rim** ("fine for now"; hand-drawn boundaries are Option C, later).
   Both default to black. The face keeps `outline`. Bear and the
   hat-beanie band stay out; No-Hair-1, hat-hip, Hijab and Turban have no
   hair.
2. A chosen hair, hair-outline or bandana colour is kept on its own, so
   it survives any switch, through a style without that role too (and
   bandana-outline since 2026-09-25, "Hats as a layer").
3. Each style shows its own colour until one is picked.
4. Tune three outline edges (Cornrows' braid lines, Medium-Bangs-2's ear,
   Short-4's left strip).
5. Old saved looks load with each style's defaults and are updated on
   their next save. No migration. (For the hair roles. 5b-3 later added
   one column for the saved picks, below.)

**Built:**
- **The cut.** `split_hair_from_head.py` cuts all 162 solid-ink items
  (`expr 18 \* 9`). The hair mass is the ink surviving an opening of 12
  atom units, plus the slivers and corner pieces the opening cuts off its
  edge. The rim is the mass's outer 12 units (`🖍-Hair-Ink`), and the fill
  is the mass less 6 (`🎨-Hair`, under the rim). The rest of the ink stays
  `🖍-Ink`, reaching 3 units into the hair where a face line joins it.
  Parameters are pinned under `solid_ink` in `head_hair_regions.json`.
- **The fit.** It's exact on all 225 split items: white IoU 1.00000,
  worst ink IoU 0.99996 (`fit_iou.py`, `fit-iou.log`). Part 1 claimed this
  for its 81 without a committed computation.
- **Tuning.** Pinned polygons (`hair_ink_zone`) add to or take away from
  the region styles' 14-unit zone:
  - Cornrows' braid lines are hair outline (orange in the renders). In
    the hair colour they'd vanish into the fill; `cornrows-braids-options.png`
    shows part 1, the hair outline and the hair colour.
  - Medium-Bangs-2's ear contour is face outline.
  - All of Short-4's left edge is hair outline.
- **Frontend.** `state.chosenHeadColors` holds the picks.
  `carriedHeadColors` reads only it. A loaded look, or in-progress state
  stored before part 2, takes as picked the hair colours that differ from
  the head's defaults (`chosenFromHeadColors`). So a save and load lost a
  pick made on a head without that role, or equal to the saved head's
  default (the operator, approval b6e5d4a-1: kept for part 2). Since 5b-3 the
  look stores the picks and they come back (below).
- **Head thumbnail crops.** They're recomputed
  (`compute_option_thumbnail_viewboxes`) and tighter now. On master, a
  path-scan artefact in Bun's old ink set every body style's head crop
  (evidence README).
- **Backend.** No change. The startup sync gives an existing db the roles
  on the 162 heads. An old look loads unchanged, and its next save stores
  the default hair colours (`backend/tests/test_hair_roles_part2.py`).
  (5b-3 changed the backend for the saved picks, below.)

**Open:**
- The rim is derived, so it follows the ink's silhouette, not a
  hand-drawn hair edge (Option C).
- Sharp hair tips (corners under about 84°) and hair strokes thinner
  than the opening (Twists' top knobs) stay face outline. They show as
  black notches only when the hair outline is recoloured
  (`after.Cornrows-2.png`, `corner-pieces.log`). No reach or width
  threshold separates them from the face lines by the ear, so the fix is
  Option C's hand-drawn boundaries.

**Evidence:** `scripts/evidence/hair-colour-5b2/README.md` (exit
statuses there).

## Facial hair and accessories on every pose (2026-09-24)

agentic-workspace `plans/backlog-plan-18.md` step 6. The spike
(`scripts/evidence/facialhair-accessories-all-poses/README.md`) found
that facial hair and accessories sit at a constant offset from the face
on every pose, measured from the artist's own items to 0.0000 units.
Paths below are from the repo root. The operator's decisions, 2026-09-24:

1. All 16 facial-hair styles and all 8 accessories on all 9 poses
   (option B). That's 144 new items, so the catalog has **567 items**, up
   from 423 (594 since the Hat slot, "Hats as a layer").
2. Fix Glasses 4 in the same build (option C). Its 5 generated files
   (blazer, easing, polka_dots, resting, robot_dance) were solid black
   frames, because the old loader kept only the first shape, the white
   one, and wrote it with a black fill. They now have shirt's white frame
   with a black outline.
3. Where facial hair overlaps the Hijab's jaw cloth, the cloth covers it.
   Facial hair stays selectable with the Hijab. The Hijab is the only
   head that covers the jaw: Turban and the two hats cover the top of
   the head, and no hairstyle reaches the chin
   (`scripts/evidence/facialhair-accessories-all-poses/build/heads-jaw-shirt.png`
   and `scripts/evidence/facialhair-accessories-all-poses/build/heads-jaw-crossed_arms.png`). In the follow-ups the same
   evening the operator chose the same for accessories: glasses arms and the
   eyepatch strap go under the cloth too.
4. Not in this step: a facial-hair colour (later, 5c: its own colour,
   following the hair colour until picked), and keeping face, facial
   hair and accessories over a body switch (plan 19 step 3c-2, built
   2026-09-26). Each new
   style keeps its source colours, so Full 4 and Moustache 9 keep their
   white fill.

**Pipeline.** `pipeline/add_facialhair_accessories_to_all_poses.py`
replaces `add_crossfamily_facialhair`, `add_crossfamily_accessories`,
`add_all_facialhair_to_calibrated_families` and
`add_all_accessories_to_calibrated_families`. Those four and their
tests are deleted (in git: `git show ce0454a:pipeline/<name>.py`). The
module runs after `pipeline.add_missing_none_items`, because each pose's
canvas comes from its `*-None` items. A slot's calibration on a pose is the pose's face
calibration plus a whole-number offset in the artist's units: (36, −152)
for facial hair and (112, −55) for accessories. Every source shape is
kept, white ones first. The 53 good generated items already in the
catalog are left alone. They reproduce byte for byte from their original
per-pose constants. The face-derived constants differ from those by
float noise only, under 1e-5 units per coordinate.

**Canvas.** Moustache 8's handlebar reaches past the canvas on 5 poses.
`normalize_family_canvas_bounds` grows a canvas's width by the same
amount on both sides, so its centre stays put (the operator's follow-up): on
crossed_arms by 19 units a side, easing 27, polka_dots 32, shirt 5 and
walking 11. No content moves inside the canvas, the preview's scale is
unchanged (the height sets it), and no figure moves in the preview: 0 px
on all 9 poses
(`scripts/evidence/facialhair-accessories-all-poses/build/preview_shift.py`,
log in `scripts/evidence/facialhair-accessories-all-poses/followups/preview-shift-after.log`). The first build grew
the right edge only, which moved those figures 1.4 to 9.0 px left.
`normalize_family_canvas_height` used to trim crossed_arms' width back,
which undid the bounds step on every re-run. Its width now only grows,
as its docstring already said.

**Icons.** The facial-hair row's icons share one crop per pose, as every
row does, but Moustache 8 is left out of it: in the shared crop its
handlebar widened it from 121 × 94 to 234 × 104 units on every pose.
Without it, every other beard is drawn 1.93 times as big as in the first
build. Moustache 8 gets the shared crop scaled about its centre until it
fits (234 × 182), so it sits where the others do in its tile, drawn
smaller than them (`pipeline/compute_option_thumbnail_viewboxes.py`,
`OWN_CROP_STYLES`;
`scripts/evidence/facialhair-accessories-all-poses/followups/icon-crops.log`).

**Hijab.** A mask on the facial-hair and accessory layers, made from the
Hijab's own shapes (`frontend/logic.js`, `maskUnderHeadCloth`), used in
the preview and the composite thumbnails. The layer shows only where the
Hijab's skin shows. A draw-order change would hide the whole layer under
the face, and a separate cloth layer would need a new head layer in
every rendering path.

**Evidence:** `scripts/evidence/facialhair-accessories-all-poses/build/README.md`
and, for the follow-ups, `scripts/evidence/facialhair-accessories-all-poses/followups/README.md`
(exit statuses there).

## One skin control, a fixed colour order, Title Case captions, 2026-09-24

agentic-workspace `plans/backlog-plan-19.md` step 3c-1. The operator, looking
at the live app: "there are two skin color pickers in the color section,
and they can overwrite each other but color the same stuff." That's the
UI audit's finding #19 (`scripts/evidence/ui-consistency-audit/README.md`):
Head skin, Outfit skin and the "Switch skin tone" button were 3 controls
for one synced value. Dragging one skin swatch left the other showing the
old value until the next full render. His standard point 7 (option A of
that README's point 7) and Title Case captions, group headings and row
labels, all chosen 2026-09-24, are what the Colors section now does:

- **One Skin group, first.** One swatch, with the "Switch skin tone"
  button beside it. No part's group has a skin swatch. It's shown
  whenever anything equipped has a skin region, and setting it
  (`setSkin`) goes through `setColor`'s existing sync, so every such
  part changes at once.
- **Groups in slot order** after it: Head, Face, Facial Hair,
  Accessories, Outfit (and Hat after Facial Hair since 2026-09-25). The
  headings, and the rows' labels (Body Style, Facial Hair), are Title
  Case by the same `displayName` rule.
- **Swatches in a fixed order** (`COLOR_ROLE_ORDER`): hair, hair outline,
  bandana, top, jacket, pants, shorts, shoes, prosthesis, outline last.
  Before, they followed each item's manifest order. Since 2026-09-25
  bandana outline, cloth, cloth outline, hat and hat outline come after
  bandana, each fill before its own outline ("Hats as a layer").
- **Captions in Title Case** (`colorRoleLabel` is now the rows'
  `displayName`): "Hair Outline", not "hair outline".

**Unchanged:** the stored colours (skin is still kept per slot, in
`state.colors.head.skin` and `state.colors.outfit.skin`), saved looks,
stored in-progress state, carried hair colours and the rows. No backend
or catalog change.

**Built:** `frontend/logic.js`'s `colorPickerGroups` returns the groups
and swatches, and `frontend/app.js`'s `renderColorPickers` only draws
them. The button is built inside the Skin group, not in `index.html`.

**Evidence** (`scripts/evidence/skin-control-3c1/README.md`, exit statuses
there):
- `frontend/tests/colors.test.js` (15 tests) checks one skin control on
  every outfit with every head, and on every face, facial hair and
  accessory, on all 9 body styles. It also checks the role order for
  every colourable item in the manifest, the captions and headings, that
  stored state and saved looks still load, and that stored state with no
  skin colour loads with the outfit's skin default on the swatch and on
  every part, not the head's white placeholder (`reviews/log/effe8d3.md`
  #3, `d0872dc.md` #1). The first 14 failed against master's `logic.js`
  (the 15th was added later), and so does `hair.test.js`'s caption test.
- `scripts/skin-control-e2e-check.js` runs in Chrome on all 9 body styles
  and every outfit, against the real backend, with the headings and row
  labels: 491 checks passed at 3c-1 (master `8ee5b2d`). Against master's
  frontend, 284 of the 491 failed, including the stale second skin
  swatch. The count grows with the catalog: 546 after plan 18 step 6
  (facial hair on all 9 poses; `e2e-run-on-fh-branch.log`), and 546
  again after step 4's Hat slot and head roles, which updated the
  script's role order and row labels
  (`scripts/evidence/hats-4/skin-control-e2e-run.log`).

**Older e2e checks** (none in `scripts/run-all-tests.sh`): of the 8 that
expect a skin swatch in the Outfit or Head group, or lower-case captions,
three were rewritten 2026-09-24 and pass (`skin-tone-feature-e2e-check.js`,
`per-part-color-independence-e2e-check.js`, the only check for an
outfit's outline bleeding onto the head over head switches, and
`hair-colour-e2e-check.js`). The other five broke with plan 19 step 3a
(category rows) and 3c-1. Plan 19 step 3a-2 rewrote
`colorize-e2e-check.js`, `crossed-arms-head-fix-e2e-check.js` and
`color-swatch-visual-e2e-check.js` for the rows and this section, and
retired `regenerated-colorization-e2e-check.js` and
`scaled-colorization-e2e-check.js` (`scripts/RETIRED.md`; runs in
`scripts/evidence/3a-2/`).

## Hats as a layer, and hat / hijab / bandana colours, 2026-09-25

agentic-workspace `plans/backlog-plan-18.md` step 4, from the hat-layer
spike (`scripts/evidence/hat-layer-spike/README.md`). This is the
deferred "hats" request from "Outfit vertical-position inconsistency"
above. The operator's decisions:
- **2026-09-24, on the spike ("all recommended"):**
  - Option A: a new optional **`hat` slot**, starting with the beanie and
    the turban cut out of their heads.
  - It's drawn after facial hair and before accessories.
  - Any hat goes on any hair for now.
  - Saved looks survive through a one-off, tested, nullable
    `ALTER TABLE look ADD COLUMN hat`.
  - The baked-in hat heads stay.
- **2026-09-24:** hats "need color and outline color separate from the
  hair they cover".
- **2026-09-24 evening:** the Hijab and the hip hat stay head styles, and
  get their own cloth or hat colour and outline, like hair. The bun
  bandana gets an outline colour too.
- **2026-09-25, approval 3d66046-1:** the hats' teal default `#9DDADB`,
  the Sketch colour, is intended. That includes the existing beanie and
  turban heads and saved looks that use them.

**Built:**
- **The Hat slot** (`pipeline/add_hat_layer.py`) puts a `*-None`, a
  Beanie and a Turban on all 9 poses, 27 items, so the catalog has 594.
  - Each hat is the Sketch fill region, pinned in
    `pipeline/head_hat_regions.json`, clipped to the atom's silhouette.
    That's role `hat`. Its outline is the atom ink within 14 atom units of
    the region, role `hat-outline`, default black.
  - The hats are placed with the head calibration, so no new calibration
    was needed.
  - Since the follow-ups (below), the Beanie is drawn 1.08 × 1.12 larger,
    about a point on its brim (`HAT_ENLARGE`).
  - The icons share one crop per pose (`compute_option_thumbnail_viewboxes`).
- **Head styles** (`pipeline/split_hat_cloth_from_head.py`, re-applied by
  `fix_crossfamily_head_backgrounds`):
  - The beanie and turban heads get the same `hat` / `hat-outline` cut, so
    a hat colours the same either way.
  - The hip hat's cap had no fill region: it's solid ink. It is cut like
    solid-ink hair, into a fill and a derived rim (`hat` / `hat-outline`,
    default black). So the spike's "no fill region" was answered the way
    hair answered it.
  - The Hijab gets `cloth` / `cloth-outline` (default black), the same
    way. Its Sketch forehead band, skin-coloured before, joins the cloth.
  - Bun and Bun-2 get `bandana-outline`, from the face ink and, on Bun-2,
    the hair rim along the bandana.
- **Frontend:**
  - `hat` is a slot between `facial-hair` and `accessories`.
  - A body style starts with its Hat None, and a body switch resets it
    (until plan 19 3c-2, 2026-09-26, which keeps the hat: see "A body
    switch keeps face, facial hair, hat and accessories").
  - The Hat row is None first, Title Case, with "No hats for this pose"
    for an empty row.
  - `COLOR_ROLE_ORDER` puts bandana outline, cloth, cloth outline, hat and
    hat outline after bandana, each fill before its own outline.
  - `bandana-outline` carries over switches like `bandana`. Hat and cloth
    colours don't.
  - The Hijab's mask of facial hair and accessories still takes
    everything but the skin shape as cloth, so recolouring the cloth
    doesn't change it.
- **Backend:**
  - `hat` is optional everywhere a look's slots are listed. An older
    client that sends no hat still saves.
  - `validate_look` accepts null where the pose has `hat/*-None`, which
    every pose does.
  - `toolkit.db.add_look_columns` is the one in-place migration. It
    runs in `init_db` before the fail-loud schema check. Running it twice,
    or on a fresh db, does nothing. Any other missing column still fails
    loud (`backend/README.md`). (Step 4 named it `add_look_hat_column`;
    5b-3 renamed it and had it add `carried_colors_json` too: "Saved
    looks keep the carried hair picks" below.)

**Where hair shows:**
- Long Afro stands out above and around both hats on every pose.
- Long hair shows below them, and since the follow-ups its crown is
  covered by both (it showed above the Beanie as first cut).
- Short 2 shows a little at the nape under the Beanie
  (`scripts/evidence/hats-4/renders/`).
- The tall styles still show above the Beanie: Pomp, Mohawk, Flat Top
  Long, Shaved 2, Cornrows 2, Bantu Knots and Long Curly
  (`hats-4/round-2/README.md`).

**Evidence** (`scripts/evidence/hats-4/README.md`, exit statuses there):
- **Unit tests:** `pipeline/tests/test_add_hat_layer.py`,
  `pipeline/tests/test_split_hat_cloth_from_head.py`,
  `backend/tests/test_hat_slot.py` and `frontend/tests/hats.test.js`.
- **Against master:** all four fail (`hats-4/teeth.py`). The pipeline
  catalog classes run on master's catalog with 56 failures and 75
  errors. `hats.test.js` fails 12 of 12.
- **`scripts/hats-e2e-check.js` in Chrome, on all 9 poses:**
  - 894 passed and 0 failed, including a look from a db seeded as master
    left it. That look loads with the Hat None and re-saves.
  - Against master's frontend and catalog: 163 passed, 135 failed.
- **Older checks:** `skin-control`, `hair-colour` and `rows` had
  hard-coded row and role lists that the Hat row and Bandana Outline
  broke. They are updated and pass, as do the other three maintained
  checks.

**Known, left as is:** 10 zero-area subpaths remain in the `🖍-Ink` of
Bun (3), Bun-2 (4) and hat-hip (3; none on master). Master's Bun and
Bun-2 had 6124. They draw nothing, and the only step that raises on one
(`fit_hijab_drape_to_pose`) reads only the Hijab.

**Follow-ups, 2026-09-25** (the operator, on the pre-merge preview;
`scripts/evidence/hats-4/round-2/README.md`, `hats-4/rollback/README.md`):
- **The Beanie covers Long's crown.** It's enlarged, as above. A new
  pipeline test checks that none of the hair of Long, Flat Top, Twists
  and six short and medium styles shows above it on any pose. The test
  fails at aff41f5, where 437.8 units² of Long's hair is above the Beanie.
- **Each hat in one row only (Beanie and Turban out of the Hair row): not
  done.** Old looks with the `hat-beanie` or `Turban` head would need
  mapping to "the head under the hat" plus the Hat item. The Turban head
  matches No Hair 1 + Turban. No head matches the beanie head, which has
  a band of short hair under the brim. Per the instruction ("if there's no
  clear hair under a hat, stop and report"), nothing was moved; the
  choice is the operator's. No other head duplicates a Hat-row item.
- **Rollback (approval 8413f19-1):** master (385e5b8) starts on a
  migrated db, returns every look, and its frontend loads a look saved
  with a hat, drawing no hat. Master's re-save leaves `look.hat` as it
  was, so rolling forward after a re-save on another body style loads
  the other pose's hat, and saving it gets a 400. That's an open
  question, not fixed. (Fixed by 5b-3: such a look loads with the pose's
  Hat None and saves. See below.)
- **Review fixes:** `isLookComplete` no longer exempts the hat, which
  defaults like facial hair and accessories (`reviews/log/74ee44c.md` #1).
  Also three stale comments (#2), and the 567 counts (`aff41f5.md` #1
  and #2).

## Saved looks keep the carried hair picks, 2026-09-25

agentic-workspace `plans/backlog-plan-18.md` step 5b-3. Until now a saved
look stored only the per-slot colours, so a hair, hair-outline, bandana
or bandana-outline pick made on a head without that role (or equal to the
saved head's default) was lost on save and load (part 2, approval
b6e5d4a-1).

**Built:**
- **Backend.** `look.carried_colors_json`, nullable. The one in-place
  migration, now `toolkit.db.add_look_columns`, adds it as it adds
  `look.hat`: running it twice or on a fresh db does nothing, and any
  other missing column still fails loud. `POST /api/looks` takes
  `carried_colors` ({role: `#RRGGBB`}, default {}); `GET` returns it, {}
  for a look saved before. Only the four carried roles that some head in
  the catalog has are kept; other roles are dropped, and a bad hex is a
  400.
- **Frontend.** Save sends `carried_colors: state.chosenHeadColors`.
  `stateFromSavedLook` restores the picks from it. Picks read off the
  head colours (`chosenFromHeadColors`, as before) fill in roles it
  lacks, so a look saved before 5b-3 (stored {}) loads as it did. For a
  look saved since, the two agree.
- **Rollback tolerance** (data another version wrote must load and save
  again):
  - A colour role the slot's item doesn't have is dropped by
    `validate_look`, not a 400. A bad hex, an unknown item id and colours
    on a non-colorizable item still raise.
  - A stored hat that's in the catalog but isn't a hat for the look's
    pose (the hats rollback run's step 5: walking's Beanie on a look
    re-saved on shirt by master) loads as the pose's Hat None with no hat
    colours, in `GET /api/looks/{name}` and in `stateFromSavedLook`, so
    it's never sent back. A hat id not in the catalog still fails loud.
  - Restored in-progress state gets the same: another pose's hat becomes
    the Hat None (it discarded the whole state before), and each slot
    keeps only its item's roles with `#RRGGBB` values.

**Evidence:** `scripts/evidence/5b3/README.md` (exit statuses there).

## Facial-hair colour: beards follow the hair until picked, 2026-09-25

agentic-workspace `plans/backlog-plan-18.md` step 5c. Until now every
beard's ink had the face "outline" role and Full-4's and Moustache-9's
white fill had none, so a beard couldn't take a colour. The operator chose the
spike's recommendations (`scripts/evidence/facial-hair-colour-spike/README.md`)
on 2026-09-25.

**Built:**
- **Pipeline** (`pipeline/split_facial_hair_colour.py`). Two roles,
  `facial-hair` and `facial-hair-outline`, a scheme per kind (option C),
  on all 144 facial-hair items; the 9 `*-None` items are untouched:
  - 11 solid-ink styles: the 5b-2 solid-ink cut (imported from
    `split_hair_from_head`). Fill → `facial-hair`, rim →
    `facial-hair-outline`, the ink left over stays `outline`. Full's two
    thin moustache lines join the fill through pinned include polygons.
    Defaults black and black.
  - Full-4 and Moustache-9: the white shape → `facial-hair` (default
    `#FFFFFF`), the ink → `facial-hair-outline` (black).
  - Moustache-1, -4 and -8: the whole ink → `facial-hair` (black), no
    outline role.
  So every beard looks as before until a colour is set.
- **Frontend.** A beard's `facial-hair` colour is the facial-hair pick,
  else the carried hair pick, else its default; `facial-hair-outline` the
  same from `hair-outline`. The hair pick counts on a head without hair
  (No-Hair-1, the hat heads). A beard pick is kept with the hair picks, so
  it carries over head and body switches and is saved as
  `carried_colors`. The Colors section's Facial Hair group shows Facial
  Hair, Facial Hair Outline and Outline swatches, as the beard has them.
- **Backend.** `carried_colors` keeps a facial-hair pick when some
  facial-hair item has that role; other roles are still dropped.
- **Old data.** Old saved looks and stored state have no facial-hair
  picks, so their beards follow the hair pick or keep their defaults. No
  migration.

**Evidence:** `scripts/evidence/facial-hair-colour-5c/README.md`.

## A body switch keeps face, facial hair, hat and accessories, 2026-09-26

agentic-workspace `plans/backlog-plan-19.md` step 3c-2, from the operator's
interface standard of 2026-09-24, point 8: choices that can carry over,
do, when the body style changes. Until now a body switch kept the head's
style (`headIdForFamily`) but reset the face to the body style's first
face and facial hair, hat and accessories to None.

**Built:**
- `equipOutfit` (`frontend/logic.js`) keeps face, facial hair, hat and
  accessories the same style on the new body style where it exists,
  matched by style name like the head (`sameStyleInFamily`). Where it
  doesn't, the face falls back to the first face and the others to None,
  as before. A None carries as the new body style's None.
- Their colours carry role by role when the style carried: a role the
  new item has keeps the previous value, a role the previous item lacked
  gets the new item's default. A fallback item gets its own defaults,
  because the old picks were for a different part. Facial-hair roles still
  follow the picks (`withFacialHairFollowing`).
- Unchanged: the outfit and its colours reset to the body style's
  defaults; the one Skin tone, the head carry-over, saved looks, the rows
  and their order.
- The body-switch status message says what carries.

Every body style has all 16 facial-hair styles, 8 accessories and both
hats, and the Cute face, so today only a face other than Cute can fall
back.

**Evidence:** `scripts/evidence/3c-2/README.md`.

### Head and Hair rows (agentic-workspace plan 20 step 2b, 2026-09-26)

**Decided (the operator, 2026-09-26):** the Head row is the 9 head styles,
named Head 1 … Head 8 and Bear, with the descriptive name in the
tooltip; a Hair row (None, then the 25 hairs) follows it. The head
style's own ear is drawn over the hair. Bear is a head style: the Hair row
greys out on it, and hats go on it. An old session or look with one of the
31 old heads becomes its head style and its hair.

**Built:**
- Catalog slots `head-style` and `hair` (step 2a's) are the app's; the old
  `head` items stay in the manifest as the pipeline's source and are no
  longer stored by the backend's sync (`RETIRED_SLOTS`).
- Draw order: outfit, hair back, head style, hair front, the style's ear,
  face, facial hair, hat, accessories. Hats clip both hair layers.
- The hair colours are the hair's (a Hair colour group); Bear's fur stays
  on its head style. Head style and hair carry over a body switch.
- `look.hair` is added in place; a saved look with an old head loads
  mapped. The body-style thumbnails no longer show each body's own default
  head before one is picked (the `headExplicitlyChosen` rule above): every
  body has the same head styles, so they show the look's own.

**Evidence:** `scripts/evidence/p20-2b/README.md`.
