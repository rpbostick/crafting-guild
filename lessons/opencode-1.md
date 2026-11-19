# Lessons: OpenCode 1.x (installed line)

This prompt runs against OpenCode 1.x. Name and follow the 1.x surface (`docs/opencode-1x.md` has the detail).

- The shell tool and permission key are `bash`; a deny or allow rule for a command goes under `bash`.
- `--pure`, `--variant <name>` and `--attach <url>` exist, and the model list takes a provider and `--verbose`. A review
  keeps `--pure`; a builder needs its run-events plugin, so it must not use `--pure`.
- A plugin exports named async functions returning hooks; events arrive as `event(input)` with `input.event.properties`.
  `tool.execute.before` gets `(input, output)` and a shell command is `output.args.command` with `input.tool === "bash"`.
- The context hooks are `experimental.chat.system.transform` (`output.system.push`) and
  `experimental.session.compacting` (`output.context.push`). A finished reply is `experimental.text.complete`
  (`output.text`).
- The server paths are `POST /session`, `GET /skill` and `POST /session/:id/message`; the schema field on the last one is
  `format: { type: "json_schema", schema, retryCount }`.
- Run checks through `bin/ws-run`; do not switch a 1.x command to a 2.x spelling on this line.
