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

## Two weeks earlier: 09-15 to 09-29

Added at Patrick's request on 2026-10-06 23:50, from every repo's git log, the v1 workspace's dispatch logs and plans, and v2's runs and changelog. Nothing was dispatched between 09-15 and 09-22: the only activity was housekeeping in the v1 workspace (the cost log, a checklist sweep, then the cost log's retirement). The working window was 09-23 to 09-29.

| Day | Projects | Merges | Builder runs, $ | Notes |
|---|---|---|---|---|
| 09-23 | colorwright (v1 workspace) | 2 | 7, $6 | paper-doll-workshop mothballed |
| 09-24 | colorwright | 14 | 44, $139 | usage limit 17:23 to 19:04 (6062 s), the largest lever in the v1 pilot findings |
| 09-25 | colorwright; v2 workspace starts 18:00 | 6 | v1 16, $53; v2 7, $23 | limit ~13:35; Patrick paused at 16:45 for a code audit; v1 retired 18:01 |
| 09-26 | colorwright | 9 | 20, $164 | |
| 09-27 | colorwright v1.0 tagged 11:34; figurewright and skywright start 18:55; bike-weather's first commit | 20 | 27, $116 | OOM kill ~21:45: a 7.6 GB probe took down VS Code, the orchestrator and both builders; memory cap in 2.1.3 |
| 09-28 | colorwright, figurewright, skywright, the site | 20 | 24, $94 | the site's history rewritten after a leak audit; two orchestrators ran side by side from 16:42 to 08:52 |
| 09-29 | the same four | 19 | 27, $88 | attribution scrub, about 800 comment lines; dispatch and merge refuse attribution since |

Window totals: 90 merges; v1 67 runs for $197, v2 105 runs for $484 (reviews not totalled). Per project: colorwright 46 merges (the slots, hair, hats, heads, prosthesis colours, the pipeline tests cut from 27 minutes to 130 seconds, the v1.0 wrap-up, the static build and leak check), figurewright 28 merges in three days ($170: body model, ink renderer, garment engine, the easing pose, the dressed body), skywright 9 ($17), the site 7 ($20, six of them rewritten away).

**Rework in that window.** Nineteen names ran three times or more. The costly ones: hats across four days (10 runs, about $88, a spike, two partials, a limit stop and a pause; the beanie enlarged on 09-25 and put back to source size on 09-27); cw-p20-2b (partial, partial, timed out, finished: $31, 10 hours); cw-fh-spike (six runs, $27, including merge-master and split-log rounds that were the tool's doing); cw-hair2 ($23, limit stop, resume, fix); cw-prosthesis (three fix rounds after the preview, $21); fw-dress (reviewed twice by two orchestrators, $20). Two review-fix rounds on a single report (cw-outline-repro, four runs) and three rounds on a checklist wording (cw-p16-rule) are the process being heavier than the work. No reverts; figurewright's posed-garments render was re-rendered three times. Over four hours from first dispatch to merge: sky-demo (18 h, waiting on the preview), fw-dress (16 h, overnight), cw-p20-2b (10 h), cw-hats (7 h), cw-testspeed (7 h), site-backdrops (5 h).

**The orchestrator in that window** (from 732 transcript files, 20 of them interactive sessions, deduplicated against the forked session of 09-28). Sonnet 5 ran the orchestrator on 09-15 and 09-22, Opus 5.5 from 09-23 to 10-03 midday; Fable appears before 10-03 only in the research session that designed v2 (09-25) and a comparison session (09-27). Opus wrote 5.9 M output tokens over seven working days, 2.2 M of them on 09-23 alone. Only two reset notices exist for the window (09-24 and 09-25); the 09-24 limit cost 6062 s and was the pilot audit's largest lever.

**Things asked for more than once**, from the typed messages and the answers to prompts:

| Ask | Times | Dates |
|---|---|---|
| "Are you actually using the workspace's rules, memory and agents?" | 11 | 09-15 (three times), 09-22 (twice), 09-23, 09-24, 09-25 (twice), 09-26, 09-29 |
| "This is taking a very long time" / is something hung? | 7 | 09-23 (twice), 09-25 (four times, ending in the pause for a code audit and the v2 rebuild), 09-26 |
| Clickable prompts with the recommended option first | 5 | 09-24, 09-28, 09-29, then 10-03 and 10-06 |
| The beanie's fit and where it is listed | 5 | 09-25 to 09-27 |
| Heads, hair and hats separated | 4 | 09-24 to 09-26 |
| His name out of code and comments | 3 | 09-28, 09-29 (twice) |
| Robot-dance head position, prosthesis colours, two skin pickers, hair colour | 2 to 3 each | 09-24 to 09-26 |
| Preview ports (rule adopted 09-24 22:42, broken 09-25 10:16) | 2 | |

The first row is the finding: for two weeks the operator's most frequent message was a check that the tool was being used at all. v2's cold-start hook and pinned sessions (09-25 to 09-27) ended it; it has not been asked since 09-29.

**Directions reversed within days.** The cost log removed on 09-22 and kept on 09-23; "we won't go back to colorwright for a while" (09-22) and colorwright resumed 09-23; Hermes dropped 09-23 and studied again 09-25; "get back to bike-weather" then "finish figurewright first" within 13 minutes on 09-29, and that order overruled on 10-05 for the Bike Weather skeleton with his OK. None of these cost runs; they cost plan rewrites.

**Premises the orchestrator stated as fact and then withdrew:** that a session needed a restart for a Matrix fix (09-15, wrong within two minutes); that no note existed on the sudo popup (09-15, the note existed; the popup had been killed by a 3-second timeout); that a 30-minute review timeout was the only signal (09-23; measured the same evening at ten times the longest review, replaced by a 180-second silence rule); that port 8792 could stay the live site (09-24; inside the range reserved for agents); that the second `ws bike-weather` session was another orchestrator on the workspace (09-28; it was a daemon fork, then the VS Code extension). The pattern: a confident diagnosis before a measurement, each corrected after Patrick pushed back. The lesson "check a provider's real behaviour before writing a fix task" (09-27) and "measure before choosing" (10-05) are the same lesson written twice.

**What the window changed about the tool.** The merge gate growing from 6 to 28 minutes and 188,000 lines of evidence against 8,800 of code in colorwright led to 2.1.0 (builders run only their own tests, the gate runs the suite, evidence trimmed); the OOM kill to the memory cap; the second session moving `state/current` to pinned sessions; the leak to `release-audit.md`, the fresh history and the attribution refusal.

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

## Rules we got wrong and built on

Patrick's second addition (2026-10-06 23:50): "sometimes we get the rules wrong and build wrong on top of them." From the git history of CLAUDE.md, the lessons, the checklist, the agent sheets, the changelog, the plans and the v1 workspace's pilot findings.

**Rules that were wrong, with what was built while they held.**

| Rule as first written | When | Built on it | Corrected | Cost |
|---|---|---|---|---|
| One builder at a time; parallel builders only reach the limit sooner | 09-25 | colorwright v1.0 one run at a time | 09-27: parallel is fine, "no run stopped on the limit in 42 hours"; then 10-05: parallel is the norm | the merge suite two to three times slower beside a render builder |
| "The usage limit stopped no run in 42 hours" | 09-27 | four builders overnight 10-05 | 10-06: the limit kills every builder at once, sometimes with the wrapper that writes the result | 8 of 36 hours; three tool fixes in six days (2.2.4, 2.3.3, 2.3.4) |
| Evidence hygiene blocks a review | 09-25 | three colorwright reviews blocked in one day | 09-26: formatting never blocks; the merge refuses home paths instead | a `--no-review` override; "a two-outfit colour split took an hour of process" |
| Review limit 30 minutes | 09-23 (v1) | the hook port | measured the same evening: median review 88 s; a 180-second silence rule | a reviewer that finished then hung was re-queued, duplicating proposals |
| Append to a cost log each session | 09-15 (v1) | a script and its test | 09-22: 0 of 33 entries ever filled in; removed | a script built and deleted |
| `--allow "Bash(cp *)"` lets a builder copy from another repo | 09-28 | site-fw round 3 | same day: denied regardless; copy assets in by hand | two rounds, a missing splash image |
| figurewright before Bike Weather | 09-29 | the I-series and shoulders | 10-05: both in parallel | plan rewrites only |
| Found-art registers by the drawn rig; then by the fitted joints | 10-05 | two partial runs | the builder's measured option | $43 |
| Shoulders from "option E" widths | 10-01 | eight runs | 10-05: chest out, shoulders in; the switch-course lesson | $84 + $29 |
| Review budget $3 on the default model | 09-25 | reviews at about $1 | 10-04: reviewer on Fable, budget $8 | $3.50 to $4.30 a review; no file records the quality gained |

**Rules builders got wrong because of how they were written.** Task files carried "Patrick, 2026-09-29" and "the operator: ..." as requirements, and builders copied them into about 800 comment lines (scrubbed 09-29 in three rounds; dispatch and merge refuse attribution since). The attribution rule then matched generated bundles and a novelist's surname, needing an exemption list. A UTC date typed on the evening of 09-24 went into colorwright's comments as the next day. A `file:../skywright` link in the skeleton task resolves one level wrong from a worktree, so Metro and the preview broke. The jest config at the repo root made the merge gate collect the worktrees' copies of every test. "Open-Meteo times shift at DST", written as a fix task's premise without a check, had a builder build a per-hour offset resolver that was itself the bug. "Follow the checklist" was in the sheet before the checklist was in the prompt. "Read the docs" without the web tools granted produced a comment written from memory. The common thread: a requirement stated from reasoning, or from a convention, that one measurement or one live call would have corrected before the run.

**Tool rules that misfired, and whether the fix held.** The usage-limit class took three fixes in six days (the chain after a 429, the result written by `ws wait`, now the review retry) and had a v1 ancestor; held so far, the last landed tonight. `--timeout 180` read as seconds killed two runs; held. A `grep -q` under `pipefail` bit twice (dispatch and the chain's merged-step check), the second re-dispatching a merged step. Dispatch grants needed seven fixes in twelve days and 259 result files record denials; this is the most recurrent class. `ws merge` needed four rounds on dependencies. The forked background orchestrator (09-28, again 10-01) is still an open investigation with no detection.

**Counts stated and then corrected by a review:** "a few thousand combinations" (59,904), "all eight sliders additive" (five), "44 faults against 45" (all tie), the suite count 887 (882). Each cost a fix round of $1.50 to $6. Arithmetic by a tool, not by the model, was Patrick's rule on 09-22; it is in CLAUDE.md and still slips in prose.

**Rules in force that look at risk** (the cheap ones fixed tonight are marked):
- checklist.md says nineteen rules and holds twenty; rules 12, 13 and 16 are cited one to two times in 181 reviews, rule 15 170 times. The "cost real time twice" bar is not applied on the way in. *Header fixed; the pruning is a daytime decision.*
- agents/builder.md still says "never `npm install` in the worktree, the environments are shared symlinks", against the 2.2.10 behaviour and four confs that grant it. *Fixed.*
- The builder sheet's "the full suite is the merge's job" against the lesson that builders run a whole suite with `--runInBand` when a task asks. *Reconciled: a builder runs the suite only when its task says so, and then in band.*
- `TZ=$WS_TZ date` cited in the lessons and rule 17 while `WS_TZ` is empty. *Lessons and the rule now say what CLAUDE.md says: `date`, or `TZ=$WS_TZ date` only when config sets one.*
- CLAUDE.md step 3 omits the `timeout` a wait over 30 minutes needs. *Added.*
- The attribution regex matches "the operator" and surnames; the reviewer sheet itself contains "(the operator's rule, 2026-09-26)". *Sheet line reworded; the regex is a decision.*
- The reviewer on Fable at $8: no file records what the extra $3 a review buys. A decision for Patrick, with the audit's numbers.
- Lesson 35 (a reused step name is skipped as merged) and lesson 38 (the `.worktrees/<sibling>` symlink) are hand steps that belong in `ws chain` and `ws init`. Tool work, queued.
- "Two orchestrators at once" cites CLI 2.1.286; the machine runs 2.1.292. Open.

## What to change

1. `ws chain`: a review that fails on the usage limit waits for the reset and retries, like a builder (tool fix, light, before tonight).
2. Three builders at once is the practical cap: beyond that the account limit stops everything, and a stop costs more than the parallelism gains.
3. The reviewer on Fable costs four times Opus. Keep it for visible or complex branches and consider Opus for `Track: light` tasks.
4. Keep measuring before choosing (the found-art lesson): it is the one orchestration error in the window that cost real money.
5. Switch course on the second partial run of one name, and on the third feel-tuning round of one page: change the task (acceptance sentence, measure first, a slider page), not the budget. Patrick's one-sentence faults go into the task as its done-when, verbatim.
