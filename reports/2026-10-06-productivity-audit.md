# Productivity audit: the last 36 hours against the week

Written 2026-10-06 23:20 MDT by the orchestrator at Patrick's request ("a $5 audit"). Sources: `runs/*/\*.result.txt` and `*.review.md` (builder and review cost), each project's `git log --merges`, the orchestrator session transcripts (model, timestamps, usage-limit notices), and this repo's commit log. Week window: 2026-09-29 23:00 to 2026-10-06 23:16 MDT; "last 36 hours" is from 2026-10-05 11:16 MDT. There was no activity on 2026-09-30.

## Headline

Output over the last 36 hours matched the week's pace by count and cost about 20 percent more per merge, on the hardest work of the week, with 8 of the 36 hours lost to usage limits.

| | Last 36 h | Week | Share |
|---|---|---|---|
| Branch merges to main | 23 | 107 | 21 % (36 h is 21 % of the week) |
| Builder runs | 44 (35 done, 6 partial, 3 killed by the limit) | 158 | 28 % |
| Builder spend | $227 | $806 | 28 % |
| Review spend | $94 | $173 | 54 % |
| Spend per merge (build + review) | $14.0 | $9.1 | |
| Usage-limit stops | 6 | 10 | 60 % |

The 36 hours were figurewright's body geometry (12 merges, $147 of builds) and Bike Weather's engine and screens (10 merges, $77), plus one skywright fix. The rest of the week was mostly pen-paper-rpg documents and small web pages (48 merges at about $6.60 each), which are cheap and fast by nature. So the per-merge cost rise is partly the mix.

## Day by day

| Day | Orchestrator | Active hours | Orchestrator output tokens | Builder $ | Merges | Limit stops |
|---|---|---|---|---|---|---|
| 10-01 | Opus | 13 | 1.71 M | 168 | 21 | 0 |
| 10-02 | Opus | 13 | 0.80 M | 222 | 36 | 3 |
| 10-03 | Opus to 12:56, then Fable | 5 + 7 | 0.12 M + 0.29 M | 70 | 11 | 1 |
| 10-04 | Fable | 9 | 0.27 M | 118 | 14 | 0 |
| 10-05 | Fable | 14 | 0.45 M | 130 | 11 | 1 |
| 10-06 | Fable | 11 | 0.49 M | 97 | 12 | 5 |

Workspace commits per day (plans, lessons, tool): 69, 55, 23, 23, 40, 38.

## Fable as orchestrator against Opus

- **When.** Opus ran the orchestrator from 10-01 to midday 10-03. Fable has run it since 10-03 13:21. The reviewer was moved to Fable on 10-04 20:31 and its default budget raised on 10-05; review cost per branch went from about $1.00 (10-02 to 10-04) to $3.50 on 10-05 and $4.30 on 10-06. That is most of the review-spend jump, not the orchestrator.
- **Merges per active hour.** Opus days: 1.6 and 2.8. Fable days: 1.6, 0.8 and 1.1. The Opus days were pen-paper-rpg, where a builder finishes in 5 to 20 minutes; the Fable days were figurewright runs of 50 to 70 minutes, each gated on Patrick's look. The projects differ more than the models do here; the one like-for-like signal is 10-04, a Fable day on skywright and pen-paper-rpg, which matched the Opus merge rate at the lowest cost per merge of the week.
- **Orchestrator volume.** Opus wrote three to four times more output tokens per active hour and sent 2,000 messages on 10-01. Much of that was direct editing of the character sheet with Patrick giving screenshots. Fable delegates more and writes less; builder spend per day is similar either way.
- **Orchestration mistakes with a cost.** Under Fable: two found-art runs ($38) on registrations named from reasoning instead of measurement (lesson recorded 10-05). Under both: fw-shoulders-build took seven runs over five days ($85); the last two fell in the window.

## The two directions from 10-05

**"Run more in parallel" (19:00).** Acted on at once: three builders plus plan writing in parallel that evening, four builders overnight, three Bike Weather builders beside figurewright this morning. Parallel work across projects is now the norm; within a project the chain stays sequential because the steps depend on each other. The cost showed up as usage-limit stops: five on 10-06 against none or one on single-stream days. Two stops killed running builders (three LIMIT results; the cut-off work was kept in the worktrees and resumed for under $1 each).

**"Keep running through the night and through run-outs" (23:05).** Followed. A heartbeat fired every 30 minutes; `ws chain` waited through three resets (01:19, 02:48, 03:33); seven merges landed between 23:24 and 06:58; the machine was clean and pushed at 07:36 for the 08:00 offline window. Spend was about $85 of the $200 guide, so no new limit was needed: the usage limit, not the budget, bounded the night. Nothing could run from 03:33 to 06:31.

**The gap.** At 12:57 today the limit killed a *review* inside the chain, and the chain stopped with "the review failed" instead of waiting for the reset as it does for a builder. Nothing ran from 12:57 until this session at 22:57 (the wind-down at 15:32 took the rest of the afternoon anyway). Tonight's run needs that fixed in `scripts/chain.sh` first.

## What to change

1. `ws chain`: a review that fails on the usage limit waits for the reset and retries, like a builder (tool fix, light, before tonight).
2. Three builders at once is the practical cap: beyond that the account limit stops everything, and a stop costs more than the parallelism gains.
3. The reviewer on Fable costs four times Opus. Keep it for visible or complex branches and consider Opus for `Track: light` tasks.
4. Keep measuring before choosing (the found-art lesson): it is the one orchestration error in the window that cost real money.
