# This installation (private)

Read with CLAUDE.md; where they differ, this file wins. Not part of a public release.

## Asking
- Decisions go to Patrick through AskUserQuestion, recommended option first and labelled, at most four per call, in rounds. Where several options can apply together, use multi-select checkboxes. He usually answers "all recommended".
- Ask before any infrastructure change (replacing a layer, adding a service, changing how builders are launched).

## Previews
- Previews on :8801 and up (`WS_PREVIEW_PORT`), the live app on :8800 (`WS_PREVIEW_PORT_MAIN`), builders' own browser checks on 8790 to 8799.
- Pages made for him to look at (comparisons, review pages) are served from the scratchpad (`python3 -m http.server 88xx --directory …`), not published as claude.ai artifacts; a tool he uses from several computers with saved state is the exception (a private artifact).
- Every preview: ask with AskUserQuestion whether to open it in his browser, and on yes run the `open it:` line `ws serve` prints (`WS_BROWSER_CMD`, `firefox --new-tab <url>`).

## Budgets
- Every dispatch gets a budget and a timeout. Unattended runs: ask the scope and the budget first; merge what is invisible, gate what is visible, and keep working across the plan.
- Switch course on the second partial run of one task name instead of raising the budget.

## Releases
- Nothing goes public without `release-audit.md` passing and Patrick seeing the findings and approving.
- Cadence (2026-10-09): Crafting Guild goes public in a weekly batch, or once about five changes pile up; a fix for unsafe or wrong behaviour goes out right away. Between releases, VERSION and CHANGELOG.public.md hold the next version's entry.
- Credits the audit checks for this installation's projects: Open Peeps CC0, React Bits MIT + Commons Clause, Open-Meteo CC BY 4.0. Not redistributable: reference photos, BodyM (non-commercial). colorwright's `build-static.sh` is the example of a build that fails on a leak pattern.
- Policy decided 2026-09-28; which agent-readable material each release carries is settled with Patrick per release.
- Crafting Guild is published from this repository with `ws --project crafting-guild release` (`RELEASE_PATHS` in its conf); this file, `lessons/*.local.md`, `config.local.sh`, `plans/`, `projects/*.conf`, `reports/` and `CHANGELOG.md` stay here.
