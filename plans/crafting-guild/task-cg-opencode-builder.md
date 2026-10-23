# Builders on OpenCode: an agent switch in dispatch

Builders are launched as `claude -p` (`scripts/dispatch.sh`, the `cmd=(claude -p ...)` line). Add a second launcher that runs the same builder through OpenCode (`opencode run`, MIT, github.com/anomalyco/opencode) with a model such as `opencode-go/deepseek-v4.1-flash`. Everything downstream (check-result, wait, chain, review, merge) must work unchanged.

## What to build
1. **The switch.** `WS_AGENT` in `config.sh` (`claude`, the default, or `opencode`), and a `--agent claude|opencode` flag on dispatch (and passed through by `ws dispatch` and chain queue flags, as `--model` is). For opencode, `--model` takes a `provider/model` ID; `WS_OPENCODE_MODEL` in config.sh is the default (`opencode-go/deepseek-v4.1-flash`). The dry run prints the agent and model.
2. **`scripts/opencode-builder.sh`**, run by dispatch in place of `claude -p`, with the same prompt, budget, timeout and memory cap:
   - **Privacy guard first:** run `scripts/zdr-check.sh` with the model's display name (Go's page maps IDs to names in its model table; see how `~/self-hosted-models/scripts/configure-hermes.sh --go` does it, or keep a small ID-to-name map in config.sh, whichever you can test offline). A model that fails is refused before anything runs, with the check's reason in the log.
   - **Grants become OpenCode permissions.** Build an OpenCode config (passed via `OPENCODE_CONFIG_CONTENT` or a file in `$RUNS`, whichever OpenCode 1.19 honours; check its docs at opencode.ai/docs/permissions and /docs/config) where `bash` is `deny` by default with an `allow` rule per Bash grant in `TOOLS` (the `Bash(<pattern>)` form becomes the pattern), the `DENY` list stays denied, `edit` is allowed only inside the worktree, `webfetch`/`websearch` follow the task's web grants, `external_directory` is denied, and `share` is disabled. Nothing may resolve to `ask`: headless, it must be allow or deny. Denied calls must still be reported (the result's `denied`).
   - **Budget cap:** each `step_finish` event carries `part.cost` (dollars). Sum them as the log streams; when the sum passes the budget, stop OpenCode (by PID, never `pkill -f`) and finish as below with status forced to `partial`.
   - **stdin closed** (`< /dev/null`): `opencode run` hangs waiting on it otherwise.
   - **A Claude-shaped result.** OpenCode has no JSON-schema output. The prompt already asks for the JSON result; take the last text part, extract the JSON object, and validate it against `schema/result.json` (python3 stdlib only; `jsonschema` is not installed, so check the types, enums and required keys the schema uses). If it does not validate, continue the same session once (`opencode run --session <id>`) with the errors and "reply with only the JSON result". Then append one line to the run's `.jsonl` that `result_json` in `scripts/lib.sh` already finds: `{"type":"result","total_cost_usd":<sum>,"duration_ms":<wall>,"usage":{"output_tokens":<sum>,"cache_read_input_tokens":<sum>},"structured_output":<the result or null>,"result":<last text>}`. A result that still does not validate leaves `structured_output` null, so check-result reports it as it does for Claude.
3. **check-result and review** work on an OpenCode run without changes to their checks; if anything there reads Claude-only event fields (tool denials, web requests), make it read both shapes.
4. **Self-test** (`scripts/selftest.sh`): a stand-in `opencode` on PATH (as the stand-in `claude` already is) that replays `plans/crafting-guild/opencode-sample.jsonl` (a real OpenCode 1.19.1 log: one bash tool call, two `step_finish` costs, a final text) with the final text swapped for a valid result. Check:
   - a dry run with `--agent opencode` shows the agent, model, and the generated permission config (Bash grants allowed, `git push` denied, nothing set to `ask`);
   - a run ends with a result line check-result accepts;
   - a run whose steps cost more than the budget is stopped and reported `partial`;
   - an invalid final JSON triggers exactly one continue, and if that also fails, `structured_output` is null;
   - a model zdr-check refuses (a saved page fixture, as the existing zdr-check self-test does) never starts the stand-in.
   No self-test may call a real model.
5. Docs: `MODIFYING.md` (the new script and setting), `README.md` (one paragraph: builders on OpenCode, zero-retention models only), `bin/ws help`.

## Prior art
- OpenCode's own headless mode and permission system (opencode.ai/docs/cli, /docs/permissions, /docs/config): use them; do not build a sandbox.
- The existing Claude path in `scripts/dispatch.sh` and the stand-in claude in `scripts/selftest.sh`: copy their shape.
- `scripts/zdr-check.sh` for the privacy guard.

## Commands
`bash scripts/selftest.sh`, `bash -n *`, `shellcheck *`, `python3 *`, `jq *`, `git add`, `git commit`, `git mv`, `grep *`. One command per Bash call. Never run a real `opencode` or `claude` (the stand-ins only). No installs.

## Leave alone
`plans/`, `projects/`, `lessons/`, `CLAUDE.md`, `*.local.*`. The Claude launch path must behave exactly as before.

## Done when
- `ws dispatch --dry-run --agent opencode <name> <task>` prints the agent, the model and a permission config with every Bash grant allowed, the deny list denied and no `ask`.
- The self-test checks in step 4 pass, and `bash scripts/selftest.sh` passes in full.
- With no `--agent` and `WS_AGENT` unset, a dry run's printed command and prompt are byte-identical to main's.
