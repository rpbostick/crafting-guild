# Open Peeps art sourcing — research findings, 2026-09-11

Copied verbatim from agentic-workspace's `plans/open-peeps-research-2026-09-11.md`
(and `plans/open-peeps-research/`), written the same day this repo was
scaffolded — that copy is the framework's own durable record of why the
pivot decision was made; this copy is the working reference for actually
building Colorwright. Cross-repo paths below (`plans/pilot-paper-doll-workshop.md`)
refer to agentic-workspace, not this repo.

Durable record of the research that led to the decision to mothball
Paper Doll Workshop and start a new project built around real Open Peeps
art (see `plans/pilot-paper-doll-workshop.md`'s "Pilot conclusion" and
`pm/ROADMAP.md` item 3, both in agentic-workspace). Written because the
journalist's final pilot pass correctly caught that this research
existed only as session-scoped conversation, not as anything a later
session could re-verify — the same "ground-truth over recollection" gap
`CLAUDE.md` exists to prevent, just applied to a research claim instead
of a code claim (agentic-workspace's `reviews/pilot-findings.md`,
journalist final pass). Every claim below cites a real, checked-in
artifact in `plans/open-peeps-research/`, not just prose.

## What Open Peeps actually is

Hand-drawn character illustration library by Pablo Stanley
(https://twitter.com/pablostanley), published at
https://www.openpeeps.com/.

## License — verified two independent ways

1. **`@dicebear/open-peeps` npm package's own LICENSE file** (installed
   2026-09-11, version 9.4.2), saved verbatim at
   `plans/open-peeps-research/dicebear-open-peeps-LICENSE.txt`:
   > Source: Open Peeps (https://www.openpeeps.com/)
   > Designer: Pablo Stanley (https://twitter.com/pablostanley)
   > License: CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/)

   (The code wrapper itself — DiceBear's Figma-export tooling — is
   separately MIT-licensed; that MIT grant covers DiceBear's own export
   code, not the Open Peeps designs, which are CC0 as quoted above.)
2. **Every individual SVG downloaded directly from openpeeps.com's own
   CDN embeds CC0 attribution metadata in the file itself** (RDF/Dublin
   Core `<metadata>` block, `<dc:title>Open Peeps</dc:title>`,
   `<dc:creator>Pablo Stanley</dc:creator>`, license URI pointing at
   creativecommons.org's CC0 deed) — confirmed by direct inspection of a
   generated sample (via the DiceBear package) and of a real
   openpeeps.com-hosted file (see next section).

## Real, direct downloads — no Figma, no Gumroad checkout required

Contrary to an earlier, less-informed pass at this research (which
assumed Figma was the only source, based on a narrower citation in
DiceBear's own plugin credits, not on checking openpeeps.com directly),
**openpeeps.com hosts real SVG/PNG files directly on a public CDN**
(`cdn.prod.website-files.com`), linked straight from the homepage's
"Grab and go!" section — no login, no purchase flow, no Figma account.

- The homepage has three tabs: **Busts**, **Standing**, **Sitting** — all
  three are real, separate pose categories with their own sample sets,
  not a DiceBear-specific limitation. (An earlier pass wrongly attributed
  "bust-only" as an inherent Open Peeps limitation — that's actually
  DiceBear's own scoping choice for their headshot-avatar use case, not
  a constraint of Open Peeps itself. Corrected here.)
- **30 full standing-pose SVGs**, confirmed direct public URLs, listed
  in full at `plans/open-peeps-research/openpeeps-standing-svg-urls.txt`
  (fetched 2026-09-11 from the live homepage HTML).
- One real sample downloaded and kept as evidence:
  `plans/open-peeps-research/sample-peep-standing-30.svg` (fetched
  directly from the first URL in that list), rendered to
  `plans/open-peeps-research/sample-peep-standing-30.png` for a
  quick visual check without needing to open the SVG.

## Real modularity — confirmed via named layer groups in the raw file

`sample-peep-standing-30.svg`'s top-level group IDs (checked directly,
`grep -o 'id="[^"]*"'`):

```
accessories/Glasses-4
a-person/standing
face/Smile
facial-hair/*-None
head/Long-Curly
pose/standing/shirt-1
```

This is a real, separable structure — a named group per component
category (head/hair, face, facial hair, accessories, and the clothing
for that specific pose, e.g. `pose/standing/shirt-1`) — not a single
fused illustration. Confirmed across multiple sampled files (bust,
standing, and sitting variants all checked during this research), each
with the same naming pattern, different specific variant names.

## Colorization — real, but it's DiceBear's addition, not Open Peeps' own feature

The raw files downloaded directly from openpeeps.com use flat, hardcoded
`fill="#000000"` / `fill="#FFFFFF"` — pure black-and-white line art, no
built-in color parameters. openpeeps.com's own "Change the colors"
tutorial section is a GIF showing manual recoloring in a design tool
(Figma/Illustrator/Sketch) — not a documented technical mechanism.

**`@dicebear/open-peeps` proves the technique works, for the subset it
covers.** Its Figma-exporter-generated component files use template
placeholders instead of hardcoded fills. Saved verbatim, not just
prose-quoted (`plans/open-peeps-research/dicebear-open-peeps-head-component.js`,
177KB — the full file, package version 9.4.2), e.g.:

```
fill="${escape.xml(`${colors.skin}`)}"
fill="${escape.xml(`${colors.clothing}`)}"
fill="${escape.xml(`${colors.headContrast}`)}"
```

fed by a schema (saved verbatim at
`plans/open-peeps-research/dicebear-open-peeps-schema.js`) declaring
plain 6-digit hex arrays, e.g.:

```json
"clothingColor": {
  "type": "array",
  "items": { "type": "string", "pattern": "^(transparent|[a-fA-F0-9]{6})$" },
  "default": ["e78276", "ffcf77", "fdea6b", "78e185", "9ddadb", "8fa7df", "e279c7"]
}
```

**This only covers DiceBear's own bust/headshot subset** — confirmed via
their `Options` type, saved verbatim at
`plans/open-peeps-research/dicebear-open-peeps-types.d.ts`: only `head`,
`face`, `facialHair`, `mask`, `accessories` are declared, no `pose` or
`standing`/`sitting` option exists in the package at all. Nobody has
published the equivalent template-ization for the real standing-pose
files this project actually needs — that identification work (which
black shapes are skin vs. clothing vs. hair, per standing-pose variant)
is real, un-done engineering, not a solved problem to just import.

## What this means for scoping this project

- Real, full-body, license-clean, genuinely modular source art exists
  and is directly downloadable — confirmed, not assumed.
- The colorization *technique* is proven (template placeholders + a hex
  array schema) — confirmed, not assumed.
- The colorization *mapping* for standing/sitting poses does not exist
  yet anywhere — this is the real, sizable engineering task this
  project's requirements pass needs to scope honestly, not a quick
  integration.
