# OpenCode 1.x instructions

Read this when `WS_OPENCODE_LINE=1`, which `opencode --version` reports for the installed 1.19.1 line. The 2.x line is
[opencode-2x.md](opencode-2x.md); the mechanisms behind these differences are in
[opencode-orchestrator.md](opencode-orchestrator.md) and [opencode-2-api.md](opencode-2-api.md).

## Shell

- The tool and its permission key are `bash`; `scripts/opencode_run.py` writes the builder's grant and deny rules under
  `bash`, and `scripts/opencode-plugins/deny-guard.js` checks `input.tool === "bash"`.
- A foreground call without `timeout` has no documented limit on this line; the two-minute default is a 2.x statement.

## Flags

- `opencode run --format json` prints `step_start`, `text` and `step_finish` events.
- `--variant <name>` is a model variant, checked with `opencode models <provider> --verbose`.
- Reviews pass `--pure`, which skips every external plugin; a builder does not, because it needs its run-events plugin.
- A client attaches to a server with `--attach <url> --session <id>`, and `OPENCODE_SERVER_PASSWORD` (with
  `OPENCODE_SERVER_USERNAME`) is the Basic-auth pair.

## Plugins

- A local plugin exports named async functions that return an object of hooks. `scripts/opencode-plugins/` holds the
  two file-URL plugins; `.opencode/plugins-1x/` holds the orchestrator's three, and `ws oc` lists them as a `plugin`
  array of `file://` URLs in `runs/<slug>/oc.config.1x.json`. `.opencode/plugins/` itself holds no plugin file: both
  lines auto-discover it, and a 1.x plugin there fails to load on 2.x.
- Hooks in use: `tool.execute.before`, `permission.ask`, `event(input)` with `input.event.properties`,
  `experimental.chat.system.transform` (append to `output.system`), `experimental.session.compacting` (append to
  `output.context`) and `experimental.text.complete` (append to `output.text`).
- The config key is `plugin`, and a file URL or a tuple is accepted.

## Server

- Sessions and messages: `POST /session`, `POST /session/:id/message`, `GET /session/:id/message`.
- `GET /skill` lists skills; `GET /tool` lists tools.
- A forced schema is `format: { type: "json_schema", schema, retryCount }` on `POST /session/:id/message`.
- The database is `~/.local/share/opencode/opencode.db`; this line reads it as its own schema.
