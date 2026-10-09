# Crafting Guild Agentic Workspace

Build software with a small team of Claude Code agents from one folder, on projects that live in other folders.

You open one Claude Code session here and point it at a project. That session is the orchestrator: it plans, dispatches headless builders into git worktrees of the project, checks what they claim, reviews each branch once, and merges with the project's tests as the gate. Plans live in files that survive context compaction, and a twenty-second cold start runs at every session start and after every compaction, so a resumed session never guesses.

No servers, no Docker, no cron, no MCP: about 1,300 lines of shell, one small Python script and a few pages of prose.

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
