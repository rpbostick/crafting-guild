# Tool calls and denials

Every command an agent runs goes through one client's own tool loop: the client offers the tools, the model
chooses a call, the client checks it against a permission and returns either the result or a refusal. This page
says which tools each role gets, where that list is defined, how a model chooses, and what a denial is for. Claims
about the code name the file and the symbol in it, never a line number: a line moves with every edit above it, and a
symbol name survives.

## The contract

The harness never runs a tool loop of its own. `ws dispatch` assembles one prompt, one grant list, one budget,
one wall-clock cap, one working directory and one result schema, and hands all of it to whichever client is
configured:

- Claude Code: `claude -p "<prompt>" --allowedTools "${TOOLS[@]}" --disallowedTools "${DENY[@]}" ...`
  (the `claude -p` command built in `scripts/dispatch.sh`).
- OpenCode: the same two arrays become a permission config the launcher hands the client in
  `OPENCODE_CONFIG_CONTENT`: the config build and the `cmd=(...)` launcher call in `scripts/dispatch.sh`, the
  `OPENCODE_CONFIG_CONTENT` setting in the two line branches of `scripts/opencode-builder.sh`, and `build_config` in
  `scripts/opencode_run.py` writing the permissions.

The two lists are shell arrays in one file: `TOOLS` and `DENY` in `scripts/dispatch.sh`, with the `interpreter_deny`
loop below `DENY` adding the interpreter code-option rules.

| In this workspace | Claude Code form | OpenCode form |
|---|---|---|
| `Read`, `Grep`, `Glob` | tool names in `--allowedTools` (the first entries of `TOOLS`) | `read`, `grep`, `glob`, `list` and `lsp` allowed, `codesearch` denied (`FIXED` in `scripts/opencode_run.py`) |
| `Edit(./**)` | a path-scoped allow entry in `TOOLS` | `edit` allowed only inside the project directory; `external_directory` is denied, and edits outside it fail (the `edit` value in `build_config`, `scripts/opencode_run.py`) |
| `Bash(git status*)` | a `Bash(<pattern>)` glob; `*` spans spaces, so the pattern covers the subcommand and its arguments (the `Bash(...)` entries in `TOOLS`) | `bash` starts at deny and each pattern is added as an allow (`build_config` in `scripts/opencode_run.py`); 2.x spells the action `shell` and builds an ordered rule array instead (`permission_rules` in `scripts/opencode_run.py`) |
| `Bash(git push *)` in `DENY` | `--disallowedTools`, which wins over every allow (the `claude -p` command in `scripts/dispatch.sh`) | written after every allow, because OpenCode applies the last matching rule (the deny loop at the end of `build_config`) |
| a quoted spelling, `python3 "-c" 1` | matched as Claude Code matches it | OpenCode keeps the quotes when it matches, so the deny guard re-tests the command text with its quoting removed (`simpleCommands` in `scripts/opencode-plugins-2x/deny-guard.js`) |
| `bin/ws-run` | the evidence runner | the same, and it reads the same two files (the deny and grant checks in `bin/ws-run`) |

A grant in the "grant file" form is the pattern without the `Bash(...)` wrapper and without quotes, because
`bin/ws-run` matches the words the shell already passed it (the `RUN_GRANTS` write in `scripts/dispatch.sh`, and
`cmd="$*"` in `bin/ws-run`).

## Who gets what

| Role | What it gets | Where |
|---|---|---|
| builder | 69 entries: `Read`, `Grep`, `Glob`, `Edit(./**)` and 65 `Bash(...)` patterns, plus the project's test command, `EXTRA_TOOLS`, `--allow`, `bin/ws-run`, and the grants the task's `## Commands` derives | the `TOOLS` array in `scripts/dispatch.sh` and its `EXTRA_TOOLS`, `--allow` and `bin/ws-run` appends below it |
| builder, refused | 614 deny patterns: 44 written out in the list, and 570 built by the interpreter loop (three per code option and two per bundle that carries one, so 285 rules, each written direct and with a `*/` path) | the `DENY` array in `scripts/dispatch.sh` and the `interpreter_deny` loop below it |
| reviewer | 17 tool rules on 1.x (`READONLY_FIXED`: four read tools allowed; edit, write, web, task, skill, question and the rest denied) and 16 on 2.x (`READONLY_FIXED2`: `subagent` in place of `task`, and no `write` rule), with ten shell patterns and three denials among them | `READONLY_FIXED`, `READONLY_BASH` and `READONLY_FIXED2` in `scripts/opencode_run.py`, built by `run_pass` in `scripts/review.sh` |
| reviewer, Claude | `--restricted`, a read-only tool set of its own | the Claude branch of `run_pass` in `scripts/review.sh` |
| orchestrator | a shell allowed by default with ten destructive forms asking first; `external_directory` with one `ask` and an allow per registered project checkout and each of its worktrees, plus `/tmp`; edits denied on the memory directory; the `task` tool denied; the browser MCP | the `bash_rules` loop, the `external` and `edit_rules` blocks and `browser_mcp` in `scripts/opencode-perms.sh`, loaded by the `oc` case in `bin/ws` |
| orchestrator, the rest | edit, `question`, `skill` and the web tools are whatever the client offers; the orchestrator's config only narrows that | the `jq` merge at the end of `scripts/opencode-perms.sh` |

The reviewer's shell patterns are ones a builder can run as well; what differs is its tool map and its three
denials: its read tools are four and everything that writes, fetches or spawns is denied (`READONLY_FIXED` on 1.x,
`READONLY_FIXED2` on 2.x), its shell grants are named one by one (`READONLY_BASH`), and its three denials come last
so a `--output` or a redirect stays refused even when an allow matches its prefix (`READONLY_BASH_DENY`, added after
the allows in `build_readonly_config`).

## How a model chooses

Nothing in the harness picks a tool; the model does. The harness sets what is possible and what must be shown,
and the four inputs below are the whole of that:

- **What exists.** A tool is available only if the client's permission map allows it: builder (`FIXED` on 1.x,
  `FIXED2` on 2.x), reviewer (`READONLY_FIXED` on 1.x, `READONLY_FIXED2` on 2.x), orchestrator (the `jq` merge in
  `scripts/opencode-perms.sh`). A tool that is not in the map is not a choice.
- **The role sheet.** It is the first section of the prompt, before the checklist and the task (the `prompt`
  assignment in `scripts/dispatch.sh`); for a builder it states one command per Bash call, that scratch files stay
  out of the source tree, and what a refusal means (`agents/builder.md`, the one-command-per-Bash-call, scratch-file
  and refusal bullets).
- **The task.** Its `## Commands` section is what the grants are derived from (the derivation loop and `derive` in
  `scripts/dispatch.sh`) and its done-when is what the result is checked against (the done-when block in
  `scripts/check-result.sh`).
- **The denial path** below, which turns a refused call into a named gap rather than a silent one.

## Denials as teaching, not only as a fence

A denial has four stages, and each one is a chance for the next task to be easier.

### 1. Before the call

`## Commands` is read out of the task, each backticked entry becomes a grant by its first word (or its first two
for `npx`, `npm`, `node`, `python3`, `python` and `git`), and every entry that grants nothing is listed with the
shape that would run instead: `bash scripts/t.sh` is granted as written rather than as `bash *`, and a bare
`bash *`, an interpreter with its own `-c`/`-e` option, or a path above the worktree is refused (`grant_name`,
`bare_entry`, `shell_pattern`, `interp_pattern` and the `./`-stripping block in `scripts/dispatch.sh`, whose reason
is `outside_refusal`). The refusals are printed at dispatch (the `not granted:` note in `scripts/dispatch.sh`) and
pasted into the prompt under "Commands refused" (`refused_note`).
A compound entry gets its own warning, because a pipe or `&&` is denied as one call even when both halves are
granted (the compound-entry warning in `scripts/dispatch.sh`). An entry the task forbids but an existing grant still
runs is named as covered instead of refused, so the prompt does not claim a narrowing that did not happen
(`covered_by_grant` and the `covered` loop in `scripts/dispatch.sh`).

### 2. At the call

The client refuses a command that matches no allow rule, and the deny list wins over every allow. On OpenCode the
deny guard re-tests the deny list on the unquoted command and throws a refusal that names the closest grant
(`simpleCommands` and the `execute.before` hook in `scripts/opencode-plugins-2x/deny-guard.js`; its
`tool.execute.before` hook in `scripts/opencode-plugins/deny-guard.js` on 1.x). The name comes from one rule, shared
by both guards and the evidence runner: the grant whose pattern shares the longest run of the command's own words,
or "no grant covers this" (`closestGrant` and `grantSuggestion` in `scripts/grant-suggest.js`). `bin/ws-run` refuses
the same way, and for the same reason: it adds no permission a builder did not already have (the deny check and the
grant check in `bin/ws-run`).

### 3. After the run

The run-events plugin records every `permission.asked`/`permission.replied` pair into the run's events file
(the `permission.asked` and `permission.replied` cases of the event switch in
`scripts/opencode-plugins-2x/run-events.js`; the same two cases in `scripts/opencode-plugins/run-events.js` on 1.x).
`scripts/check-result.sh` merges those records with the client's own denial list, deduplicated by tool and input,
and prints the count and the first calls (the denial-merge block in `scripts/check-result.sh`). `ws wait` then prints
the result followed by the denial summary, each refused call with the grant it needed (the `wait` case in `bin/ws`,
which runs `scripts/denied-summary.py`).

### 4. Across runs

A denial that names a grant is a fix the orchestrator makes in the next task: name the command that way in
`## Commands`, or pass it with `--allow`. A denial that keeps recurring becomes a default grant. The read-only
probes in the default list are that loop written down: command lookup, printed versions, `jq`, `echo`, `sort`,
`du`, and the four system checks `free`, `df`, `nproc` and `uptime` were each added after a run was denied them
(the probe entries at the end of `TOOLS` in `scripts/dispatch.sh`, and the interpreter note above `interp_combos`).
`ws audit` groups the denials the runs recorded by reason, which is where the next default grant comes from
(`denied_calls` in `scripts/audit.py`).

### What a denial cannot do

- **A builder cannot grant itself anything.** The grant and deny files are written outside the worktree, at
  dispatch, and the evidence runner reads them from its environment (the `RUN_GRANTS` and `RUN_DENY` writes in
  `scripts/dispatch.sh`, and the `WS_RUN_GRANTS` and `WS_RUN_DENY` reads in `bin/ws-run`), so the list it is checked
  against is not a file the builder can edit. The client's permission map is also fixed at dispatch: on OpenCode the
  file tools are bounded by `external_directory: deny` (`FIXED`), and with `WS_SANDBOX=bwrap` the shell runs under a
  wrapper (the `WS_SANDBOX` block in `build_config`). This install leaves `WS_SANDBOX` empty (`config.sh`, where the
  variable is defined), so the boundary is the fixed map and the files' location. A deny rule is written after
  every allow, so a broad grant cannot re-open it (the deny loop in `build_config`).
- **A denial that names no grant is a lost turn.** "No grant covers this" tells a model which shape is missing,
  not which one to use; the builder sheet tells it to report that in `open_questions` rather than retry
  (`grantSuggestion`'s "no grant covers this" branch in `scripts/grant-suggest.js`, and the refusal bullet in
  `agents/builder.md`).
- **The teaching reaches the next task through `ws wait` or `ws audit`, not by itself.** The refusal text is in
  the run log and the summary is one line of `ws wait`'s output (the `wait` case in `bin/ws`); `ws audit` groups the
  denials the runs recorded by reason with no orchestrator step, so a recurring gap is named for the next default
  grant (`denied_calls` in `scripts/audit.py`).
- **The deny list is a backstop, not the boundary.** A broad grant such as `Bash(node *)` from `EXTRA_TOOLS` or
  `--allow` stays usable except where a deny pattern narrows it, and a glob cannot see where an interpreter's
  options end, which is why the patterns are written the way they are (the `DENY` array and the interpreter note
  above `interp_combos` in `scripts/dispatch.sh`).

## Keeping it true

The builder counts on this page (the tool entries, shell patterns and deny patterns) are copied from `TOOLS` and
`DENY`, and the suite holds them: its `docs/tool-calls.md's counts match dispatch.sh` case reads the two arrays and
fails when a number drifts (the counts case in `scripts/selftest.sh`). The reviewer and orchestrator counts are
copied by hand from the permission maps named beside them, and no case reads those maps. A change to `TOOLS`,
`DENY`, the `## Commands` derivation or either permission map (`scripts/opencode_run.py`,
`scripts/opencode-perms.sh`) updates this page in the same branch; `MODIFYING.md` lists where each of those lives.

Cite the symbol, not the line. A line number moves with every edit above it, while the array, function, flag or
case name it pointed at survives a merge that only shifts code; a change to a cited mechanism therefore re-reads
its sentence and the terms it uses, where a number would only be checked for still landing somewhere. A sentence
that no longer matches the symbol is the defect to fix, and a moved line is not.
