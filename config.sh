# Crafting Guild settings. Sourced by every script. Edit freely; nothing else reads these.
# config.local.sh, when present, is sourced after this file: put private values there (your own names below).
WS_TZ=""                        # calendar for dates written into plans ("Europe/Lisbon"); empty = this machine's local time
WS_BENCH_HOURS="${WS_BENCH_HOURS-}"             # hours the bench replays back to back, "22-07" (WS_TZ, else local); outside them half pace; empty = always back to back
WS_BENCH_OUTSIDE="${WS_BENCH_OUTSIDE-half}"        # outside WS_BENCH_HOURS: "half" (half pace) or "wait" (no replays: the bench runs inside the hours only)
WS_MERGE_TEST_TIMEOUT="${WS_MERGE_TEST_TIMEOUT-1800}"  # seconds the merge gate's test run (and merge.sh --test-only) may take before it is killed and the merge undone; a runner that never exits after its tests would otherwise hold the merge lock
WS_DEFAULT_BUDGET="10"         # dollars, --max-budget-usd for a builder run
WS_REVIEW_BUDGET="8"            # dollars, for a review run
WS_REVIEW_PASS_RETRY="${WS_REVIEW_PASS_RETRY:-1}"     # a failed review pass is retried once, after the others finish
WS_REVIEW_PASS_RETRY_DELAY="${WS_REVIEW_PASS_RETRY_DELAY:-5}"  # seconds before that retry
# Independent reviews per branch (1-3), their blocking findings unioned and the strictest verdict kept; ws review
# --passes overrides. An OpenCode-only install sets 2 in config.local.sh, so every script review runs two OpenCode
# passes and their blocking findings are unioned. Each pass costs a whole review, so on Claude the cost multiplies.
WS_REVIEW_PASSES="${WS_REVIEW_PASSES-1}"
WS_CLAUDE_BUDGET="$WS_REVIEW_BUDGET"   # dollars, for one delegated Claude job (ws claude); --budget overrides
# Dollars a day for Claude builders and ws claude jobs together, read from runs/*/claude-jobs.tsv; empty = no cap.
# An installation sets it in config.local.sh; ws claude --spent prints today's total and the room left.
WS_CLAUDE_DAY_CAP="${WS_CLAUDE_DAY_CAP-}"
WS_DEFAULT_TIMEOUT="120m"       # wall-clock cap for a builder run (timeout(1) form)
WS_LIGHT_TIMEOUT="45m"          # cap for a task marked 'Track: light'
WS_BUILDER_MEM="4G"             # memory cap for a builder and everything it runs (systemd MemoryMax); empty = no cap
WS_SERVE_MEM="3G"               # memory cap for a `ws serve` preview and everything it starts; empty = no cap
WS_OC_PORT="${WS_OC_PORT:-4096}"                     # ws oc starts the session's server on the first free port from here up (runs/<slug>/oc.port)
WS_WAKE_URL="${WS_WAKE_URL:-}"                        # the server ws wake sends to: --url, else this when set, else http://127.0.0.1:<runs/<slug>/oc.port>, else http://127.0.0.1:4096
WS_WAKE_TIMEOUT="${WS_WAKE_TIMEOUT:-900}"             # seconds ws wake waits for the session's first event before it records a failure
WS_WAKE_ATTEMPTS="${WS_WAKE_ATTEMPTS:-3}"             # delivery attempts for one wake before it gives up (a timeout is not retried)
WS_WAKE_RETRY_DELAY="${WS_WAKE_RETRY_DELAY:-20}"       # seconds between those attempts
WS_WAKE_BACKSTOP="${WS_WAKE_BACKSTOP:-600}"            # seconds: one more attempt on a timer after they fail; 0 = none
WS_PREVIEW_PORT="8801"          # ws serve <worktree> without a port
WS_PREVIEW_PORT_MAIN="8800"     # ws serve main without a port
WS_TUTOR_PROJECT="${WS_TUTOR_PROJECT-}"   # ws tutor: the course project the tutor tab opens
WS_LIVE_PROJECTS="${WS_LIVE_PROJECTS-}"   # ws autostart: projects whose live app runs on WS_PREVIEW_PORT_MAIN as a systemd user service, restarted after a crash
WS_BENCH_AUTOSTART="${WS_BENCH_AUTOSTART-0}"   # ws autostart: 1 resumes the bench (systemd/ws-bench.service) at login
WS_BENCH_AUTOSTART_CMD="${WS_BENCH_AUTOSTART_CMD-}"   # the bench command file ws-bench.service runs (relative to the workspace or absolute)
WS_BROWSER_CMD="firefox --new-tab"   # ws serve prints "open it: <this> <url>"; empty = print nothing
WS_SUITE_WARN_S="300"           # ws merge warns when the project's suite takes longer than this many seconds
WS_SELFTEST_LOCK_WAIT="${WS_SELFTEST_LOCK_WAIT:-900}"  # seconds a second `bash scripts/selftest.sh`, in the main checkout or a worktree, waits for the one running before it exits 3
WS_CHAIN_FIX_ROUNDS="1"          # ws chain: automatic fix rounds per step before it stops for the orchestrator
# A usage limit's reset can be days away. A wait longer than WS_LIMIT_PROBE_AFTER seconds wakes every
# WS_LIMIT_PROBE_EVERY seconds and makes one cheap probe call through the same agent and model; the first success
# resumes at once, so a limit that ended (an upgrade, a new pool) does not stall the bench or the chain for days.
WS_LIMIT_PROBE_AFTER="${WS_LIMIT_PROBE_AFTER:-21600}"  # seconds: a wait longer than this probes instead of sleeping to the reset
WS_LIMIT_PROBE_EVERY="${WS_LIMIT_PROBE_EVERY:-3600}"   # seconds between probe calls
WS_LIMIT_PROBE_BUDGET="${WS_LIMIT_PROBE_BUDGET:-0.05}" # dollars one probe call may spend
WS_LIMIT_PROBE_TIMEOUT="${WS_LIMIT_PROBE_TIMEOUT:-120}" # seconds one probe call may take
WS_LIMIT_POLL="${WS_LIMIT_POLL:-60}"                   # seconds a usage-limit wait sleeps between clock checks
WS_MODEL="opus"                   # builder model alias ("sonnet", "opus", ...); empty = Claude Code's default
WS_REVIEW_MODEL="fable"         # reviewer model alias; empty = default
WS_REVIEW_MODEL_LIGHT="opus"    # reviewer for a branch whose task is marked `Track: light`; empty = WS_REVIEW_MODEL
WS_REVIEW_AGENT="${WS_REVIEW_AGENT:-}"  # what runs a review: empty = whichever client is installed (with only opencode installed every review runs there, no Claude CLI needed; the changed files decide when both are: docs-only on opencode, anything else on claude); "claude" or "opencode" forces it; ws review --agent overrides
WS_EFFORT=""                    # builder effort: Claude's low|medium|high|xhigh|max, or an OpenCode model variant
                                # (`opencode models <provider> --verbose`); empty = default. Applies to both agents:
                                # a model without that variant refuses the dispatch rather than dropping the setting.
WS_AGENT="${WS_AGENT:-claude}"  # what runs a builder: "claude" (claude -p, needs the Claude CLI) or "opencode" (scripts/opencode-builder.sh); an OpenCode-only install sets opencode; ws dispatch --agent overrides
# OpenCode builder shell commands run in scripts/ws-sandbox-shell.sh (bubblewrap: home masked, no network) when
# this is "bwrap"; empty (off) leaves the generated OpenCode config as it was. Claude builders are out of scope.
WS_SANDBOX="${WS_SANDBOX-}"
WS_OPENCODE_MODEL="opencode-go/deepseek-v4.1-flash"   # builder model for --agent opencode (provider/model); --model overrides
WS_MIN_OPENCODE="1.19.1"        # oldest OpenCode whose SDK/plugin API the launchers use: the parity probe's server json_schema output and the plugins' hooks
WS_OPENCODE_LINE="${WS_OPENCODE_LINE-}"   # 1 or 2, or empty to read the major from `opencode --version` in scripts/lib.sh; selects lessons/opencode-<line>.md and the line docs
WS_ASK_MODEL="${WS_ASK_MODEL-}"   # provider/model for ws ask research jobs; empty = the builder model (WS_OPENCODE_MODEL), resolved in scripts/ask.sh
WS_ASK_BUDGET="${WS_ASK_BUDGET:-0.50}"              # dollars, for one ws ask research job
# OpenCode model IDs and the names its Go or Zen page gives them in its privacy table, which zdr-check reads: a model
# not listed here is refused, since its retention cannot be checked.
WS_BROWSER_MCP_VERSION="0.0.84"   # @playwright/mcp, exact: npx would otherwise fetch whatever is newest into the orchestrator session
WS_OPENCODE_MODEL_NAMES=("opencode-go/deepseek-v4.1-flash=DeepSeek V4.1 Flash")
WS_REVIEW_SHADOW="${WS_REVIEW_SHADOW-}"   # empty = off; "opencode" also reviews every deciding review on OpenCode and records the pair
WS_ORCHESTRATOR_OPENCODE="${WS_ORCHESTRATOR_OPENCODE-}"   # slugs (space-separated) an OpenCode session owns; ws orchestrator-record counts the rest as Claude's, and with this empty prints the owner as not recorded
WS_REVIEW_SHADOW_MODEL="${WS_REVIEW_SHADOW_MODEL:-$WS_OPENCODE_MODEL}"   # provider/model for a shadow review
WS_REVIEW_SHADOW_BUDGET="${WS_REVIEW_SHADOW_BUDGET:-$WS_REVIEW_BUDGET}"   # dollars, for one shadow review
WS_REVIEW_MEM="${WS_REVIEW_MEM:-3G}"   # memory cap for a shadow review and everything it starts (systemd MemoryMax); empty = none
# OpenCode Go limits, one per model and window: <provider/model>=<5h>,<7d>,<30d> in dollars, space-separated. From
# opencode.ai/docs/go: 20%, 50% and 100% of a model's monthly dollars (Flash $100, Pro $15). ws allowance reads them.
WS_ALLOWANCE_LIMITS="${WS_ALLOWANCE_LIMITS-opencode-go/deepseek-v4.1-flash=20,50,100 opencode-go/deepseek-v4-pro=3,7.5,15}"
WS_ALLOWANCE_HOLD="${WS_ALLOWANCE_HOLD-80}"   # percent of the summed window total past which ws bench run waits, ws review-compare stops and shadow reviews are skipped; chains, dispatches and sessions only warn
WS_ALLOWANCE_STARTS="${WS_ALLOWANCE_STARTS-}"   # <5h-epoch>,<7d-epoch>,<30d-epoch> from the Go Console; empty = rolling windows
WS_ALLOWANCE_DB="${WS_ALLOWANCE_DB-$HOME/.local/share/opencode/opencode.db}"   # OpenCode's database, read-only; empty = the meter is off and nothing is held
WS_WEB_MAX_MB="${WS_WEB_MAX_MB:-20}"  # ws web refuses a file larger than this many MB (the environment may set it for one call)
WS_LESSONS_CAP="40"            # cold-start warns when a lessons/ file (shared or .local.md) passes this many lines
# Days between maintenance reports. When runs/maintenance.last is older than this, cold-start --brief and ws brief
# print one "maintenance due" line; the report itself runs only when someone runs `ws maintenance` (no timer).
WS_MAINTENANCE_DAYS="${WS_MAINTENANCE_DAYS-7}"
# Days zdr-check reuses a fetched privacy page (runs/zdr-page-go.html, runs/zdr-page-zen.html) before fetching it
# again; a failed refresh still falls back to the stale page. 0 always fetches when it has no --page.
WS_ZDR_CACHE_DAYS="${WS_ZDR_CACHE_DAYS-1}"
WS_MEMORY_DIR="${WS_MEMORY_DIR-}"   # absolute path of a memory directory (MEMORY.md plus one file per memory) an OpenCode orchestrator loads; set it in config.local.sh; empty = no memory
WS_MEMORY_CAP="${WS_MEMORY_CAP-24000}"   # characters of the memory index and bodies in a session's system text, not counting the header and notes; what does not fit is dropped and named there
# 1: every question to the operator goes through the question tool with labelled options and a free-text box;
# 0: plain chat questions. On by default; set 0 in config.local.sh to turn it off.
WS_ASK_PROMPTS="${WS_ASK_PROMPTS-1}"
# A line in a plan that says a decision waits on the operator (an ERE; empty lists none). config.local.sh may
# override it, and the environment may for one call.
WS_WAITING_RE="${WS_WAITING_RE-[Ww]aiting on (the operator|you)}"
# Words that attribute work to people or to this process. ws merge refuses a branch that adds a line
# matching them (case-insensitive ERE), and ws dispatch refuses a task file that contains them: repos
# state reasons, the workspace's plans keep who and when. Exempt: LICENSE*, package manifests, license
# lists, and each project's CREDIT_PATHS. Empty = no check. Set your own names in config.local.sh, e.g.
# WS_ATTRIBUTION_RE="\\bada\\b|\\blovelace\\b"   (names only, whole words; roles such as "the operator"
# are the reviewer's rule 19, not a refusal).
WS_ATTRIBUTION_RE=""
