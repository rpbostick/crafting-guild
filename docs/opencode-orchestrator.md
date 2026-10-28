# The orchestrator on OpenCode

Crafting Guild runs as an orchestrator under two clients: Claude Code reads `CLAUDE.md` and its SessionStart hook; OpenCode reads `AGENTS.md`, `opencode.json`, the cold-start plugin and `/cold-start`. Both drive the same `bin/ws` loop. This page records what the OpenCode documentation says, which mechanism replaces each Claude Code one, and how the two briefs are kept from drifting.

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
- `OPENCODE_CONFIG` names a custom config file, loaded after the global config and before the project config ([docs/config](https://opencode.ai/docs/config/)).
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
- The documented events include `session.created`, `session.idle`, `tool.execute.before`/`after` and `command.executed`; the plugins page's list has no "session start, inject prompt context" hook, and the examples use events for notifications and guards, not for adding the session's opening context ([docs/plugins](https://opencode.ai/docs/plugins/)).
- `@opencode-ai/plugin`'s `index.d.ts` declares an undocumented, experimental `experimental.chat.system.transform` hook, called with `{sessionID, model}` and an appendable `output.system: string[]`; OpenCode 1.19.1 calls it for each model request and puts the appended text in the system prompt.

`.opencode/plugins/cold-start.js` closes the session-start gap. The hook runs `scripts/cold-start.sh --brief` once per session id, inheriting the session's environment so `WS_PROJECT` pinning still holds, caches the output and appends it to the system prompt behind a one-line header on every request; a failing or 20 s script appends a one-line note instead and the session continues. `/cold-start` remains the on-demand refresh mid-session. Because the hook is experimental and absent from the plugins page, an OpenCode upgrade has to re-check it. OpenCode discovers `.opencode/plugins` from the working directory, so reviews run `opencode run --pure` ("run without external plugins"). A builder cannot use `--pure`: the flag clears every plugin origin, including the run-events plugin its inline config names (the 1.19.1 binary's server plugin loader takes `plugin_origins` only when `OPENCODE_PURE` is unset). The builder names that plugin through `OPENCODE_CONFIG_CONTENT`, and the cold-start plugin returns early when `WS_RUN_EVENTS` is set, so a builder still never receives the brief.

## What replaces what

| Claude Code mechanism | In OpenCode | Basis |
|---|---|---|
| `CLAUDE.md` as the orchestrator brief | `AGENTS.md` at the project root | `AGENTS.md` is the project instruction file and is preferred over `CLAUDE.md` when both exist ([docs/rules](https://opencode.ai/docs/rules/)) |
| `CLAUDE.local.md` and the lessons files loaded beside the brief | `instructions` in `opencode.json` names the private preferences and the two orchestrator lessons files | `instructions` combines extra files with `AGENTS.md` ([docs/rules](https://opencode.ai/docs/rules/), [docs/config](https://opencode.ai/docs/config/)) |
| The `SessionStart` hook in `.claude/settings.json` | `.opencode/plugins/cold-start.js` appends `scripts/cold-start.sh --brief` to the system prompt once per session; `/cold-start` in `.opencode/commands/` remains the mid-session refresh | OpenCode 1.19.1 calls the experimental `experimental.chat.system.transform` hook with the session id and an appendable `system` array (`@opencode-ai/plugin` `index.d.ts`); the plugins page does not document it, and the plugin was observed appending the brief on 1.19.1 |
| `AskUserQuestion` | the `question` tool, with a header, the question, labelled options and a free-text answer | `question` is documented with exactly those fields ([docs/tools](https://opencode.ai/docs/tools/)) |
| `run_in_background` with a `timeout` for `bin/ws wait` and `bin/ws chain` | a foreground shell call with an explicit `timeout` in milliseconds (2700000 for a light task, 7200000 otherwise), repeated in slices of at most 600000 ms if the client caps it; `background: true` plus its completion notification where the client has it | the default foreground timeout is two minutes; per-call `timeout` and `background` notification are documented ([v2/docs/tools](https://opencode.ai/v2/docs/tools)); the shell tool itself is [docs/tools](https://opencode.ai/docs/tools/) |
| `ws <slug>`, which starts Claude Code with `--add-dir` | `ws oc <slug>` starts OpenCode here, pinned with `WS_PROJECT` and loading the orchestrator config (or leave both out to follow `state/current`); the project tree is reached through `bin/ws`, or directly through an `external_directory` allow rule | a pinned session is an environment variable, not a Claude Code flag; `external_directory` covers paths outside the working directory and asks by default ([docs/permissions](https://opencode.ai/docs/permissions/)) |
| The Bash tool | the shell tool | the built-in tool is called `shell` ([docs/tools](https://opencode.ai/docs/tools/)) |
| Claude Code's status line (`scripts/statusline.sh`) | no equivalent in `AGENTS.md`; the setting stays in `.claude/settings.json` | no status-line mechanism is part of the OpenCode config or tools pages ([docs/config](https://opencode.ai/docs/config/), [docs/tools](https://opencode.ai/docs/tools/)) |
| Delegating one job to Claude | `ws claude` runs `claude -p` with the repo's budget, read-only tools and optional JSON schema, no worktree; a usage limit exits 3, a model error or a missing structured result exits 1 | not an OpenCode feature: it keeps Claude reachable from a DeepSeek-driven session for the capabilities OpenCode does not enforce (see `plans/crafting-guild/agent-sdk-parity.md`) |
| Enforced JSON-schema output (`claude -p --json-schema`, `ws claude --schema`) | the server's `format: {"type":"json_schema","schema":…,"retryCount":2}` on `POST /session/:id/message`, enforced through a StructuredOutput tool; `opencode run` does not expose it | `ws doctor --parity` starts a temporary server and probes the configured model. OpenCode 1.19.1 with `opencode-go/deepseek-v4.1-flash` reported `failed: StructuredOutputError: Model did not produce structured output (retries 0)`, so builders stay on `opencode run` and `check-result` checks the branch ([docs/server](https://opencode.ai/docs/server), [docs/sdk](https://opencode.ai/docs/sdk)) |
| Permission denials in a builder run | `scripts/opencode-plugins/run-events.js` records `permission.ask`, `permission.asked` and `permission.replied` to `runs/<slug>/<name>.events.jsonl`; `scripts/check-result.sh` merges them with the tool errors already parsed from the run log, so a denied call is listed as it is for Claude runs | `@opencode-ai/plugin` `index.d.ts` declares the `permission.ask` hook and the SDK v2 event types declare `permission.asked`/`permission.replied`; the plugin is plain ESM, imported by the selftest |
| A builder run stopped by a provider limit | the same plugin records `session.status` retries with `next` and the message, and `session.error` with the API error's status and response headers; `scripts/check-result.sh` prints `LIMIT` and `reset_epoch` from the last retry or error, so `ws chain` waits and resumes | `SessionStatus{type:"retry",attempt,message,next}` and `APIError.responseHeaders` in `@opencode-ai/sdk`; the 1.19.1 server retry policy honours `retry-after`/`retry-after-ms` and caps at 2147483647 ms; a real OpenCode Go limit has not been captured |

The one mapping with no OpenCode page behind it is the status line: it is a Claude Code display setting, not a step in the loop, so `AGENTS.md` does not mention it.

## The orchestrator's own config

`ws opencode-perms` writes the registered project paths and the shell rules to `~/.config/opencode/orchestrator.json`, not to the global `opencode.json`. Config sources are merged ([docs/config](https://opencode.ai/docs/config/)), so a rule in the global file also sits under the inline permissions a builder or review passes: its `bash` rules combine, and an `ask` left there waits on a prompt a headless run cannot answer, leaving it without a shell. The orchestrator loads the file as its custom config. The launcher does both in one command:

```
ws oc <slug>
```

It sets `WS_PROJECT` and `OPENCODE_CONFIG` and starts OpenCode in the workspace; it does not move `state/current`, so a second session stays on its own project. `ws oc <slug> --print` shows the underlying command.

`OPENCODE_CONFIG` is loaded after the global config and before the project config ([docs/config](https://opencode.ai/docs/config/)), so the orchestrator session still inherits the global providers, models and other keys. The builder and review launchers unset `OPENCODE_CONFIG`, so the orchestrator's rules reach only the orchestrator session; the global config is left to both. The command refuses to write a global `opencode.json` and prints the launch line after writing.

## How the two briefs are kept from drifting

`docs/rules` says OpenCode uses `AGENTS.md` instead of `CLAUDE.md` when both exist ([docs/rules](https://opencode.ai/docs/rules/)). Loading `CLAUDE.md` through `instructions` as well would put two versions of the loop in context, and the Claude Code version's wait step would contradict the OpenCode one. So `AGENTS.md` is a complete brief, not an overlay.

The parts that are identical for both clients are not copied: `opencode.json` loads `CLAUDE.local.md`, `lessons/orchestrator.md` and `lessons/orchestrator.local.md` by path ([docs/config](https://opencode.ai/docs/config/), [docs/rules](https://opencode.ai/docs/rules/)). One copy of those files serves both clients.

The part that can drift is the set of `bin/ws` commands named in the two briefs. `scripts/selftest.sh` extracts every `bin/ws <command>` from `CLAUDE.md` and fails when `AGENTS.md` does not name the same command. Adding a command to one brief and not the other is a red self-test.

## Delegation and the parity probe

Two commands keep a Claude-only capability reachable and tested from an OpenCode/DeepSeek session:

- `ws claude [--budget USD] [--schema file] [--dir path] [--allow <tool>] [--raw] <prompt-file|->` runs one Claude Code job in the current directory with `--output-format json`, `--max-budget-usd`, `--permission-prompts none`, read-only tools (`Read,Grep,Glob`) plus any `--allow`, and the optional `--json-schema`. It signs in checks first (`claude auth status`), never creates a worktree or a branch, prints the JSON result (or the reply text with `--raw`, cost on stderr), and exits 3 on a usage limit, 1 on a model error or a reply without a structured result. `WS_CLAUDE_BUDGET` (config.sh, defaults to `WS_REVIEW_BUDGET`) is the budget.
- `ws doctor --parity` runs one tiny structured-output job per agent (opt-in, paid). It reports whether Claude's `--json-schema` is enforced. For OpenCode it starts a temporary `opencode serve` on `127.0.0.1` with a random password, posts one prompt with `format: {"type":"json_schema","schema":…,"retryCount":2}`, and reports `enforced`, `failed: …` (including `StructuredOutputError`) or `unsupported: …` from the reply; the server is stopped in a trap and its session deleted. The server enforces the schema through a StructuredOutput tool, not the provider's JSON mode, and `opencode run` cannot request it. Those results are the decision point for moving builders to the server path.

Tested with OpenCode 1.19.1: `scripts/selftest.sh` proves `ws claude`'s flags, schema refusal, raw output and limit exit with a stand-in; `ws doctor --parity` reports Claude's enforced schema and, against a stand-in HTTP server, OpenCode's `enforced` reply and its `StructuredOutputError`, and no server outlives either run; a real Claude 429 was reported as a usage limit, not a probe failure. `ws doctor` also checks the Claude sign-in and OpenCode's presence and credential, because reviews and delegation need the first and the default builders need the second.

Tested with OpenCode 1.19.1: a real `ws doctor --parity` on OpenCode 1.19.1 with `opencode-go/deepseek-v4.1-flash` reported `failed: StructuredOutputError: Model did not produce structured output (retries 0)`. The server's forced schema is not usable with this model, so builders stay on `opencode run` and `check-result` checks the branch; a non-thinking variant or another model has not been tried.

Tested with OpenCode 1.19.1: the selftest imports `scripts/opencode-plugins/run-events.js` with `node`, feeds stand-in permission, retry and 429 events, and checks `check-result`'s denial, recovered-retry and limit outcomes; the OpenCode stand-in dispatch shows the builder's inline config carrying the plugin.

## Not settled by the documentation

- The docs do not say what happens when an `instructions` path does not exist. Globs are accepted ([docs/config](https://opencode.ai/docs/config/)), which suggests a pattern that matches nothing is harmless, but that was not observed. `CLAUDE.local.md` and `lessons/orchestrator.local.md` are private and excluded from a public release, so a public tree either ships those files or removes their two entries from `opencode.json`.
- The v1 tools page documents the shell tool but gives no timeout ([docs/tools](https://opencode.ai/docs/tools/)); the two-minute figure comes from the v2 page ([v2/docs/tools](https://opencode.ai/v2/docs/tools)), and the CLI page confirms a configurable default exists ([docs/cli](https://opencode.ai/docs/cli/)). The installed OpenCode should be checked against the v1 page after an upgrade.
- `question`'s multi-select checkbox is not described on the v1 tools page; `AGENTS.md` therefore says to offer several applicable choices, and falls back to a numbered list when the tool cannot express that.
- OpenCode Go's quota response has not been captured. The 1.19.1 server recognises `GoUsageLimitError` in a provider response body, takes the wait from `retry-after`, and publishes a `SessionStatus` retry with `next` and `action.reason: "account_rate_limit"`; the run-events file will hold the real shape at the first limit. Until then `check-result`'s reset path is tested against those stand-in events, not a real 429.
