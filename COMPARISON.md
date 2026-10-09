# Why Crafting Guild, and when not to use it

Claude Code on its own is already a capable agent. What it doesn't give you is the layer above the agent: a way to split a build into steps, run each step in a fresh context, check what the agent says it did, and keep untested work off your main branch. That layer is what Crafting Guild is.

**The problem it solves: one long session doesn't scale to a whole app.** A session that builds an app by editing directly fills its own context with every file it read, every test run and every failed attempt. Then it compacts, forgets, and repeats itself. On the first app built this way, a session editing directly compacted 8 times in 25 hours and drew 17 "still broken" reports. The session that dispatched builders instead compacted twice in three days and drew none. Crafting Guild keeps the orchestrator's context small by design: each builder works in its own process and worktree, and only a checked result file comes back.

**What you get over plain Claude Code:**

- **A fresh context per step.** Each task file runs cold in a new builder, so step 12 is as sharp as step 1.
- **A gate before main.** Every branch is reviewed once against a short checklist, and merged only at the reviewed commit, with your test suite run on the merged tree. A red suite undoes the merge. `/code-review` in plain Claude Code reports; here the review and the tests decide.
- **Claims checked, not trusted.** Commits a builder says it made must exist on its branch, test logs must be where it says, and every denied tool call is listed.
- **Limits per run.** Each builder has a dollar budget, a wall-clock timeout, a memory cap, and exactly the shell commands its task names.
- **Work that outlives the session.** `ws chain` runs a queue of steps detached from the terminal and resumes after a restart. Plans and results are files, so a new session picks up where the last one stopped.
- **Releases and deploys.** `ws release` publishes an audited, fresh-history copy to a public repository. `ws site` copies built files into a site, checks every byte, and waits until it is live.

On its first app it took a project from a paused fix to a tagged v1.0 in 42 hours: 37 builder runs, 22 reviews and 22 gated merges, with no compactions in a 25-hour orchestrator session and no usage-limit stops.

**What you give up:**

- **Immediacy.** A one-line fix in plain Claude Code takes seconds. Here a change is a task file, a builder run, a review and a merge: minutes and a few dollars. Small edits are still fine to make directly in the session.
- **Watching each edit.** You review branches, not keystrokes. The VS Code extension's inline diffs are the better place to read and accept a change line by line.
- **Per-call control in code.** Grants are command patterns, and a missing one is a silent denial (the task names every command it needs). The Agent SDK's permission callbacks and hooks are finer.
- **Portability.** It is shell for Linux or macOS. The memory caps and the detached chain use systemd user scopes. It is a tool for one person at a terminal, not a service.

## Compared with the alternatives

| | Claude Code in a terminal | Claude Code in VS Code | Crafting Guild | Agent SDK, your own program |
|---|---|---|---|---|
| Setup | None | The extension | Clone, `ws init`, `ws <slug>` | Write the orchestration yourself |
| Best at | Questions, debugging, quick fixes | Reading and accepting changes line by line | Building an app over many steps | Services, CI, agents inside products |
| Parallel work | Subagents, workflows, background sessions | Subagents and background tasks | Headless builders, each in its own worktree | As wide as you code it |
| Fresh context per step | Partly: subagent summaries return to the session | Same | Yes: only a checked result file returns | If you design it |
| Gate before main | None; review reports but does not block | None | Review verdict at a pinned commit, plus your tests on the merged tree | Yours to build |
| Agent's claims checked | No | No | Commits and test logs checked against the branch | Yours to build |
| Survives the session closing | Background sessions until shutdown | No | Detached chain that resumes after a restart | Yours to build |
| Per-run budget, timeout, memory cap | Budget for headless runs only | No | All three, every builder | Budget and turns; the rest yours |
| Control of each tool call | Permission modes, hooks | Same | Command patterns per task | Callbacks and hooks in code |

**Use plain Claude Code** when you can watch the work and check it by eye. **Use Crafting Guild** when the work outgrows one session or your attention: many steps, several builders, unattended runs, a main branch that must stay green. **Use the Agent SDK** when the orchestrator should be a program, not a person: a service, CI, or an agent inside a product. They combine. The orchestrator here is itself Claude Code in a terminal, and nothing stops you from reading a builder's branch in your editor.

**Billing:** Crafting Guild drives the `claude` CLI, so it uses whatever Claude Code is signed in with. Anthropic's terms treat a subscription as individual use; a product you offer to others should use an API key.
