# Crafting Guild

Crafting Guild Agentic Workspace: build software with a small team of Claude Code agents from one folder, on projects that live in other folders.

You open one Claude Code session here and point it at a project. That session is the orchestrator: it plans, dispatches headless builders into git worktrees of the project, checks what they claim, reviews each branch once, and merges with the project's tests as the gate. Plans live in files that survive context compaction, and a twenty-second cold start runs at every session start and after every compaction, so a resumed session never guesses.

No servers, no Docker, no cron, no MCP: about 1,300 lines of shell, one small Python script and a few pages of prose.

## Why use it

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

### Compared with the alternatives

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

## Requirements

- Linux or macOS with `bash`, `git`, `jq`, GNU `timeout` and `python3`
- [Claude Code](https://code.claude.com) CLI 2.1.257 or later, signed in
- Optional: systemd user scopes (Linux), so builders and previews run under a memory cap (`WS_BUILDER_MEM`, `WS_SERVE_MEM`) and a chain survives the session that started it
- Optional: `gh`, for `ws release` to attach a build to a GitHub release; `rsync`, for `ws site`

## Install

```bash
git clone <this repository's URL> ~/crafting-guild
ln -s ~/crafting-guild/bin/ws ~/.local/bin/ws          # or add bin/ to your PATH
bash ~/crafting-guild/scripts/selftest.sh              # checks the scripts against a throwaway repo
```

## Register a project

```bash
ws init ~/code/my-app                       # guesses the test command and tool grants
$EDITOR ~/crafting-guild/projects/my-app.conf     # check TEST_CMD, EXTRA_TOOLS, PREVIEW_CMD
ws my-app                                   # opens Claude Code here with the project attached
```

`projects/example.conf.sample` shows every key a conf can hold. A project without tests can be registered; its merges run without a gate until `TEST_CMD` is set. Then tell the orchestrator what you want built: `CLAUDE.md` and the cold-start context give it everything it needs. If you skip `ws init`, it asks which repository to work on and registers it.

## The loop

```
you:    add a hat slot to the avatar editor, with its own colour
agent:  writes plans/my-app/hats.md: three steps, each a task file
agent:  ws dispatch hats-1 plans/my-app/hats-1.md      (a builder in .worktrees/hats-1, $10 cap)
agent:  ws wait hats-1                                  (in the background; you can keep talking)
        ...
agent:  result: done, 2 commits, 41 tests passed, log present, no denied calls
agent:  ws serve hats-1 -> http://127.0.0.1:8801/  "have a look"
you:    looks right, merge
agent:  ws review hats-1  -> merge, no blocking findings, 2 suggestions carried forward
agent:  ws merge hats-1 3f2a9c1  -> tests passed, pushed, worktree removed
```

1. **Plan** in `plans/<slug>/`: small independent steps, each a task file a builder can run cold, each with a done-when.
2. **Dispatch** one builder per step into its own worktree and branch, with a dollar budget, a wall-clock cap and a grant of exactly the commands it needs.
3. **Wait**, then read the checked result: claimed commits must exist on the branch, a claimed test log must be where it says, and denied calls are listed whether or not the builder mentions them.
4. **Preview** a visible change from the worktree.
5. **Review** the whole branch once against `checklist.md`, after a mechanical precheck. Blocking findings go back to the builder; suggestions carry forward.
6. **Merge** the reviewed SHA: the project's tests run on the merged tree, a red suite undoes the merge, a green one pushes.
7. **Chain** sequential steps (`ws chain <queue>`), which runs 2, 3, 5 and 6 unattended and stops only for what needs a person.

Builders never push and never touch the main checkout.

## Commands

`ws help` prints them all. The main ones:

| Command | What it does |
|---|---|
| `ws <slug>` | open an orchestrator session for a registered project |
| `ws init <path> [--tests CMD] [--branch B]` | register a project |
| `ws list`, `ws status [slug]` | registered projects; cold-start by hand |
| `ws dispatch [--budget N] [--timeout T] [--model M] [--effort E] [--allow RULE]... <name> <task-file>` | run a builder (`--dry-run` or `--print-prompt` to see what it would get) |
| `ws wait <name>`, `ws tail <name>`, `ws runs`, `ws stop <name>` | wait for, watch, list, stop runs |
| `ws serve <name\|main> [port]`, `ws serve stop [name]` | preview server from a worktree or the main checkout |
| `ws review <name>`, `ws precheck <name>` | review the branch (prints the verdict and the SHA to merge); the mechanical checks alone |
| `ws merge <name> <sha>` | merge a reviewed branch, run the tests, push on green, clean up |
| `ws chain <queue>`, `ws chain-wait` | run a queue of steps unattended; wait on a running chain |
| `ws audit [days]` | what builders keep doing by hand, from the run logs |
| `ws release [--dry-run]` | publish main (or its `RELEASE_PATHS`) as one audited commit on a public repository |
| `ws site [--dry-run]` | copy a project's published files into a site project, test, push, wait until live |
| `ws --project <slug> <command> ...` | act on a registered project other than the selected one |

## Configuration

- `config.sh`: budgets, timeouts (45m for a task marked `Track: light`, 120m otherwise), models, memory caps, timezone, preview ports, the browser command `ws serve` suggests, and `WS_ATTRIBUTION_RE` (names a merge refuses to add to a repository).
- `config.local.sh` (optional): sourced after `config.sh`, for values you keep private, such as your own names in `WS_ATTRIBUTION_RE`.
- `projects/<slug>.conf`: one per registered project (path, branch, `TEST_CMD`, `EXTRA_TOOLS`, `PREVIEW_CMD`, release and site settings).
- `checklist.md`, `agents/*.md`, `lessons/*.md`: the review rules, the three roles and the lessons pasted into every prompt.

## What stays private by design

The workspace keeps your working material beside the tool, and none of it is meant to be published:

- `plans/`: plans and task files, kept here so product repositories carry only product
- `runs/`, `state/`: logs, results, reviews, builders' evidence, the selected project (gitignored)
- `projects/*.conf`: your projects' paths and settings
- `*.local.md`: `CLAUDE.local.md` (your preferences for the orchestrator) and `lessons/<role>.local.md` (lessons that name your projects, people or dates), loaded after the shared files when present
- `config.local.sh`: your private settings

`.gitignore` ignores only `runs/`, `state/` and logs (`*.log`), so a private copy of the workspace can track the rest; add `*.local.md`, `config.local.sh`, `plans/` and `projects/*.conf` to it if you keep a public fork.

## Changing the tool

[MODIFYING.md](MODIFYING.md) explains every file and where to change what. After a change, `bash scripts/selftest.sh`.

## License

MIT. See [LICENSE](LICENSE).
