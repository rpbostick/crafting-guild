# agentic-workspace v2 settings. Sourced by every script. Edit freely.
WS_TZ="America/Denver"          # dates written into plans and task files use this calendar
WS_DEFAULT_BUDGET="10"          # dollars, --max-budget-usd for a builder run
WS_REVIEW_BUDGET="3"            # dollars, for a review run
WS_DEFAULT_TIMEOUT="90m"        # wall-clock cap for a builder run (timeout(1) form)
WS_MODEL=""                     # builder model alias ("sonnet", "opus", ...); empty = Claude Code's default
WS_REVIEW_MODEL=""              # reviewer model alias; empty = default
WS_EFFORT=""                    # builder effort (low|medium|high|xhigh|max); empty = default
