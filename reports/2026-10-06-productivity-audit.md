# Productivity audit: the last 36 hours against the week

Written 2026-10-06 23:20 MDT by the orchestrator at Patrick's request ("a $5 audit"). Sources: `runs/*/\*.result.txt` and `*.review.md` (builder and review cost), each project's `git log --merges`, the orchestrator session transcripts (model, timestamps, usage-limit notices), and this repo's commit log. Week window: 2026-09-29 23:00 to 2026-10-06 23:16 MDT; "last 36 hours" is from 2026-10-05 11:16 MDT. There was no activity on 2026-09-30.

## Headline

Three questions were asked: the last 36 hours against the week, Fable against Opus as orchestrator, and the two directions from 10-05. Two were added while it was written: the weekend's paper RPG projects in their own right, and rework, error rates and time to done.


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

## The weekend's paper RPG work (10-01 to 10-04)

The pen-paper-rpg cluster (pen-paper-rpg, toybox, reactbits-kit, the GitHub Pages site, the dice comparison) was most of the week: 88 of 158 runs, 64 of 107 merges, $446 of $806 in builds. Under Opus from 10-01 to midday 10-03, then Fable.

| Project | Runs | Merges | Build $ | $ per merge | Not-done runs | Fix tasks |
|---|---|---|---|---|---|---|
| pen-paper-rpg | 63 | 47 | 316 | 6.7 | 4 | 9 |
| toybox | 8 | 7 | 71 | 10.1 | 1 | 0 |
| reactbits-kit | 5 | 5 | 39 | 7.8 | 0 | 0 |
| rpbostick.github.io | 11 | 3 | 20 | 6.5 | 0 | 0 |
| dice-roller-comparison | 1 | 1 | 1 | 0.7 | 0 | 0 |

What it produced: the rules synthesis through six versions with three review tools and two review pages; the character generator (groundwork, editable attributes, public build, flavour names, the sheet, the toybox edition); five research reports (licences, community hacks, drawing tools, web toys, prices, group combat, spells, magic); the toybox as its own library (drawer, windows, dice tray, drawing, twisty cube, backgrounds) and reactbits-kit as a package the site and chargen both install. Median time from first run to merge was under an hour; the longest was the chargen sheet at 10 hours.

This is the cheapest work of the week per merge and the fastest. It is also where most of the operator-driven iteration happened (next section).

## Rework, error rates and time to done

**Error rates by project (week).**

| Project | Runs not done (partial, blocked, killed) | Branches needing a fix round | Typical failure |
|---|---|---|---|
| figurewright | 12 of 34 (35 %) | 2 of 20 | the run ends partial at its budget or timeout; resumed |
| bike-weather | 2 of 24 (8 %) | 9 of 13 (69 %) | the review says fix-first; a $0.20 to $2 fix round follows |
| pen-paper-rpg | 4 of 63 (6 %) | 9 of 48 (19 %) | the operator asks for another pass after looking |
| skywright, reactbits-kit, dice | 0 | 0 | |
| toybox, site | 1 of 19 | 0 | |

Today's reviews on their own: four fix-first out of about nine (bw-name-check, bw-wardrobe-screen, fw-hybrid-widths, bw-today). The reviewer on Fable finds more; each fix round so far was a real defect or a false claim in the result, and none has needed a second round.

**Things redone over and over.** Ranked by cost, with when the course should have changed.

1. **figurewright shoulders: 8 runs, 4 days, $84, then $29 more.** Patrick said on 10-01 12:53 that the wide builds' shoulders "hang way away from the body" and at 12:58 gave the rule: shoulder width follows chest width. fw-shoulders-build then ran three partials in the next 2.5 hours and five more runs through 10-05. On 10-05 15:45 he had to state the same rule again ("bring the chest out and the shoulders in"), which became fw-shoulders-chest and fw-shoulders-in that evening. The rule given on 10-01 was never written into a task as the acceptance test; the tasks chased widths instead. **Switch point missed:** three partial runs on one name in one afternoon. The rule now: after the second partial on a name, stop and change the task (measure first, split, or state the acceptance rule), not the budget.
2. **fw-found-art: 3 runs, $43, 2.5 hours.** Two runs on registrations chosen by reasoning; the builder's measured third option was right. Lesson recorded 10-05; the measure-first rule in fw-far-arm-neck's task comes from it.
3. **site-waves-momentum: 9 runs, 5 hours, $17.** Four rounds of feel ("more local ripple", "the sheet doesn't spring back", "like the inside of a ball"), each a builder round of 20 to 60 minutes for a few parameters. **Switch point missed:** after round three the right move was a page with the parameters as sliders for Patrick to tune live, then one builder round to commit the values. This is the automation rule applied to feel-tuning.
4. **ppr-chargen-sheet: 8 runs, 5 hours, $42, four fix tasks.** Mostly new asks per round (numbered weapon lines, the printer-friendly toggle, colour printing, printing the scribbles), so less rework than it looks; one true redo (the lines had to be fixed height after the first pass). Rounds with screenshots are how this work goes; the cost is fine, the wall-clock is the builder's turnaround.
5. **Rules synthesis v1 to v6: 6 versions in 3 days, about $100 with the review tools.** Iterative by design: Patrick reads, sends a review pass, a new version is built. Not rework.
6. **The 3D route: two spike rounds, $17, then the hybrid.** The course changed on the analysis's evidence within a night. This is the switch working as it should.

**How long against how long it should have taken.** Median first run to merge is under an hour everywhere except figurewright, where the median is also short but the tail is four days (shoulders) and the hybrid line is now three runs deep with a gate each. The pattern in the tail is the same each time: a visible fault Patrick named in one sentence, a task that did not carry that sentence as its pass or fail, and a run budget raised instead of the task changed.

**Process regressions he pointed out this week.** 10-03 20:58: "you used to give me prompts with checkboxes and suggestions. i would like that again" (Fable's first day; the lesson was re-seeded). 10-05 19:00: "progress has felt really slow today" (figurewright's dependent line, answered with the parallel plan). 10-06 10:23: questions were skipped and had to be asked again. 10-06 23:07: a preview that showed Expo's placeholder instead of the app (a shared Metro cache; fixed in the preview command).

## Usage limits: what a stop costs

Measured over the week from the orchestrator transcripts and the run results (Patrick's estimate: "5 to 10 % of our tokens for a window to recover").

| | Value |
|---|---|
| Limit stops in the week | 10 (six of them on 10-05 and 10-06) |
| Builder resume runs after a kill | 6, about $15 in all |
| Orchestrator input volume in the 30 minutes after a reset | 1.6 to 2.9 times its normal half-hour (one reset at 0.6) |
| Share of the week's orchestrator input spent in those ten half-hours | 13 %, for 8.5 % of active time |
| Dead wall-clock in the last 36 hours | about 8 hours |

So the builders recover cheaply, because every task commits after each numbered item and the chain resumes from the worktree; the cost sits in the orchestrator re-reading state after each reset, about 5 % of the window, and above all in the hours when nothing can run. A limit that lands mid-run also kills the review or the merge in flight, which until 2.3.4 stopped the chain for the rest of the day.

What can be done about it is in the next section once the facts on Claude Code's own facilities are checked.

## Getting the same work done for fewer tokens

Patrick's reframing (23:50): wall-clock lost to a limit does not matter unless it is his; what matters is work per token, so the windows go further. The facts on Claude Code's own facilities (checked against its docs on 2026-10-06): the status line's JSON input carries `rate_limits.five_hour.used_percentage` and `resets_at` (and the seven-day pair); the terminal warns at 85 % and 90 %; `claude -p` has `--max-budget-usd`; there is no hook, setting or flag that warns earlier, waits for a reset, or reads usage from a script, and no Anthropic-endorsed pacing plugin. Extra usage at pay-as-you-go rates can be switched on at claude.ai, which removes the stops at a price.

Where the week's tokens went: builders and reviews about $980 ($173 of it reviews, four times dearer per review since the reviewer moved to Fable on 10-04); the orchestrator 4.3 M output tokens against 1.42 billion input and cache-read tokens. Every turn re-sends the whole context, so the orchestrator's standing context is the multiplier on all of its work; cold-start printed 32 KB because the plans had stacked twelve in-flight blocks, and the overnight heartbeat re-read them every 30 minutes.

Methods, ranked by expected saving:

1. **A lean orchestrator context.** One in-flight block per plan (older blocks archived to `in-flight-history.md`, done 2026-10-06 23:55), research delegated to subagents whose reading never enters the orchestrator's context, fewer and larger tool calls, and the cold-start kept short.
2. **No polling.** Chains and waits already wake the orchestrator when they finish or stop; the heartbeat is only a fallback, hourly, and reads a few lines when nothing has changed.
3. **Reviewer by track.** Opus for `Track: light` branches, Fable for visible or complex ones: about $1 against $4 a review, 108 reviews a week. The operator's call.
4. **Do not start what the window cannot finish.** The status line script writes the five-hour percentage and reset time to a file; `ws chain` holds a new dispatch above a threshold until the reset instead of having a run killed at 95 % and re-read on resume. A small tool change.
5. **Fewer partial runs.** The switch-course rule above: change the task after the second partial, not the budget. Resumes are cheap in dollars but each re-reads the task and the worktree.
6. **Builders by track.** A smaller model for research and document tasks marked light, measured on a few before it becomes the default.

## What to change

1. `ws chain`: a review that fails on the usage limit waits for the reset and retries, like a builder (tool fix, light, before tonight).
2. Three builders at once is the practical cap: beyond that the account limit stops everything, and a stop costs more than the parallelism gains.
3. The reviewer on Fable costs four times Opus. Keep it for visible or complex branches and consider Opus for `Track: light` tasks.
4. Keep measuring before choosing (the found-art lesson): it is the one orchestration error in the window that cost real money.
5. Switch course on the second partial run of one name, and on the third feel-tuning round of one page: change the task (acceptance sentence, measure first, a slider page), not the budget. Patrick's one-sentence faults go into the task as its done-when, verbatim.
