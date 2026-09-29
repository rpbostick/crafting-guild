# Checkpoint: plans/requirements.md drafting (agent/requirements-expert-cw)

Written 2026-09-11, before drafting the full requirements doc, standing in
for the v1 plan-checkpoint skill (since removed) — that skill file did not
exist in this worktree at the time.
Flagging that gap rather than silently skipping the discipline it's meant
to provide.

## Research already done (see this worktree's plans/open-peeps-research*)

Confirmed by direct inspection of `sample-peep-standing-30.svg` (not just
reading the prose summary in the research doc):

- Every named component group (`pose/standing/shirt-1`, `head/Long-Curly`,
  `face/Smile`, `accessories/Glasses-4`) contains exactly **two flat
  paths**: one `id="🎨-Background" fill="#FFFFFF"` and one
  `id="🖍-Ink" fill="#000000"`, each a single monolithic `<path d="...">`
  merging every sub-shape of that whole component into one compound path.
- This means **within** `pose/standing/shirt-1` (the whole body + that
  pose's clothing, fused), there is no existing shape-level separation
  between skin and clothing at all — it's one white fill region and one
  black outline region for the entire body+shirt silhouette. The
  research doc's "real modularity" finding is true at the
  group-swapping level (swap hairstyle/face/accessories/whole-outfit
  wholesale) but does NOT extend to recoloring skin separately from
  clothing within a pose group — that shape-level split doesn't exist in
  the raw file and would have to be authored (segmenting one big
  compound path into per-region sub-paths), not just tagged.
- This is a stronger and more specific risk than "cross-file alignment
  might not work" — it's "even a single file's body shape isn't
  segmented by color region yet." Both risks are real and distinct;
  requirements.md needs to name both.
- DiceBear's proven technique (`skinColor`/`clothingColor`/
  `headContrastColor` template placeholders) works because DiceBear's
  Figma-exported bust components apparently already had that
  segmentation done upstream (by the original Figma authoring or by
  DiceBear's exporter) — that authoring effort is invisible to us and
  has NOT been done for standing/sitting poses by anyone.

## Section breakdown for plans/requirements.md

1. Framing (what/who/unofficial stance) — re-decide the 3-audience frame,
   don't assume it transfers unchanged.
2. Asset scope, phased — MVP from the 30 standing samples' *swappable
   groups* (hair/face/facial-hair/accessories/whole-outfit) as the
   near-term buildable slice; skin/clothing independent recoloring
   within a pose flagged as a separate, harder, later phase gated on a
   prototype.
3. Shape-tagging / colorization data model — manifest-driven proposal
   (SVG stays source-of-truth for geometry; a sidecar manifest maps
   region IDs to color roles), justified against the two real risks
   above.
4. Artist/tutorial deliverable — what segmenting a compound path into
   color regions actually requires teaching.
5. Stack decision — Python-leaning default vs. actual needs (SVG path
   manipulation/splitting tooling is the real bottleneck, not app glue).
6. Explicit out-of-scope.
7. Delivery/done-when + open questions (segmentation-authoring effort is
   the headline open question).

No user sign-off loop is possible in this dispatch (one-shot, report at
the end) — proceeding straight to drafting `plans/requirements.md` per
the dispatch instructions rather than blocking on an interactive
checkpoint the harness has no path to answer mid-task.
