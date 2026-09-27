# agentic-workspace v2 settings. Sourced by every script. Edit freely; nothing else reads these.
WS_TZ=""                        # calendar for dates written into plans ("America/Denver"); empty = this machine's local time
WS_DEFAULT_BUDGET="10"          # dollars, --max-budget-usd for a builder run
WS_REVIEW_BUDGET="3"            # dollars, for a review run
WS_DEFAULT_TIMEOUT="120m"       # wall-clock cap for a builder run (timeout(1) form)
WS_LIGHT_TIMEOUT="45m"          # cap for a task marked 'Track: light'
WS_SUITE_WARN_S="300"           # ws merge warns when the project's suite takes longer than this many seconds
WS_MODEL=""                     # builder model alias ("sonnet", "opus", ...); empty = Claude Code's default
WS_REVIEW_MODEL=""              # reviewer model alias; empty = default
WS_EFFORT=""                    # builder effort (low|medium|high|xhigh|max); empty = default
WS_LESSONS_CAP="40"             # cold-start warns when a lessons/ file passes this many lines
