# agentic-workspace v2: public release as Waystation Guild

**In flight right now**

**NOW (2026-10-09 10:09 MDT):** `ws-public-scrub` running (task-public-scrub.md, light, $8). Then: review, merge, Patrick reviews the findings list (release-audit.md section 5), create the public repo `rpbostick/waystation-guild` (name re-checked 2026-10-09: the exact phrase is unused; bare "Waystation" is crowded: waystation.ai / WayStation MCP, ythx-101/openclaw-qa "Agent Waystation"), `git remote add public`, `ws --project agentic-workspace-v2 release`.

## Decisions (Patrick, 2026-10-09)
- A new public repository; this one stays private as the working copy and research record, and publishes into the public one with `ws release` + `RELEASE_PATHS` (2.3.9).
- Name: Waystation Guild (settled 2026-09-10; Wayfarers Guild and Continuity Guild kept for future forks).
- Scrub here too: comments become plain technical reasons in this repository, one source.
- Lessons: generic public files plus private `.local.md` overlays with the dated incidents; operator preferences to `CLAUDE.local.md` and, where a script reads them, `config.sh`.
- A fresh public CHANGELOG; the private one keeps the journey.
- Start now (week's budget over 80% until 10/12; Patrick's OK for one light builder).
