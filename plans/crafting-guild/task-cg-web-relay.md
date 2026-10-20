# Crafting Guild: builders request web sources; the orchestrator only decides

Track: full

Builders have no web access (WebFetch and WebSearch are denied by design). When a task needs a source (a disassembly, a spec, docs), today the builder fails a call, reasons around it, and the orchestrator fetches by hand. Instead, a builder asks, and a tool does everything but the decision. Read `schema/` (the result schema), `scripts/dispatch.sh`, `scripts/check-result.sh`, `scripts/chain.sh` and `agents/builder.md` first, by section.

## Build
- Result schema: an optional `web_requests` list, each `{url or query, why, what is needed from it}`. `agents/builder.md`: when a task needs a web source it does not have, the builder does the rest it can, returns `status: partial` with the request, and does not call WebFetch/WebSearch.
- `check-result.sh` prints the requests; `ws chain` stops on them with the reason "web requests".
- `ws web <name>`: lists the requests; `ws web <name> approve <n|all> [--url <replacement>]` fetches each approved URL with curl (raw file, no rendering) into the worktree's `.ws-evidence/given/web/` with a sidecar noting URL, time, size and SHA-256, refuses non-http(s) schemes and files over a size cap (`WS_WEB_MAX_MB`, config.sh, default 20), and treats the content as data. A search request is not fetched: `ws web` shows it so the orchestrator can answer with URLs (then approve those). `ws web <name> resume` writes a resume task naming the fetched files and re-dispatches the same builder name. `ws web <name> deny <n> "<reason>"` records the reason for the resume task.
- `MODIFYING.md`, `bin/ws help` and `lessons/orchestrator.md` (one line) describe it.

## Tests
`scripts/selftest.sh`, offline (a local `python3 -m http.server` on a free port or a file:// refusal check, no internet): a fixture result with two requests is listed; approving one fetches it into `given/web/` with its sidecar; a non-http scheme and an oversize file are refused; deny records its reason; resume writes a task naming the file and keeps the original task's Commands. Show them failing first (log).

## Prior art
Claude Code's own permission model (deny by default, a human approves); curl's `--max-filesize` and `--proto =http,https` for the limits.

## Commands
`bash scripts/selftest.sh`, `bash -n *`, `shellcheck *`, `python3 *`, `bash *`, `git add`, `git commit`, `git log *`, `git show *`, `git worktree *`, `git rev-parse *`. One command per Bash call. `curl *`.

## Done when
- The new selftest checks fail before and pass after (logs); `bash scripts/selftest.sh` passes (log).

## Carried from the cg-bench review (suggestions; do them where the code is yours to touch)
- `scripts/bench.sh:142`: Rule 1: when merge.sh --test-only refuses a misconfigured project (npm ci with a linked node_modules, or no TEST_CMD), the run is recorded as tests=fail, the same as a real test failure. The bench then spends money on every run, and every arm shows 0% tests passed. Run the same refusal check once in bench_run before dispatching (and in --dry-run), so a config error stops the bench instead of being recorded as quality data.
- `scripts/bench.sh:166`: A git-ref arm copies only the builder*.md files tracked at that commit, so a gitignored lessons/builder.local.md never reaches a `current=HEAD` arm. A directory arm, by contrast, carries whatever its directory holds. If the live workspace uses builder.local.md, the baseline arm isn't what builders get today. Say so in the usage text or MODIFYING.md, or copy the workspace's local file into ref arms.
- `scripts/bench.sh:141`: review.sh's exit status is ignored. A review that crashes or hits a limit is recorded as verdict 'none' and counted as a non-merge in 'merge verdicts', which can produce a spurious quality drop. Record a review failure separately (state, or a 'review-failed' verdict that the report leaves out).
- `projects/skate-mario.conf:4`: Rule 18 (existing before this branch, not added here): PROJECT_PATH and TEST_CMD in this tracked conf already hold /home/patrickb paths. The new BENCH_TEST_CMD line rightly doesn't repeat them. Consider making project confs untracked, or reading these paths from the environment, in a separate change.
- `scripts/chain.sh:123`: This change to the chain's stop message (and the selftest's carry-repo hook test) is outside the bench task's scope. It looks correct, but it belongs in its own commit or a note in the task log.
