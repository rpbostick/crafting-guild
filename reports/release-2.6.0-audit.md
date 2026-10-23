# Release audit: Crafting Guild 2.6.0 (dry run, 2026-10-22 22:55 MDT)

Not published. Waits for Patrick's approval.

## 1. Secrets and machine details: pass
- `ws release --dry-run`: 27 release paths, 55 files; 2397 lines added since the last public release (89418d9); no home paths, user name, e-mail, keys or attribution.
- The two new OpenCode log fixtures (`scripts/fixtures/opencode-sample.jsonl`, `opencode-denied.jsonl`): paths are /tmp/demo and /home/user, the account and organisation IDs are zeroed (a review caught them), session IDs are random and tied to nothing.
- `opencode.json` ships without a model (the model line OpenCode wrote moved to the user's own config).

## 2. Journey and personal text: one item to decide
- `docs/opencode-orchestrator.md:5`: "Sources were read on 2026-10-22." A citation date, not a decision; keep (it tells a reader how fresh the OpenCode facts are) or drop.
- No names, quotes or dated decisions in AGENTS.md, opencode.json, /cold-start, the launcher scripts or zdr-check. The tool's own vocabulary (builder, orchestrator, review) is its subject, as in earlier releases.

## 3. Licences: pass
No new third-party code or assets. OpenCode (MIT) is a tool the user installs, not shipped.

## 4. Built output: none (scripts only).

## 5. Agent-readable material in this release (to settle per release)
New: `AGENTS.md` (the orchestrator brief for OpenCode, parallel to CLAUDE.md), `.opencode/commands/cold-start.md`, `docs/opencode-orchestrator.md` (how each Claude Code mechanism maps to OpenCode, with sources). Recommendation: ship all three; they are how another team runs the tool under OpenCode.

## What 2.6.0 contains
See CHANGELOG.public.md: builders on OpenCode (--agent, permissions from grants, budget cap, result check), zdr-check, the orchestrator under OpenCode, bench arms by agent and model; plus the unreleased 2.5.4 items.
