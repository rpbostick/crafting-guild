# agentic-workspace v2: public release as Crafting Guild Agentic Workspace

**In flight right now**

**DONE (2026-10-09 11:00 MDT):** Crafting Guild Agentic Workspace v2.3.9 is public at github.com/rpbostick/crafting-guild (one fresh commit 7a9b07c, tag v2.3.9, 36 files; a fresh clone passes its selftest). Scrub merged 0a08c9e ($3.80 + $1.15 fix round, reviews $0.75 + $0.73). Patrick read the README and approved; copyright "Robert Patrick Bostick". Later releases: bump VERSION, add a CHANGELOG.public.md entry, `ws --project agentic-workspace-v2 release --no-asset` (`--no-asset`: the workspace's own scripts/release.sh is `ws release`, not a build). Private stays private: plans/, projects/*.conf, runs/, reports/, *.local.md, config.local.sh, CHANGELOG.md (release.sh refuses any *.local.* in the public tree).

## Decisions (Patrick, 2026-10-09)
- A new public repository; this one stays private as the working copy and research record, and publishes into the public one with `ws release` + `RELEASE_PATHS` (2.3.9).
- Name: **Crafting Guild** (2026-10-09; Patrick's own idea from 2026-09-10). Waystation Guild, settled 2026-09-10, dropped: "Waystation" is crowded by AI-agent products (waystation.ai / WayStation MCP, ythx-101/openclaw-qa "Agent Waystation").
- Scrub here too: comments become plain technical reasons in this repository, one source.
- Lessons: generic public files plus private `.local.md` overlays with the dated incidents; operator preferences to `CLAUDE.local.md` and, where a script reads them, `config.sh`.
- A fresh public CHANGELOG; the private one keeps the journey.
- Start now (week's budget over 80% until 10/12; Patrick's OK for one light builder).
