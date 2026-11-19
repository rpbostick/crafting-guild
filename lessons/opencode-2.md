# Lessons: OpenCode 2.x

This prompt runs against OpenCode 2.x. Name and follow the 2.x surface (`docs/opencode-2x.md` has the detail; the
sources and unresolved rows are in `docs/opencode-2-api.md`).

- The shell tool and permission action are `shell`, not `bash`; `write`/`patch` are `edit`, and `task` is `subagent`.
  The deny guard checks `event.tool` against `shell` and reads `event.input.command`.
- There is no `--pure`, `--attach` or `--variant`: use `--standalone`, `--server <url>` with `OPENCODE_PASSWORD`, and
  `-m provider/model#variant`. `opencode models` takes no provider argument and has no `--verbose`.
- A default run uses a background service that caches its first config. A per-run `OPENCODE_CONFIG_CONTENT` needs
  `--standalone` or a service stop/start; do not assume a later config applies.
- A plugin default-exports `{ id, setup }` (or `Plugin.define`). Register through `ctx.tool.hook("execute.before")`,
  `ctx.session.hook("context")`/`("compaction")` and `ctx.permission.hook("evaluate")`; events come from
  `ctx.event.subscribe()` as `{ type, data }`, not `input.event.properties`.
- There is no `experimental.text.complete`; do not port reply-time/reply-log without a decided replacement.
- The server is under `/api` (`/api/session`, `/api/skill`, `/api/tool`, `/api/event`, `/api/websearch`). On 2.2.7 the
  1.x `POST /session` and `GET /skill` answer 405, while `GET /tool` still serves the web UI HTML.
- Run checks through `bin/ws-run`; do not switch a 2.x command to a 1.x spelling on this line.
