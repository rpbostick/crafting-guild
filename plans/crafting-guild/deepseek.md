# DeepSeek V4.1 Flash in Crafting Guild

**In flight right now (2026-10-22 22:56 MDT, overnight, Claude budget $20 for this session; the OpenCode orchestrator has its own $30 on bike-weather):** two orchestrators (CLAUDE.local.md "Two orchestrators"); builders default to DeepSeek (config.local.sh). figurewright lane (/tmp/claude-1000/-home-patrickb-crafting-guild/2c659456-f846-43e8-9fef-485254378ee1/scratchpad/night-fw.sh, log night-fw.log): the fw-vests-shells fix round, its review, then fw-warmers, fw-hands-feet, fw-head-neck each built and reviewed, sheets copied to ~/Pictures/figurewright, all stopped before merge for Patrick's look. bike-weather lane (night-bw.sh, log night-bw.log): bench pass 1, then trials 2-3 (replay.patch kept per run since this evening), then Hermes + DeepSeek on the same 8 tasks (trial.sh, labels hds-*), for the morning report: Hermes + DeepSeek against Crafting Guild + DeepSeek against Claude's recorded runs. 2.6.0 audit dry run passed; findings in reports/release-2.6.0-audit.md for approval. The OpenCode orchestrator's merges checked: option A was Patrick's choice; server suite 95/95 on main at 1f9facb.

## When Patrick is back (2026-10-22 16:59 MDT, his words: "2 and 1, let's start benchmarking DeepSeek and use our Crafting Guild orchestrator (you) to validate it as we go. i want to get the tools online so we can be using opencode tokens today or tomorrow to build everything out. then we'll get to the other parts.")
1. VSCodium (he runs the apt commands, then settings and extensions).
2. Hermes on DeepSeek, then benchmark DeepSeek, with the orchestrator checking every result by code.
3. Get the OpenCode launcher online soon (Claude builders kept small) so OpenCode tokens do the build-out; the support email goes with it.

## Decided (2026-10-22 16:56 MDT, Patrick)
- **One toolkit with a switch**, not a fork: the same bin/ws and scripts, a setting picks the builder agent (Claude Code or OpenCode + DeepSeek), and an AGENTS.md lets OpenCode orchestrate as CLAUDE.md does. Fork only if we run into issues.
- **Start, in this order, when he is back:**
  1. The OpenCode builder launcher in scripts/dispatch.sh (grants into OpenCode permission config, a cost/steps cap over step_finish costs, the JSON result validated, the log parsed for check-result.sh, selftest stubs, `scripts/zdr-check.sh` refusing a model that is not zero-retention). Built by **Claude builders**, light tasks, kept small to save Claude usage.
  2. The bench: an arm can be another agent and model; replay 5-10 past light tasks, Claude against OpenCode + DeepSeek. Nothing switches unless DeepSeek matches Claude's quality.
  3. Hermes on DeepSeek: a second profile in self-hosted-models' configure-hermes.sh pointing at Go (https://opencode.ai/inference/go/openai/v1), beside local Qwen3.6; run bench/job.sh gear/bugfix/feature on it.
  4. VSCodium: Patrick runs the three sudo apt commands; then copy ~/.config/Code/User/settings.json and keybindings.json to ~/.config/VSCodium/User and install the Claude Code and OpenCode extensions from Open VSX.
  5. The DeepSeek orchestrator (AGENTS.md), after the bench shows DeepSeek's quality.

## Setup state
- OpenCode 1.19.1 at ~/.local/bin/opencode; logged in to OpenCode Go (`opencode auth list`: 1 credential). `opencode models opencode-go` lists deepseek-v4.1-flash.
- **Blocker:** calls fail with "This Go model requires Global regions": Patrick chose to select Global in the console's Privacy settings (guarded by zdr-check.sh). Not yet switched at 2026-10-22 16:56 MDT.
- `opencode run` hangs without `< /dev/null`; the launcher must close stdin.
- Go's page says it "is designed for OpenCode and other coding agents", so headless OpenCode use fits. Still to ask OpenCode support (help@anoma.ly): where Global-region requests are processed.
- DeepSeek on Go: no training, 0 days retention, ZDR agreement renewed monthly (valid through 2026-10-31); zdr-check.sh fails once it lapses unrenewed.
- Never Muse Spark (trains on prompts). Private code only to models zdr-check passes.
