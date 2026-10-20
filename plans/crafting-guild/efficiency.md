# Crafting Guild: quality-safe efficiency (2026-10-20)

**In flight right now**
- **Running (2026-10-20 11:04 MDT):** `ws --project crafting-guild chain plans/crafting-guild/efficiency.queue`: cg-grants-env, cg-lessons-dedupe, cg-bench, cg-web-relay in that order, merging on test evidence. skate-mario's sm-budget-doc runs in its own `tooling.queue`. Next after: pick the 10 bench tasks, write the lean arm, run the bench (40 runs, one at a time).

Patrick, 2026-10-20, after asking for an audit ("it seems like we've been filling up the context buffer a lot sooner and we've run out of tokens a lot ... our runs take a long time too"): make the four fixes, "make sure to research all of these, and create some sort of test for each change. we don't want to lose capability trying to chase efficiency. we want to produce high quality work, gaining speed is a bonus, not something we're willing to trade for quality." Bench: 10 tasks x 2 arms x 2 trials. Builders get no web access; "builders can request searches from you, and you act as a go-between. consider making a tool to automate this builder-to-orchestrator webfetching, so you only need to be involved for the decision." He pivots to bike-weather and wants both at once ("i want to do bike-weather and the workspace fixes at the same time"); this runs beside it in this session, bike-weather in its own `ws bike-weather` session. The bench waits on any project's merge.

## Measured (skate-mario builders, 2026-10-16..20)
- ~190 tool calls a run; context 30k at the start, 150-160k by a quarter of the run, 220-240k at the end; 20-35M cache-read tokens a run.
- Context: ~30k base prompt, ~65k tool output (Read 60-75% of it: whole 20-50 KB files such as main.c, smb3-model.md, skate.s, the test files), the rest the model's own output and thinking (70-105k output tokens a run).
- Denied calls ~1 a run, scattered (git check-ignore x3, git -C x3, git show --output x2, env x2, WebFetch/WebSearch x3).
- Reviews flag hand-copied cycle figures in smb3-model.md as stale on nearly every step.

## Research (agent report, 2026-10-20)
Anthropic, context engineering: just-in-time retrieval, context rot; tools post: range selection, concise responses ~1/3 tokens. SWE-agent ablation (GPT-4 Turbo, SWE-bench Lite): 100-line window 18.0%, whole file 12.7%, 30-line 14.3%; last-5 observations 18.0% vs full history 15.0%. JetBrains Complexity Trap (arXiv 2508.21433): observation masking halves cost, matches or beats summarisation. Claude Code: CLAUDE_CODE_AUTO_COMPACT_WINDOW / --autocompact, BASH_MAX_OUTPUT_LENGTH, --max-turns; thinking is kept across tool steps, no CLI control. Evals: replay fixed tasks from their base commit, several trials, grade outcomes, blind grader, track tokens beside accuracy. Doc numbers: cog --check / marker blocks with a staleness test.

## Steps
1. cg-bench: `ws bench`, replay A/B with a blind review. Built first: every model-behaviour change is measured by it.
2. cg-grants-env: safe recurring grants; dispatch writes a project's worktree env file from its conf. Light.
3. cg-lessons-dedupe: a check that no lesson is lost, then the private orchestrator file reduced to its specifics. Light.
4. cg-web-relay: builders request fetches in their result; `ws web` shows them, fetches what the orchestrator approves into the worktree, and resumes the run.
5. sm-budget-doc (skate-mario): the frame-budget table generated between markers, a test fails when stale. Light.
6. cg-lean-reads (after 1): builder rule "find, then read by section; whole files only for files you edit"; benched against the current rules, 10 tasks x 2 arms x 2 trials, adopted only with no quality drop.

## Bench corpus
- skate-mario first (10 merged tasks). Then bike-weather's merged tasks too (Patrick, 2026-10-20: "i'm also good if the bench evaluates bike-weather once it runs out of skate-mario tasks to compare. there are some compute heavy tasks there too."). A second project also serves as a held-out set, so a rule tuned on skate-mario is checked where it was not tuned. Bike-weather replays run Expo/Metro and jest: one at a time, never beside a bike-weather merge (the bench waits on any project's merge lock), jest with `--runInBand`, Metro with `--max-workers 2`.
