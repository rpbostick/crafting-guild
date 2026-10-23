# The orchestrator on OpenCode

Crafting Guild runs as an orchestrator under two clients: Claude Code reads `CLAUDE.md` and its SessionStart hook; OpenCode reads `AGENTS.md`, `opencode.json` and `/cold-start`. Both drive the same `bin/ws` loop. This page records what the OpenCode documentation says, which mechanism replaces each Claude Code one, and how the two briefs are kept from drifting.

Sources were read on 2026-10-22. Every statement about OpenCode below names the page it comes from.

## What the pages say

### Rules and AGENTS.md

- OpenCode reads `AGENTS.md` from the project root for instructions local to that directory ([docs/rules](https://opencode.ai/docs/rules/)).
- A project `AGENTS.md` can be committed and shared with a team; a global `~/.config/opencode/AGENTS.md` holds personal rules ([docs/rules](https://opencode.ai/docs/rules/)).
- `AGENTS.md` wins over `CLAUDE.md`: when both are present in a directory, only `AGENTS.md` is used; `CLAUDE.md` is a fallback for projects without one ([docs/rules](https://opencode.ai/docs/rules/)).
- The `instructions` key in `opencode.json` adds more files, paths, glob patterns or remote URLs to the same context, and all of them are combined with `AGENTS.md` ([docs/rules](https://opencode.ai/docs/rules/), [docs/config](https://opencode.ai/docs/config/)).
- Remote instruction URLs are fetched with a five-second timeout ([docs/rules](https://opencode.ai/docs/rules/)).

### Config

- Project config is `opencode.json` in the project root, in JSON or JSONC, and it is safe to commit ([docs/config](https://opencode.ai/docs/config/)).
- Config sources are merged; a project config overrides global and remote configs only for the keys it sets ([docs/config](https://opencode.ai/docs/config/)).
- `.opencode/` holds project-level `agents/`, `commands/`, `plugins/`, `skills/`, `tools/` and `themes/` ([docs/config](https://opencode.ai/docs/config/)).
- The `instructions` key takes an array of paths and glob patterns to instruction files ([docs/config](https://opencode.ai/docs/config/)).
- The published config schema defines `share` with `"manual"`, `"auto"` and `"disabled"` ([schema](https://opencode.ai/config.json)). The config page describes config validation against that schema ([docs/config](https://opencode.ai/docs/config/)).

### Commands

- A markdown file in `.opencode/commands/` becomes a slash command named after the file; YAML frontmatter supplies `description`, `agent` and `model` ([docs/commands](https://opencode.ai/docs/commands/)).
- A command template can inject the output of a shell command with `` !`command` ``; commands run in the project root and their output becomes part of the prompt ([docs/commands](https://opencode.ai/docs/commands/)).
- `$ARGUMENTS`, positional `$1`, `$2`, and `@file` references are the other prompt substitutions ([docs/commands](https://opencode.ai/docs/commands/)).

### Tools

- OpenCode's built-in shell tool executes commands in the project environment; permission is `shell` ([docs/tools](https://opencode.ai/docs/tools/)).
- The `question` tool asks the user during execution; each question has a header, text and a list of options, and the user can pick an option or type a custom answer; with several questions the user can move between them before submitting ([docs/tools](https://opencode.ai/docs/tools/)).
- The v2 copy of the tools page states that the shell tool has a two-minute default foreground timeout, that `timeout` is set in milliseconds when that is not suitable, and that `background: true` returns immediately and notifies the session when the call finishes ([v2/docs/tools](https://opencode.ai/v2/docs/tools)). The v1 tools page documents the shell tool without giving a timeout ([docs/tools](https://opencode.ai/docs/tools/)).
- The CLI page lists `OPENCODE_EXPERIMENTAL_BASH_DEFAULT_TIMEOUT_MS`, the default timeout for bash commands in milliseconds ([docs/cli](https://opencode.ai/docs/cli/)).
- The `question` tool's permission key is `question` ([docs/tools](https://opencode.ai/docs/tools/), [docs/permissions](https://opencode.ai/docs/permissions/)).

### Permissions

- Permission rules resolve to `allow`, `ask` or `deny` ([docs/permissions](https://opencode.ai/docs/permissions/)).
- Most permissions default to `allow`; `doom_loop` and `external_directory` default to `ask` ([docs/permissions](https://opencode.ai/docs/permissions/)).
- `external_directory` applies to any tool call that touches a path outside the working directory OpenCode was started in, including `read`, `edit`, `glob`, `grep` and many shell commands ([docs/permissions](https://opencode.ai/docs/permissions/)).
- Shell rules match the parsed command, so a pattern needs `*` to allow arguments (`"grep *"`, not `"grep"`) ([docs/permissions](https://opencode.ai/docs/permissions/)).

### Plugins

- Local plugins live in `.opencode/plugins/` or `~/.config/opencode/plugins/` and are JavaScript/TypeScript modules exporting hooks ([docs/plugins](https://opencode.ai/docs/plugins/)).
- The documented events include `session.created`, `session.idle`, `tool.execute.before`/`after` and `command.executed`; the list has no "session start, inject prompt context" hook, and the examples use events for notifications and guards, not for adding the session's opening context ([docs/plugins](https://opencode.ai/docs/plugins/)).

## What replaces what

| Claude Code mechanism | In OpenCode | Basis |
|---|---|---|
| `CLAUDE.md` as the orchestrator brief | `AGENTS.md` at the project root | `AGENTS.md` is the project instruction file and is preferred over `CLAUDE.md` when both exist ([docs/rules](https://opencode.ai/docs/rules/)) |
| `CLAUDE.local.md` and the lessons files loaded beside the brief | `instructions` in `opencode.json` names the private preferences and the two orchestrator lessons files | `instructions` combines extra files with `AGENTS.md` ([docs/rules](https://opencode.ai/docs/rules/), [docs/config](https://opencode.ai/docs/config/)) |
| The `SessionStart` hook in `.claude/settings.json` | `/cold-start`, a command file in `.opencode/commands/` whose template runs `` !`scripts/cold-start.sh --brief` `` | Commands inject shell output into the prompt and run in the project root ([docs/commands](https://opencode.ai/docs/commands/)); plugins expose events but no documented session-start context hook ([docs/plugins](https://opencode.ai/docs/plugins/)) |
| `AskUserQuestion` | the `question` tool, with a header, the question, labelled options and a free-text answer | `question` is documented with exactly those fields ([docs/tools](https://opencode.ai/docs/tools/)) |
| `run_in_background` with a `timeout` for `bin/ws wait` and `bin/ws chain` | a foreground shell call with an explicit `timeout` in milliseconds (2700000 for a light task, 7200000 otherwise), repeated in slices of at most 600000 ms if the client caps it; `background: true` plus its completion notification where the client has it | the default foreground timeout is two minutes; per-call `timeout` and `background` notification are documented ([v2/docs/tools](https://opencode.ai/v2/docs/tools)); the shell tool itself is [docs/tools](https://opencode.ai/docs/tools/) |
| `ws <slug>`, which starts Claude Code with `--add-dir` | start OpenCode in this folder with `WS_PROJECT=<slug>` in the environment, or let it follow `state/current`; the project tree is reached through `bin/ws`, or directly through an `external_directory` allow rule | a pinned session is an environment variable, not a Claude Code flag; `external_directory` covers paths outside the working directory and asks by default ([docs/permissions](https://opencode.ai/docs/permissions/)) |
| The Bash tool | the shell tool | the built-in tool is called `shell` ([docs/tools](https://opencode.ai/docs/tools/)) |
| Claude Code's status line (`scripts/statusline.sh`) | no equivalent in `AGENTS.md`; the setting stays in `.claude/settings.json` | no status-line mechanism is part of the OpenCode config or tools pages ([docs/config](https://opencode.ai/docs/config/), [docs/tools](https://opencode.ai/docs/tools/)) |

The one mapping with no OpenCode page behind it is the status line: it is a Claude Code display setting, not a step in the loop, so `AGENTS.md` does not mention it.

## How the two briefs are kept from drifting

`docs/rules` says OpenCode uses `AGENTS.md` instead of `CLAUDE.md` when both exist ([docs/rules](https://opencode.ai/docs/rules/)). Loading `CLAUDE.md` through `instructions` as well would put two versions of the loop in context, and the Claude Code version's wait step would contradict the OpenCode one. So `AGENTS.md` is a complete brief, not an overlay.

The parts that are identical for both clients are not copied: `opencode.json` loads `CLAUDE.local.md`, `lessons/orchestrator.md` and `lessons/orchestrator.local.md` by path ([docs/config](https://opencode.ai/docs/config/), [docs/rules](https://opencode.ai/docs/rules/)). One copy of those files serves both clients.

The part that can drift is the set of `bin/ws` commands named in the two briefs. `scripts/selftest.sh` extracts every `bin/ws <command>` from `CLAUDE.md` and fails when `AGENTS.md` does not name the same command. Adding a command to one brief and not the other is a red self-test.

## Not settled by the documentation

- The docs do not say what happens when an `instructions` path does not exist. Globs are accepted ([docs/config](https://opencode.ai/docs/config/)), which suggests a pattern that matches nothing is harmless, but that was not observed. `CLAUDE.local.md` and `lessons/orchestrator.local.md` are private and excluded from a public release, so a public tree either ships those files or removes their two entries from `opencode.json`.
- The v1 tools page the task points at documents the shell tool but gives no timeout ([docs/tools](https://opencode.ai/docs/tools/)); the two-minute figure comes from the v2 page ([v2/docs/tools](https://opencode.ai/v2/docs/tools)), and the CLI page confirms a configurable default exists ([docs/cli](https://opencode.ai/docs/cli/)). The installed OpenCode should be checked against the v1 page after an upgrade.
- `question`'s multi-select checkbox is not described on the v1 tools page; `AGENTS.md` therefore says to offer several applicable choices, and falls back to a numbered list when the tool cannot express that.
