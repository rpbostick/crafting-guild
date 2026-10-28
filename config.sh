# Crafting Guild settings. Sourced by every script. Edit freely; nothing else reads these.
# config.local.sh, when present, is sourced after this file: put private values there (your own names below).
WS_TZ=""                        # calendar for dates written into plans ("Europe/Lisbon"); empty = this machine's local time
WS_BENCH_HOURS="${WS_BENCH_HOURS-}"             # hours the bench replays back to back, "22-07" (WS_TZ, else local); outside them half pace; empty = always back to back
WS_BENCH_OUTSIDE="${WS_BENCH_OUTSIDE-half}"        # outside WS_BENCH_HOURS: "half" (half pace) or "wait" (no replays: the bench runs inside the hours only)
WS_MERGE_TEST_TIMEOUT="${WS_MERGE_TEST_TIMEOUT-1800}"  # seconds the merge gate's test run (and merge.sh --test-only) may take before it is killed and the merge undone; a runner that never exits after its tests would otherwise hold the merge lock
WS_DEFAULT_BUDGET="10"         # dollars, --max-budget-usd for a builder run
WS_REVIEW_BUDGET="8"            # dollars, for a review run
WS_CLAUDE_BUDGET="$WS_REVIEW_BUDGET"   # dollars, for one delegated Claude job (ws claude); --budget overrides
WS_DEFAULT_TIMEOUT="120m"       # wall-clock cap for a builder run (timeout(1) form)
WS_LIGHT_TIMEOUT="45m"          # cap for a task marked 'Track: light'
WS_BUILDER_MEM="4G"             # memory cap for a builder and everything it runs (systemd MemoryMax); empty = no cap
WS_SERVE_MEM="3G"               # memory cap for a `ws serve` preview and everything it starts; empty = no cap
WS_PREVIEW_PORT="8801"          # ws serve <worktree> without a port
WS_PREVIEW_PORT_MAIN="8800"     # ws serve main without a port
WS_TUTOR_PROJECT="${WS_TUTOR_PROJECT-}"   # ws tutor: the course project the tutor tab opens
WS_LIVE_PROJECTS="${WS_LIVE_PROJECTS-}"   # ws autostart: projects whose live app runs on WS_PREVIEW_PORT_MAIN as a systemd user service, restarted after a crash
WS_BENCH_AUTOSTART="${WS_BENCH_AUTOSTART-0}"   # ws autostart: 1 resumes the bench (systemd/ws-bench.service) at login
WS_BENCH_AUTOSTART_CMD="${WS_BENCH_AUTOSTART_CMD-}"   # the bench command file ws-bench.service runs (relative to the workspace or absolute)
WS_BROWSER_CMD="firefox --new-tab"   # ws serve prints "open it: <this> <url>"; empty = print nothing
WS_SUITE_WARN_S="300"           # ws merge warns when the project's suite takes longer than this many seconds
WS_CHAIN_FIX_ROUNDS="1"          # ws chain: automatic fix rounds per step before it stops for the orchestrator
WS_MODEL="opus"                   # builder model alias ("sonnet", "opus", ...); empty = Claude Code's default
WS_REVIEW_MODEL="fable"         # reviewer model alias; empty = default
WS_REVIEW_MODEL_LIGHT="opus"    # reviewer for a branch whose task is marked `Track: light`; empty = WS_REVIEW_MODEL
WS_REVIEW_AGENT="${WS_REVIEW_AGENT:-claude}"  # what runs a review: "claude" or "opencode" (scripts/opencode-review.sh); ws review --agent overrides
WS_EFFORT=""                    # builder effort (low|medium|high|xhigh|max); empty = default
WS_AGENT="${WS_AGENT:-claude}"  # what runs a builder: "claude" (claude -p) or "opencode" (scripts/opencode-builder.sh); ws dispatch --agent overrides
WS_OPENCODE_MODEL="opencode-go/deepseek-v4.1-flash"   # builder model for --agent opencode (provider/model); --model overrides
WS_MIN_OPENCODE="1.19.1"        # oldest OpenCode whose SDK/plugin API the launchers use: the server's json_schema output and experimental.* hooks
# OpenCode model IDs and the names OpenCode's Go page gives them in its privacy table, which zdr-check reads: a model
# not listed here is refused, since its retention cannot be checked.
WS_OPENCODE_MODEL_NAMES=("opencode-go/deepseek-v4.1-flash=DeepSeek V4.1 Flash")
WS_REVIEW_SHADOW="${WS_REVIEW_SHADOW-}"   # empty = off; "opencode" also reviews every deciding review on OpenCode and records the pair
WS_REVIEW_SHADOW_MODEL="${WS_REVIEW_SHADOW_MODEL:-$WS_OPENCODE_MODEL}"   # provider/model for a shadow review
WS_REVIEW_SHADOW_BUDGET="${WS_REVIEW_SHADOW_BUDGET:-$WS_REVIEW_BUDGET}"   # dollars, for one shadow review
WS_REVIEW_MEM="${WS_REVIEW_MEM:-3G}"   # memory cap for a shadow review and everything it starts (systemd MemoryMax); empty = none
WS_WEB_MAX_MB="${WS_WEB_MAX_MB:-20}"   # ws web refuses a file larger than this many MB (the environment may set it for one call)
WS_LESSONS_CAP="40"            # cold-start warns when a lessons/ file (shared or .local.md) passes this many lines
# Words that attribute work to people or to this process. ws merge refuses a branch that adds a line
# matching them (case-insensitive ERE), and ws dispatch refuses a task file that contains them: repos
# state reasons, the workspace's plans keep who and when. Exempt: LICENSE*, package manifests, license
# lists, and each project's CREDIT_PATHS. Empty = no check. Set your own names in config.local.sh, e.g.
# WS_ATTRIBUTION_RE="\\bada\\b|\\blovelace\\b"   (names only, whole words; roles such as "the operator"
# are the reviewer's rule 19, not a refusal).
WS_ATTRIBUTION_RE=""
