# agentic-workspace v2: public release as Waystation Guild

**In flight right now**

**NOW (2026-10-09 10:28 MDT):** name changed to **Crafting Guild** (Patrick: Waystation overlaps too much). `ws-public-scrub` first round done ($3.80; review fix-first $0.75: MODIFYING.md file-map rows run together); fix round running (task-public-scrub-fix.md, $4) with the rename. Then: review, merge, findings list to Patrick (release-audit.md section 5), create `rpbostick/crafting-guild` (free on 2026-10-09; 9 GitHub repos named crafting guild, none AI; web noise is game guilds and the UK chefs' Craft Guild app), `git remote add public`, `ws --project agentic-workspace-v2 release`.

## Decisions (Patrick, 2026-10-09)
- A new public repository; this one stays private as the working copy and research record, and publishes into the public one with `ws release` + `RELEASE_PATHS` (2.3.9).
- Name: **Crafting Guild** (2026-10-09; Patrick's own idea from 2026-09-10). Waystation Guild, settled 2026-09-10, dropped: "Waystation" is crowded by AI-agent products (waystation.ai / WayStation MCP, ythx-101/openclaw-qa "Agent Waystation").
- Scrub here too: comments become plain technical reasons in this repository, one source.
- Lessons: generic public files plus private `.local.md` overlays with the dated incidents; operator preferences to `CLAUDE.local.md` and, where a script reads them, `config.sh`.
- A fresh public CHANGELOG; the private one keeps the journey.
- Start now (week's budget over 80% until 10/12; Patrick's OK for one light builder).
