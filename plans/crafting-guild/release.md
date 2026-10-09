# agentic-workspace v2: public release as Crafting Guild Agentic Workspace

**In flight right now**

**REPOSITORIES (2026-10-09, Patrick):** the private repo is renamed `rpbostick/crafting-guild-dev` (was agentic-workspace-v2; GitHub redirects the old name; remote `origin` updated; the local folder keeps its name). Public releases go to `rpbostick/crafting-guild` (remote `public`). v1, `rpbostick/agentic-workspace`, is archived read-only for learning, after a final commit of its last uncommitted memory and proposal files (0d54c4c).

**STABLE PUBLIC VERSION (2026-10-09 16:08 MDT, Patrick):** the public crafting-guild is the stable version; work happens here and is published by audited releases. Every release since 2.5.0 has a GitHub release page (2.3.9 to 2.4.2 backfilled), a private tag `released-vX.Y.Z` on the commit published (backfilled by matching the public files), and moves the public branch `v2` (RELEASE_MAJOR_BRANCHES=1). Users install any exact version (`--branch v2.4.1`) or the newest 2.x (`--branch v2`). To return to the last stable version after a bad direction: `ws --project crafting-guild rollback --dry-run vX.Y.Z`, then without --dry-run (one new commit; plans, confs and .local files untouched; revert it to undo); the next release needs a version above the newest public one. Locked (2026-10-09, Patrick): GitHub rulesets on crafting-guild. "Stable branches" (24818336): main and v* branches cannot be force-pushed or deleted. "Release tags" (24818337): v* tags cannot be moved or deleted, only created. No bypass, owner included; tested: moving v2.3.9 was refused (GH013). Releases still work (fast-forward pushes and new tags). A mistake on the public side is fixed forward with a new release, never by rewriting it.

**DONE (2026-10-09 11:00 MDT):** Crafting Guild Agentic Workspace v2.3.9 is public at github.com/rpbostick/crafting-guild (one fresh commit 7a9b07c, tag v2.3.9, 36 files; a fresh clone passes its selftest). Scrub merged 0a08c9e ($3.80 + $1.15 fix round, reviews $0.75 + $0.73). Patrick read the README and approved; copyright "Robert Patrick Bostick". Later releases: bump VERSION, add a CHANGELOG.public.md entry, `ws --project crafting-guild release --no-asset` (`--no-asset`: the workspace's own scripts/release.sh is `ws release`, not a build). Private stays private: plans/, projects/*.conf, runs/, reports/, *.local.md, config.local.sh, CHANGELOG.md (release.sh refuses any *.local.* in the public tree).

## Decisions (Patrick, 2026-10-09)
- A new public repository; this one stays private as the working copy and research record, and publishes into the public one with `ws release` + `RELEASE_PATHS` (2.3.9).
- Name: **Crafting Guild** (2026-10-09; Patrick's own idea from 2026-09-10). Waystation Guild, settled 2026-09-10, dropped: "Waystation" is crowded by AI-agent products (waystation.ai / WayStation MCP, ythx-101/openclaw-qa "Agent Waystation").
- Scrub here too: comments become plain technical reasons in this repository, one source.
- Lessons: generic public files plus private `.local.md` overlays with the dated incidents; operator preferences to `CLAUDE.local.md` and, where a script reads them, `config.sh`.
- A fresh public CHANGELOG; the private one keeps the journey.
- Start now (week's budget over 80% until 10/12; Patrick's OK for one light builder).
