# Builder plan — backlog-plan-1 step 1 (extraction pipeline)

Written before starting, per the v1 plan-checkpoint skill (since removed).
Branch: `agent/builder-cw-extraction`. Scope: exactly
`plans/backlog-plan-1.md` step 1 — nothing from step 2/3.

Note on process: this worktree has no `.claude/agents/` character
sheets and no live Matrix/agent-memory connection (MCP servers failed
to connect — ENOENT on a missing venv). There's no channel to post this
plan to and wait on. Per the task instructions ("note it in your final
report"), I'm writing this file as the durable checkpoint and proceeding
without a blocking pause, then surfacing it plainly in the final report
for a human to review after the fact. If that's wrong, easy to unwind:
nothing here is destructive, and step 1 is flagged `[retryable]` in the
backlog plan itself.

## Layout

- `assets/raw/peep-standing-{1..30}.svg` — raw, unmodified downloads,
  named by their real number (from the URL filename), for provenance.
- `pipeline/` — the Python package:
  - `extract.py` — ported from `plans/alignment-spike/spike_extract.py`,
    generalized: ancestor-anchor computation, own-transform extraction,
    composition. Same core algorithm, not reinvented.
  - `subfamily.py` — classify each raw file into a sub-family from
    `viewBox` + the `pose/standing/<family>-N` group id prefix.
  - `catalog.py` — walks all raw files, enumerates head/face/
    facial-hair/accessories/outfit groups per file, dedupes by
    (sub_family, slot, style-name) with an anomaly log if the same
    style-name recurs with a materially different own-transform, bakes
    each distinct item to a standalone SVG at a canonical per-(slot,
    sub_family) anchor, and emits `assets/catalog/manifest.json`.
  - `build.py` — CLI entrypoint tying download -> classify -> extract ->
    bake -> manifest.
  - `tests/` — `unittest`/`pytest`-free (stdlib `unittest`, no new
    dependency) tests, including a **self-reconstruction control test**
    per the spike's own lesson: rebuild a real source file from its own
    freshly-extracted, standalone-baked parts and diff the rendered
    result against the original before trusting any cross-file swap.
- `assets/catalog/manifest.json` — the catalog.
- `assets/catalog/BUILD_NOTES.md` — honest findings: sub-family counts,
  which file was picked as canonical reference per (slot, sub_family)
  and why, any items that didn't fit cleanly, any alignment caveats.
- `assets/catalog/verification/*.png` — real rendered screenshots, at
  least one full composed look per sub-family, produced via a puppeteer
  script (`pipeline/render_check.js` or similar) rendering the baked SVG
  layers to PNG — not a DOM-only check.

## Steps, in order

1. Download all 30 raw SVGs from the URL list, save under `assets/raw/`.
2. Classify each by sub-family (viewBox + pose-group prefix); don't
   assume only `shirt`/`resting` — log whatever's actually found.
3. Port the spike's ancestor+own-transform algorithm into `pipeline/extract.py`,
   with its own unit tests first (including a control test against the
   spike's own known-good files before touching the real 30).
4. Run self-reconstruction control test against several real files (not
   just the spike's 3) to confirm the ported algorithm is faithful.
5. Enumerate every head/face/facial-hair/accessories group per file and
   the outfit (`pose/standing/<family>-N`) group per file; pick one
   canonical anchor per (slot, sub_family) from a documented
   representative file; bake every distinct item to a standalone SVG at
   that anchor.
6. Generate `manifest.json`.
7. Render at least one full composed look per sub-family with puppeteer,
   save PNGs, actually look at them.
8. Write `BUILD_NOTES.md` with honest findings (counts, anomalies,
   anchor choices, any known misalignment).
9. Commit.

## Done-when

Matches `plans/backlog-plan-1.md`'s step 1 done-when exactly: all 30
(or a documented reasoned subset) extracted into a manifest + standalone
per-item SVGs, at least one real rendered/verified combination per
sub-family, a re-runnable (not one-off) pipeline.

## Status: done, 2026-09-11

All 9 steps above completed. Real findings (not what was assumed going
in): 9 sub-families (not 2), 105 catalog items, all real-rendering
verified (self-reconstruction + head swap + outfit swap for 8/9
families). One real bug was caught by the rendered check specifically
(a dropped inherited `fill-rule`, invisible to the transform-math unit
test) and fixed -- see `pipeline/README.md` and
`assets/catalog/BUILD_NOTES.md` for the full writeup. Committed on
`agent/builder-cw-extraction`.
