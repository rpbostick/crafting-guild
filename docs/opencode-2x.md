# OpenCode 2.x instructions

Read this when `WS_OPENCODE_LINE=2`, which `opencode --version` reports as `opencode v2.x`. The 1.x line is
[opencode-1x.md](opencode-1x.md); the sources and unresolved rows are in [opencode-2-api.md](opencode-2-api.md).

## Shell

- The tool and its permission action are `shell`; `bash`, `write` and `patch` are not V2 action names (`edit` and
  `subagent` replace them). A deny rule names `action: "shell"`.
- A foreground call defaults to two minutes; `timeout` is milliseconds, and `background: true` has no timeout unless one
  is set.
- A 2.x builder's deny guard is `scripts/opencode-plugins-2x/deny-guard.js`; it checks `event.tool` against `shell`
  (and the 1.x spelling) and reads `event.input.command`.

## Flags

- `opencode run --format json` keeps the `step_start`, `text` and `step_finish` shapes.
- There is no `--pure`, `--attach` or `--variant`. A private server is `--standalone`; a client attaches with
  `--server <url>` (Basic auth `opencode:<OPENCODE_PASSWORD>`), and a variant is `-m provider/model#variant`.
- `opencode models` lists every model; it takes no provider argument and has no `--verbose`.
- A default `opencode run` uses a shared background service. The service caches the config of its first start, so a
  per-run `OPENCODE_CONFIG_CONTENT` is ignored until the service stops or the run uses `--standalone`.

## Plugins

- A plugin default-exports a V2 definition with a stable `id` and `setup(ctx)` (or an Effect `effect`); it registers
  hooks through the context and returns a cleanup function. The workspace plugins call `Plugin.define` from
  `@opencode/plugin`; the 2.2.7 binary resolves that bare import itself, so `.opencode/package.json` does not need to
  list the package (a direct `node` import of the same files does, which is why the check substitutes an identity stub).
- Hooks in use: `ctx.tool.hook("execute.before", event)` with `event.tool`/`event.input`;
  `ctx.session.hook("context", event)` and push `{ type: "text", text }` onto `event.system`;
  `ctx.session.hook("compaction", event)`; `ctx.permission.hook("evaluate", event)`.
- Events arrive through `ctx.event.subscribe({ types, signal })` as `{ id, created, type, data }`. The names are
  `permission.asked`, `permission.replied`, `session.retry.scheduled`, `session.execution.failed`,
  `session.tool.called`, `session.tool.success`, `session.tool.failed`, `session.compaction.started`,
  `session.compaction.delta`, `session.compaction.ended`, `session.compaction.failed`.
- The config key is `plugins`. V2 discovers plugin files and package directories under `.opencode/plugins/`, and
  config documents, from the starting directory upward, including a worktree's and its parent checkout's; there is no
  switch to turn discovery off. A configured entry must be a directory, which V2 loads as one module (its `index.js`):
  a loose `.js` file or a `file://` URL is not loaded. The workspace's builder plugins are the package
  `scripts/opencode-plugins-2x/`, whose `index.js` composes the deny guard and run-events so one directory supplies
  both; a builder names it absolutely in its config, so it loads in every project worktree. The orchestrator's plugins
  are `.opencode/plugins-2x/`, whose `index.js` composes `cold-start-2x.js` and `reply-log-2x.js`; `ws oc` names that
  directory in `runs/<slug>/oc.config.json`, and `.opencode/plugins/` holds no plugin file, so discovery on either line
  finds nothing to reject.
- The reply log is `.opencode/plugins-2x/reply-log-2x.js`: `session.text.ended` carries `data.text` (with `sessionID`,
  `assistantMessageID` and `ordinal`) but the event is read-only, so it saves the reply and its dated entry and cannot
  add the `━━ HH:MM ━━` banner. The reply-time check is retired on this line: no hook can append its warning to the
  visible reply, so the warning is not shown inline (`scripts/reply-time-check.sh` still runs on demand).
- A 2.x builder's event record is `scripts/opencode-plugins-2x/run-events.js`; it maps the `data` payloads onto the
  field names `scripts/opencode_run.py` and `scripts/check-result.sh` read.

## Launchers

- `ws oc` on 2.x has no TUI port flag. It sets the background service's port, restarts the service so it reads the
  per-session config, then starts the TUI against that service:
  `opencode service set port <p>`, `opencode service restart`, `opencode`. The 2.2.7 `service --help` lists
  `start`, `restart`, `status`, `stop`, `get`, `set` and `unset`; `service set --help` takes a `<key> <value>` and a
  throwaway `opencode service set port <p>` writes `port`, which `opencode service get` reports. The per-session config
  (`runs/<slug>/oc.config.json`) adds `lessons/opencode-2.md` to the project's instruction list, so a 2.x session is
  briefed with the `shell`/`--standalone` surface.
- There is only one background service per user, so only one 2.x session runs at a time. A second `ws oc` sets the
  service's port and restarts it with its own config; the first session's `runs/<slug>/oc.port` then no longer matches
  the service, and its TUI is attached to a service now configured for another project, while a wake armed without
  `--url` or `WS_WAKE_URL` resolves the service's own url again when it fires, so it reaches the service.
- A builder and a review run with `--standalone`, so `OPENCODE_CONFIG_CONTENT` is read afresh instead of the
  background service's cached first config. Both name the workspace's `scripts/opencode-plugins-2x` package in
  `plugins`, so the deny guard and run-events load even in a project worktree with no `.opencode/plugins`; a builder's
  `--effort` becomes `-m provider/model#variant`.
- A review has no `--pure`, and V2 would load the branch's own `.opencode/plugins` and `opencode.json` if the review
  started in its worktree. A 2.x review therefore runs from the workspace: only the workspace's plugins and config
  load, the read-only config grants `external_directory` for the branch's worktree, and the prompt gives the branch's
  files by absolute path. It sets `WS_RUN_EVENTS` to its own event file, which makes the reply-log plugin return early
  and gives run-events a place to write; its config still denies every writing tool.
- A wake sends `opencode run --server <url> --session <id> --format json -- <message>` with `OPENCODE_PASSWORD` in
  the environment. `OPENCODE_SERVER_PASSWORD` is also accepted and forwarded, so a wake configured with the name the
  help and the 1.x path use still authenticates on 2.x. The username is always `opencode`; `OPENCODE_SERVER_USERNAME`
  is ignored. The service writes its password to `$XDG_STATE_HOME/opencode/service.json` (mode 0600); when neither
  variable is set, `scripts/wake.sh` reads it there (`scripts/oc-service-password.sh`) and `ws oc` exports it for the
  session it starts. The value stays in the environment: a transient unit gets `--setenv=NAME`, a recurring one a
  0600 `EnvironmentFile` under `runs/<slug>/wake/`. A watchdog's unit carries the same copy in
  `runs/<slug>/chain-watch.env` (mode 0600, `WS_WAKE_FALLBACK_PASSWORD`) only as a fallback: its wake is scheduled
  when the timer fires and reads the password from the state file then, so a value that changed is not shadowed by
  the copy the arm wrote. `--disarm` and a finished chain delete the file, and the 1.x line has no such file to read.
  On 2.2.7 a restart does not regenerate the password: in a throwaway `XDG_*` prefix it held the same value (same
  sha256, first and last characters and length; only `pid` changed) after a fresh start, two restarts, a stop and a
  start, and a deleted `service.json`, so an arm-time copy stays current and the fallback is not reached in normal
  use.

## Server

- The API is under `/api`: `POST /api/session`, `POST /api/session/:sessionID/message`, `GET /api/skill`, `GET /api/tool`,
  `GET /api/event`, `POST /api/websearch`. On 2.2.7 `POST /session` and `GET /skill` answer 405; `GET /tool` still
  serves the web UI HTML.
- A web search runs through one of five third-party providers (Exa, Firecrawl, Parallel, Tavily, TinyFish), never
  through the model provider: `POST /api/websearch` answers 400 `websearch_provider_required` until
  `websearch.provider` and that provider's API key are set, and a headless session's `websearch` tool call then
  ends with `Web search cancelled` instead of searching. A web fetch needs no provider.
- `GET /api/experimental/migration/v1` reports V1-to-V2 session-history migration progress.
- `OPENCODE_PASSWORD` sets the password; the username is always `opencode`. `OPENCODE_SERVER_USERNAME` is ignored.
- The database is `~/.local/share/opencode/opencode.db` (or `OPENCODE_DB`); the 1.x/2.x migration direction is not
  stated by a page.
