# An orchestrator on OpenCode: AGENTS.md

Track: light

Crafting Guild's orchestrator is a Claude Code session in this folder, briefed by `CLAUDE.md` (the loop and rules), `CLAUDE.local.md` when present (the operator's private preferences, which win), the lessons files, and the cold-start hook in `.claude/settings.json` (runs `scripts/cold-start.sh` at session start). Make the same folder work as an orchestrator under OpenCode (opencode.ai, `opencode` in this folder), so the same `bin/ws` loop can be driven by OpenCode with a model such as `opencode-go/deepseek-v4.1-flash`. One toolkit: Claude Code keeps working exactly as now.

## What to build
1. **Read first** (web fetch these pages): opencode.ai/docs/rules (AGENTS.md, the `instructions` config key, and how OpenCode treats CLAUDE.md), opencode.ai/docs/config, opencode.ai/docs/commands, opencode.ai/docs/tools (the bash tool's timeout, the question tool), opencode.ai/docs/permissions, opencode.ai/docs/plugins. Write what you learned, with the URL for each point, in `docs/opencode-orchestrator.md`.
2. **`AGENTS.md`**: the orchestrator brief for OpenCode. Carry every section of `CLAUDE.md` (no project selected; the loop's eight steps; the rules; where things are) with the same meaning, and change only what depends on the agent:
   - Waiting: Claude Code runs `bin/ws wait` and `bin/ws chain` in the background and is woken when they end. Say what OpenCode does instead (a foreground `bin/ws wait` within the bash tool's timeout, in a loop of bounded waits, or whatever the docs show), with the numbers.
   - Questions to the operator: Claude Code's AskUserQuestion becomes OpenCode's question tool if the docs show one; otherwise a numbered list of options with the recommendation first.
   - Session start: what replaces the cold-start hook (a `/cold-start` command in `.opencode/command/`, a plugin, or an instruction to run `scripts/cold-start.sh` first; pick what the docs support and say why).
   - Anything else in CLAUDE.md that names a Claude Code feature.
   Do not copy CLAUDE.md's text where the meaning is unchanged and could drift: if OpenCode's `instructions` can load a file, prefer loading the shared parts over duplicating them, and say in `docs/opencode-orchestrator.md` how you avoided two copies drifting.
3. **`opencode.json`** at the repo root (OpenCode's project config): `instructions` loading `CLAUDE.local.md` (the private preferences, when it exists) and the lessons files `lessons/orchestrator.md` and `lessons/orchestrator.local.md`; `share` disabled; no model set (the operator chooses). If OpenCode errors on a missing instructions file, say so and handle it.
4. **A parity check in `scripts/selftest.sh`**: every `bin/ws <command>` that CLAUDE.md names is also named in AGENTS.md (or in a file AGENTS.md loads), so a command added to one brief and not the other fails the self-test.
5. Add `AGENTS.md`, `opencode.json` and `.opencode/` (if made) to `RELEASE_PATHS` guidance in `MODIFYING.md` (the conf itself is not yours to edit: say in the result which paths should be added), and one paragraph in `README.md`: running the orchestrator under OpenCode.

## Prior art
OpenCode's own AGENTS.md and project config (read in step 1); this repo's CLAUDE.md, `.claude/settings.json` and `scripts/cold-start.sh`.

## Commands
The project test command (the self-test) and syntax checks are already granted. Also: `jq *`, `python3 *`, `git add`, `git commit`, `grep *`, `mkdir *`. One command per Bash call. No installs.

Never start a real OpenCode or Claude session.

## Leave alone
`CLAUDE.md`, `CLAUDE.local.md`, `.claude/`, `plans/`, `projects/`, `lessons/`, `*.local.*`, `scripts/` except `selftest.sh`.

## Done when
- `docs/opencode-orchestrator.md` exists and every claim about OpenCode in it cites one of the step-1 pages.
- `AGENTS.md` covers each CLAUDE.md section; each Claude-Code-only mechanism is replaced by a named OpenCode one or by plain instructions, listed in `docs/opencode-orchestrator.md`.
- `opencode.json` is valid JSON and loads the private preferences and both lessons files.
- The parity check fails when a `bin/ws` command is removed from AGENTS.md (say in the result that you saw it fail), and `bash scripts/selftest.sh` passes in full.
