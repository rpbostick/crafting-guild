# Crafting Guild settings. Sourced by every script. Edit freely; nothing else reads these.
# config.local.sh, when present, is sourced after this file: put private values there (your own names below).
WS_TZ=""                        # calendar for dates written into plans ("Europe/Lisbon"); empty = this machine's local time
WS_DEFAULT_BUDGET="10"          # dollars, --max-budget-usd for a builder run
WS_REVIEW_BUDGET="8"            # dollars, for a review run
WS_DEFAULT_TIMEOUT="120m"       # wall-clock cap for a builder run (timeout(1) form)
WS_LIGHT_TIMEOUT="45m"          # cap for a task marked 'Track: light'
WS_BUILDER_MEM="4G"             # memory cap for a builder and everything it runs (systemd MemoryMax); empty = no cap
WS_SERVE_MEM="3G"               # memory cap for a `ws serve` preview and everything it starts; empty = no cap
WS_PREVIEW_PORT="8801"          # ws serve <worktree> without a port
WS_PREVIEW_PORT_MAIN="8800"     # ws serve main without a port
WS_BROWSER_CMD="firefox --new-tab"   # ws serve prints "open it: <this> <url>"; empty = print nothing
WS_SUITE_WARN_S="300"           # ws merge warns when the project's suite takes longer than this many seconds
WS_CHAIN_FIX_ROUNDS="1"          # ws chain: automatic fix rounds per step before it stops for the orchestrator
WS_MODEL="opus"                   # builder model alias ("sonnet", "opus", ...); empty = Claude Code's default
WS_REVIEW_MODEL="fable"         # reviewer model alias; empty = default
WS_REVIEW_MODEL_LIGHT="opus"    # reviewer for a branch whose task is marked `Track: light`; empty = WS_REVIEW_MODEL
WS_EFFORT=""                    # builder effort (low|medium|high|xhigh|max); empty = default
WS_WEB_MAX_MB="${WS_WEB_MAX_MB:-20}"   # ws web refuses a file larger than this many MB (the environment may set it for one call)
WS_LESSONS_CAP="40"            # cold-start warns when a lessons/ file (shared or .local.md) passes this many lines
# Words that attribute work to people or to this process. ws merge refuses a branch that adds a line
# matching them (case-insensitive ERE), and ws dispatch refuses a task file that contains them: repos
# state reasons, the workspace's plans keep who and when. Exempt: LICENSE*, package manifests, license
# lists, and each project's CREDIT_PATHS. Empty = no check. Set your own names in config.local.sh, e.g.
# WS_ATTRIBUTION_RE="\\bada\\b|\\blovelace\\b"   (names only, whole words; roles such as "the operator"
# are the reviewer's rule 19, not a refusal).
WS_ATTRIBUTION_RE=""
