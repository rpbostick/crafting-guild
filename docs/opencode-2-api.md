# OpenCode 2.x API map

The 1.x surface this workspace uses is in [opencode-orchestrator.md](opencode-orchestrator.md). This page maps each of
those mechanisms to OpenCode 2.x, names the source of each row, and lists the rows no source settles. It was written
against a throwaway 2.2.7 install and the 2.x documentation; the 1.x column is prior/known behaviour of 1.19.1.

Sources are the 2.x pages ([plugins](https://opencode.ai/docs/build/plugins/),
[plugin server](https://opencode.ai/docs/build/plugins/server/),
[plugin migration](https://opencode.ai/docs/build/plugins/migrate-v1/),
[plugin configuration](https://opencode.ai/docs/plugins/), [CLI](https://opencode.ai/docs/cli/),
[tools](https://opencode.ai/docs/tools/), [permissions](https://opencode.ai/docs/permissions/),
[migration](https://opencode.ai/docs/migrate-v1/), [skills](https://opencode.ai/docs/skills/),
[web search](https://opencode.ai/docs/websearch/), [MCP servers](https://opencode.ai/docs/mcp-servers/),
[web server](https://opencode.ai/docs/cli/web/), [troubleshooting](https://opencode.ai/docs/troubleshooting/),
[API reference](https://opencode.ai/docs/api)) and the installed 2.2.7 binary's strings and type definitions
(`@opencode/plugin` and `@opencode/protocol` 2.2.7).

## Summary

- The config, instruction, command, agent, skill, MCP and permission **file** surfaces still load. The server API,
  plugins and the CLI flags are the breaking changes ([migration](https://opencode.ai/docs/migrate-v1/)).
- The shell tool is `shell` and the permission action is `shell`; `bash`, `write` and `patch` are not V2 action names.
- Plugins default-export `{ id, setup | effect }`. The 1.x hook names and the 1.x `event(input, output)` shape do not
  load; the V2 hooks receive one mutable event and events arrive through `ctx.event.subscribe()`.
- The server moved from `/session`, `/message`, `/skill`, `/tool` to `/api/session`, `/api/session/:id/message`,
  `/api/skill`, `/api/tool`, `/api/event`, `/api/websearch` and so on. On 2.2.7 `POST /session` and `GET /skill`
  answer 405; `GET /tool` still serves the web UI HTML.
- `--pure`, `--attach` and `--variant` are gone. `--standalone`, `--server` (with `OPENCODE_PASSWORD`), and
  `-m provider/model#variant` replace them.
- A background service caches the config of its first start; a per-run `OPENCODE_CONFIG_CONTENT` is ignored until the
  service stops.

## One row per 1.x mechanism

`Resolved` means a 2.x page or type definition states the replacement. `Unresolved` means the row is named at the end.

| 1.x mechanism | 2.x surface | Source | Status |
|---|---|---|---|
| `AGENTS.md` as the project brief | unchanged; V2 discovers ambient `AGENTS.md` from the working directory up to home (and stops at a project root outside home) | [migration § Instruction files](https://opencode.ai/docs/migrate-v1/) | Resolved |
| `instructions` in `opencode.json` | unchanged key; the same files load | [migration § Configuration](https://opencode.ai/docs/migrate-v1/) | Resolved |
| Commands in `.opencode/commands/` | unchanged (`command/` and `commands/` both discovered); `subtask` becomes `subagent`, `variant` joins the model as `#variant` | [migration § Command files](https://opencode.ai/docs/migrate-v1/) | Resolved |
| Shell tool named `bash`, permission key `bash` | tool and permission action are `shell`; `write`/`patch` are `edit`, `task` is `subagent` | [tools § Shell](https://opencode.ai/docs/tools/), [migration § Permissions and tools](https://opencode.ai/docs/migrate-v1/) | Resolved |
| `question` tool | unchanged: header, question, labelled choices, `multiple`, free text | [tools § Question](https://opencode.ai/docs/tools/) | Resolved |
| Shell foreground timeout and background runs | `shell` has a two-minute foreground default, a millisecond `timeout`, and `background: true` with a completion notice; a background call has no timeout unless one is supplied | [tools § Shell](https://opencode.ai/docs/tools/) | Resolved |
| Permission effects `allow`/`ask`/`deny`, `external_directory`, shell globs | one ordered `permissions` array of `{ action, resource, effect }`; `external_directory` is **allowed** by default in V2 (V1 asked) | [permissions](https://opencode.ai/docs/permissions/), [migration § Permissions and tools](https://opencode.ai/docs/migrate-v1/) | Resolved |
| Local plugins in `.opencode/plugins/` exporting hook functions | a local directory or direct `.js`/`.ts` file that default-exports a `Plugin.define` definition `{ id, setup \| effect }`; `plugin` becomes `plugins`, and a tuple becomes `{ package, options }` | [plugins](https://opencode.ai/docs/build/plugins/), [plugin migration](https://opencode.ai/docs/build/plugins/migrate-v1/) | Resolved |
| `event(input, output)` plugin hook | `ctx.event.subscribe({ types, signal })`, an `AsyncIterable` of `{ type, data }`; abort it from `setup`'s cleanup | [plugin server § Events](https://opencode.ai/docs/build/plugins/server/) | Resolved |
| `tool.execute.before` / `tool.execute.after` | `ctx.tool.hook("execute.before" \| "execute.after", event)` with `event.tool`, `event.input`, and, after, `event.status`/`result`/`error` | [plugin migration § Register hooks](https://opencode.ai/docs/build/plugins/migrate-v1/), `@opencode/plugin` 2.2.7 `tool` type definitions (dist/promise/tool.d.ts) | Resolved |
| `permission.ask` hook and the `permission.asked`/`replied` event pair | `ctx.permission.hook("evaluate", event)` with a mutable `effect` and `message`; events `permission.asked` (`data.action`, `data.resources`, `data.metadata`, `data.id`) and `permission.replied` (`data.requestID`, `data.reply` one of `once`/`always`/`reject`) | [plugin server § Permissions](https://opencode.ai/docs/build/plugins/server/), `@opencode/protocol` 2.2.7 event type definitions (groups/event.d.ts) | Resolved |
| `experimental.chat.system.transform` (cold-start brief, memory) | `ctx.session.hook("context", event)` and push `{ type: "text", text }` onto `event.system`; register `compaction`, `generate` and `title` separately when every request kind needs it. Ported in `.opencode/plugins-2x/cold-start-2x.js`, which default-exports a plain `{ id, setup }` object (no package, so plain `node` imports it too); `scripts/cold-start-2x.test.mjs` calls its hooks against a fixture memory directory | [plugin migration § Request hooks](https://opencode.ai/docs/build/plugins/migrate-v1/), [plugin server § Model requests](https://opencode.ai/docs/build/plugins/server/), `@opencode/plugin` 2.2.7 `dist/promise/session.d.ts` (`SessionContext extends SessionRequest`: `readonly sessionID`, `system: Array<SystemPart>`; `SystemPart` is `{ type: "text", text }` in `@opencode/ai/dist/schema/messages.d.ts:7-13`) | Resolved |
| `experimental.session.compacting` | `ctx.session.hook("compaction", event)`; `event.messages` is the transcript and setting `event.result` supplies the summary. The hook adds text only through the inherited writable `event.system` (`SessionCompaction extends SessionContext`); `event.result` is a `SessionCompactionResult`, and its own type comment says setting it "use[s] this compaction and skip[s] the model request", so it replaces the summary rather than taking appended context. `cold-start-2x.js` pushes the brief and memory onto `event.system` and leaves `event.result` alone | [plugin migration](https://opencode.ai/docs/build/plugins/migrate-v1/), [plugin server § Model requests](https://opencode.ai/docs/build/plugins/server/), `@opencode/plugin` 2.2.7 `dist/promise/session.d.ts:40-50` | Resolved |
| `experimental.text.complete` (reply-time and reply-log plugins) | no V2 hook of that name; the `session.text.ended` event carries the completed text (`data.text`, plus `sessionID`, `assistantMessageID`, `ordinal`) but is not mutable. `reply-log-2x.js` saves the reply from that event; the visible banner has no hook and `reply-time` is retired on this line. `ctx.session.hook("context")` runs before a request, the wrong stage | [plugin migration § Migrate the context](https://opencode.ai/docs/build/plugins/migrate-v1/), `@opencode/protocol` 2.2.7 event type definitions (`session.text.ended`) | Resolved (read-only) |
| `AskUserQuestion` | the `question` tool, unchanged fields | [tools § Question](https://opencode.ai/docs/tools/) | Resolved |
| `run_in_background` and `TaskStop` for `ws wait`/`ws chain` | `ws bg` can stay as it is; a V2 shell call can also set `background: true`, but it returns a notice, not a tracked `runs/` record | [tools § Shell](https://opencode.ai/docs/tools/) | Resolved |
| `Monitor` | no V2 client monitor; `ws bg --watch` remains the mechanism | [tools](https://opencode.ai/docs/tools/) | Resolved |
| `Agent` background research subagent | `subagent` tool; it always runs in the background, returns a `sessionID`, and reports back when the child idles | [tools § Subagent](https://opencode.ai/docs/tools/) | Resolved |
| `ws <slug>` with `--add-dir` | `ws oc <slug>` remains; V2 allows `external_directory` by default, so a project outside the working directory is reachable without a rule | [permissions](https://opencode.ai/docs/permissions/) | Resolved |
| Session resume (`--resume`/`--continue`) and `opencode run --attach --session` | `opencode serve` owns sessions; a client resumes with `opencode run --server <url> --session <id>`. `--attach` does not exist | [CLI](https://opencode.ai/docs/cli/), [web server § Standalone](https://opencode.ai/docs/cli/web/) | Resolved |
| `OPENCODE_SERVER_PASSWORD`/`USERNAME` and the wake path | `OPENCODE_PASSWORD` is the password, the username is always `opencode`; `OPENCODE_SERVER_PASSWORD` still works and `OPENCODE_SERVER_USERNAME` does not | [migration § Server authentication](https://opencode.ai/docs/migrate-v1/), [web server § Authentication](https://opencode.ai/docs/cli/web/) | Resolved |
| `ws wake`/`ws bg --wake` sending `run --attach --session` | the same message path with `opencode run --server <url> --session <id> --format json -- <message>`; `OPENCODE_PASSWORD` must be in the sender's environment | [web server](https://opencode.ai/docs/cli/web/) | Resolved |
| `Bash` tool | `shell` | [tools § Shell](https://opencode.ai/docs/tools/) | Resolved |
| Claude Code status line | still no OpenCode equivalent | [config](https://opencode.ai/docs/config/) | Resolved (no equivalent) |
| Browser check through the `playwright` MCP server | MCP config still works but the entry moves under `mcp.servers`, `enabled` becomes `disabled`, and `timeout` becomes `{ catalog, execution }`; V2 also has a built-in desktop `browser` namespace | [MCP servers](https://opencode.ai/docs/mcp-servers/), [migration § MCP servers](https://opencode.ai/docs/migrate-v1/), [tools § Browser](https://opencode.ai/docs/tools/) | Resolved |
| Delegating one job to Claude (`ws claude`) | not an OpenCode feature; unchanged | `ws claude` | Resolved |
| Skills from `.opencode/skills/` and `GET /skill` | `.opencode/skills/<id>/SKILL.md` still loads; the list is `GET /api/skill` (the old `GET /skill` returns 405) | [skills](https://opencode.ai/docs/skills/), [API reference](https://opencode.ai/docs/api) | Resolved |
| Enforced JSON-schema output on `POST /session/:id/message` | **Checked against the 2.2.7 `openapi.json`:** no enforced free-form schema. `POST /api/session/{sessionID}/prompt` takes `text`, `files`, `agents`, `skills`, `metadata`, `delivery`, `resume` — no `format`/`schema` field; `POST /api/session/{sessionID}/generate` takes only `prompt`. What exists instead is `POST /api/experimental/generate/decisions` with `Generate.DecisionRequest` (`model`, `input`, `questions`), whose questions are typed predicate/choice/score with schema-validated answers | [API reference](https://opencode.ai/docs/api) and its [OpenAPI document](https://opencode.ai/docs/openapi.json) | **Resolved: no general schema; typed decisions only.** Builders stay on `opencode run` + `check-result` (with the repair turn); a *decision* (a verdict, a go/no-go, a score) could be enforced through `generate/decisions`, which is not wired into `ws` |
| Permission denials recorded by the `scripts/opencode-plugins/run-events.js` plugin | the same record can be built from `permission.asked`/`permission.replied` through `ctx.event.subscribe()`; `event.data` carries `action`, `resources`, `metadata`, `id`/`requestID`, `reply` | [plugin server § Events](https://opencode.ai/docs/build/plugins/server/), `@opencode/protocol` 2.2.7 event type definitions (groups/event.d.ts) | Resolved |
| Provider limits from `session.status` retries and `session.error` | `session.retry.scheduled` (`data.attempt`, `data.at`, `data.error.status/message/response.body/retryAfterMs`) and `session.execution.failed` (`data.error`); the record must map them to the names `opencode_run.py` reads | `@opencode/protocol` 2.2.7 event type definitions (groups/event.d.ts), [API reference schemas](https://opencode.ai/docs/api) | Resolved |
| `experimental.text.complete` reply plumbing (`reply-log`, `reply-time`) | `reply-log-2x.js` saves the reply on `session.text.ended`; `reply-time` is retired because the event is read-only and cannot gain the warning paragraph. Both 1.x plugins still fail to load on 2.2.7 and stay for the 1.x line | [plugin migration](https://opencode.ai/docs/build/plugins/migrate-v1/), `@opencode/protocol` 2.2.7 event type definitions | Resolved (reply log saved; banner and reply-time retired) |
| `ws review`'s choice of reviewer from the changed files | unchanged: it is a workspace launcher rule, not an OpenCode API; the review still passes a read-only config and a prompt | [CLI](https://opencode.ai/docs/cli/), `scripts/review.sh` | Resolved |
| The orchestrator's own config (`ws opencode-perms` writes it, `OPENCODE_CONFIG` loads it, the global config merges under it) | `OPENCODE_CONFIG` is still loaded after the global config and before the project config; the global file still merges under a builder's inline config; `permission` becomes `permissions` and the action names change to `shell`/`edit`/`subagent` | [config](https://opencode.ai/docs/config/), [migration § Permissions and tools](https://opencode.ai/docs/migrate-v1/), [plugin configuration § Configure](https://opencode.ai/docs/plugins/) | Resolved |
| `OPENCODE_EXPERIMENTAL_BASH_DEFAULT_TIMEOUT_MS` | the 2.x `shell` tool takes a millisecond `timeout` per call and `background: true` for a long call; the 1.x environment variable is not on the 2.x CLI page | [tools § Shell](https://opencode.ai/docs/tools/), [CLI](https://opencode.ai/docs/cli/) | Resolved |

## Plugin API details

The V2 definition and the hooks this workspace needs:

```js
import { Plugin } from "@opencode/plugin";

export default Plugin.define({
  id: "example",
  async setup(ctx) {
    await ctx.tool.hook("execute.before", (event) => {
      if (event.tool === "shell") console.log(event.input);
    });
    await ctx.session.hook("context", (event) => {
      event.system.push({ type: "text", text: "context" });
    });
    const controller = new AbortController();
    void (async () => {
      for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
        console.log(event.type, event.data);
      }
    })();
    return () => controller.abort();
  },
});
```

- A definition may be a plain `{ id, setup }` object, so a local plugin needs no `@opencode/plugin` dependency in the
  project. The workspace plugins call `Plugin.define` from `@opencode/plugin`; the 2.2.7 binary resolves that bare
  import itself, so `.opencode/package.json` does not need to carry the package. A plain `node` import of the same
  files does, so `scripts/opencode-2x-check.mjs` substitutes an identity stub for the bare specifier.
  `.opencode/plugins-2x/cold-start-2x.js` uses the plain object instead, so `scripts/cold-start-2x.test.mjs` imports it
  with plain `node` and no stub.
- Hook registrations are `await`ed and live for the plugin's lifetime; `setup` may return a cleanup function.
- The tool hook's event is a single mutable object (`tool`, `input`, `sessionID`, `agent`, `messageID`, `id`); a thrown
  error refuses the call.
- Events are `{ id, created, type, data }`; the field is `data`, not the 1.x `properties`.
- `session.compaction.started`, `.delta`, `.ended` and `.failed` are published events; the compaction *hook* is
  separate.
- The V2 loader accepts plugin directories and direct files under `.opencode/plugins/`; a configured path must be a
  directory. The 1.x file-URL plugin list (`file://.../run-events.js`) is rejected with
  `configured plugin path must be a directory`. So the workspace's `.opencode/plugins/` holds no plugin file, and
  each line's plugins sit beside it: `.opencode/plugins-2x/` (whose `index.js` composes both plugins, the one module
  the configured directory loads) for 2.x and `.opencode/plugins-1x/` for the 1.x file-URL list. `scripts/oc-config.test.mjs
  --live <opencode>` starts the installed CLI in a throwaway `XDG_*` prefix and shows its log loading the directory
  with no `failed to load plugin` line.
- The 2.x service writes `{ url, password, pid }` to `$XDG_STATE_HOME/opencode/service.json` with mode 0600. A client
  the service did not start needs that password: `scripts/oc-service-password.sh` prints it, and `scripts/wake.sh` and
  `ws oc` put it in `OPENCODE_PASSWORD` rather than on a command line.

## Server endpoints

The V2 API is generated ([API reference](https://opencode.ai/docs/api)); the paths below are the ones the 1.x parity
probes and the workspace use, with the 2.x replacement.

| 1.x endpoint | 2.x endpoint | Note |
|---|---|---|
| `POST /session` | `POST /api/session` | old path returns 405 on 2.2.7 |
| `POST /session/:id/message` | `POST /api/session/:sessionID/message` | structured-output request shape **unresolved** |
| `GET /session/:id/message` | `GET /api/session/:sessionID/message` | |
| `GET /skill` | `GET /api/skill` | old path returns no JSON on 2.2.7 |
| `GET /tool` | `GET /api/tool` | old path served the web UI HTML on 2.2.7 |
| event stream | `GET /api/event` | |
| webfetch | `POST /api/session/:sessionID/...` through the model's `webfetch` tool | the tool is still listed; the 1.x parity probe cannot post to `/session` |
| websearch | `POST /api/websearch` with `{query}`, `GET /api/websearch/provider` | the POST runs one search through the selected provider and answers 400 `websearch_provider_required` when none is configured; the model's `websearch` tool then cancels in a headless session, so search is relay-only until `websearch.provider` and its API key are set |
| browser MCP | unchanged MCP server; tools appear through `execute`/the desktop `browser` namespace | [tools § Browser](https://opencode.ai/docs/tools/) |
| `OPENCODE_SERVER_PASSWORD`, `OPENCODE_SERVER_USERNAME` | `OPENCODE_PASSWORD`, username always `opencode` | [migration](https://opencode.ai/docs/migrate-v1/) |
| `/api/info` | `GET /api/info` | the `curl -u opencode:<password>` example on [web server](https://opencode.ai/docs/cli/web/) |

The 405s were the V1 paths, not a missing server: `POST /session` and `GET /skill` return 405 because
V2 serves `/api/session` and `/api/skill`. `ws doctor --parity` and `scripts/opencode_run.py` call the path the
installed line serves (`api(line, …)` in `scripts/opencode_run.py` prefixes `/api` on 2.x), so their 2.x probes reach
the server. A 405 does not give one verdict: `schema_probe` reports it as `unsupported` with the status, while
`web_probe` reports `failed` for it and `skill_probe` maps only 404 to `not available`, so a 405 from `GET /api/skill`
reads `failed: GET /api/skill returned HTTP 405`.

## CLI flags

| 1.x | 2.x | Evidence |
|---|---|---|
| `opencode run --pure` | rejected: `Unrecognized flag: --pure`; V2 always loads the project's plugins and offers no pure switch | 2.2.7 `opencode run --help` |
| `opencode run --attach <url>` | `opencode --server <url>` or `opencode run --session` against the shared service | 2.2.7 `opencode run --help` |
| `opencode run --variant low` | `-m provider/model#low` (the variant is part of the model reference) | 2.2.7 `opencode run --help` |
| `opencode models <provider>` | rejected: `Unexpected positional argument`; `opencode models` lists all, and `models --verbose` is rejected | 2.2.7 `opencode models` |
| `opencode run` starts one process | starts or uses a shared background service; `--standalone` keeps it private; `opencode service start/restart/status/stop/get/set/unset` manages it | 2.2.7 `opencode service --help` and `opencode run --help` |
| `opencode serve --port` | unchanged (`serve` starts the foreground v2 API/web server) | 2.2.7 `opencode serve --help` |
| version text | `opencode v2.2.7` | 2.2.7 `opencode --version` |

## Config cache

2.2.7's background service loads the config of its first start and keeps it. A second `OPENCODE_CONFIG_CONTENT` is
ignored while the service lives; stopping the service makes the next start read it.

```
first start      OPENCODE_CONFIG_CONTENT instructions: probe-a -> debug config: probe-a
second start     OPENCODE_CONFIG_CONTENT instructions: probe-b -> debug config: probe-a  (service still up)
service stop
third start      OPENCODE_CONFIG_CONTENT instructions: probe-b -> debug config: probe-b
```

A 2.x runner therefore cannot pass per-run config through `OPENCODE_CONFIG_CONTENT` unless it uses `--standalone`,
restarts the service per run, or finds a per-session config path. A builder's inline config behaves the same way.

## Database path and migration

- `opencode debug paths db` prints the database and does not open it; `OPENCODE_DB` overrides the location, and a
  relative override resolves under the data directory ([CLI § Paths](https://opencode.ai/docs/cli/)). The normal path
  is `~/.local/share/opencode/opencode.db` ([troubleshooting § Service files](https://opencode.ai/docs/troubleshooting/)).
  With the `XDG_*` variables set to a throwaway prefix, it prints the database under that data home.
- V2 has a V1-to-V2 **session history migration**: `GET /api/experimental/migration/v1` is "Get V1 migration status:
  return the progress of the V1 to V2 session history migration" ([API reference § Migration](https://opencode.ai/docs/api)).
- **Unresolved:** no page states that the migration is one-way, or which client can read the database after it. The
  endpoint's name and the 2.x database path are the only sources, and the migration has not been measured on a copy:
  a database's mtime cannot distinguish a 2.x write from a 1.x session. Treat a 2.x start on the real data directory
  as a one-way step until it is measured on a copy.

## Unresolved rows

1. **The reply hook's visible effects.** `experimental.text.complete` is absent from 2.2.7. `session.text.ended`
   carries the completed text but is read-only: the reply log saves the reply without the local-time banner, and the
   reply-time warning has no place to go, so that plugin is retired on the 2.x line. Porting the banner or the
   warning needs a mutable end-of-reply hook that 2.2.7 does not expose.
2. **Structured JSON-schema output.** The 2.x API page documents `POST /api/session/:sessionID/message` but not the
   `format: { type: "json_schema" }` field the 1.x server enforces through `StructuredOutput`. The 1.x path returns
   405. Whether 2.x enforces a schema, and with which retry field, is unprobed.
3. **Database migration direction.** The V1 migration endpoint exists; "one-way" is not stated by a page, and no
   old-schema copy was loaded.
4. **The `opencode auth list` format.** Resolved in `scripts/doctor.sh`: the credential check accepts the 1.x `●`
   marker and the 2.x table's `stored` row (`OpenCode Go  API key … stored`), and still fails on an empty list.
5. **Which projects a nested worktree inherits.** 2.2.7 read both the main checkout's `opencode.json`/`.opencode` and
   the worktree's when run inside a worktree. The discovery rule for parents above the
   git root is not stated on a page.
