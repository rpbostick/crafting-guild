# Windows: what it would take

Short answer: **WSL 2 runs the harness almost unchanged today; native Windows needs a platform layer of about eight
functions across roughly 150 call sites; a rewrite is not worth it.** Every count below is a `grep` over `bin/` and
`scripts/` at v2.9.4, and you can reproduce each with the command in its row.

## What the harness needs from the operating system

| Need | Where | Count | Why it matters |
|---|---|---|---|
| A service manager with cgroups | `systemd-run --user --scope` | 12 files, 63 calls | builders, previews, chains, wakes and merges each run in their own scope with a memory cap and outlive the session |
| A persistent timer manager | `systemctl --user`, `.timer` units | 6 files | `ws autostart`, `ws wake --every`, `ws brief`, the chain watchdog |
| Session detachment | `setsid` | 12 files, 23 calls | a builder or chain that survives the terminal |
| File locks | `flock` | 11 files, 21 calls | one merge at a time, one bench per project, one suite run at a time |
| Process introspection | `/proc/<pid>/stat`, `/proc/stat` | 5 files, 19 calls | pid liveness and start time (no pid reuse), idle detection |
| Process state | `ps -o stat=` | 4 calls | zombie detection in the suite |
| Free space | `df -Pk` | 2 files, 4 calls | the disk floor before a download |
| GNU userland | `date -d`, `stat -c`, `sed -i`, `readlink -f`, `mktemp -d` | 10, 15, 5, 5, 24 files | date arithmetic, permissions, in-place edits, path resolution, scratch trees |
| Bash 4+ | `mapfile`, `declare -A` | 14 and 12 files | arrays and associative arrays throughout |
| Toolchain | git, jq, python3, GNU `timeout`, `rsync`, `shellcheck` | — | `ws doctor` checks all of them and names the fix for each |

Reproduce: `grep -rc -- 'systemd-run' scripts/ bin/` (and the same for each row's left column). The harness states the
constraint itself in `scripts/lib.sh`, where the pid and filesystem helpers are documented as Linux-only (`/proc/stat`,
systemd scopes).

## Route A: WSL 2 (recommended, and it works today)

Everything in the table exists inside a WSL 2 distribution, including systemd (`systemd=true` in `/etc/wsl.conf`, WSL
2.0 or later). Nothing in this repository changes.

1. In PowerShell: `wsl --install -d Ubuntu-24.04`, then restart.
2. In `/etc/wsl.conf` add `[boot]` and `systemd=true`; then run `wsl --shutdown` and reopen the distribution.
3. Inside WSL: `sudo apt install git jq python3 rsync shellcheck`, install one client — OpenCode
   (`npm i -g @opencode/cli`) or Claude Code (`curl -fsSL https://claude.ai/install.sh | bash`) — and run
   `bin/ws doctor`.
4. Keep the workspace and the project checkouts **inside the Linux filesystem** (for example `~/crafting-guild`,
   `~/projects/<app>`), not under `/mnt/c`. Worktree operations and the suite are much slower across the 9p mount, and
   executable permissions do not survive it.
5. Run the harness exactly as on Linux: `ws <slug>` or `ws oc <slug>`, then `/cold-start`.

The two rough edges are filesystems and terminals: use a WSL shell profile in Windows Terminal, and point
`WS_BROWSER_CMD` at the Windows browser (`cmd.exe /c start`) so `ws serve` previews open on the Windows side. A server
listening on `127.0.0.1` inside WSL 2 is reachable from Windows browsers through the loopback relay.

## Route B: native Windows (Git for Windows + MSYS2)

Git for Windows supplies bash 4.4+, GNU coreutils (`date -d`, `stat -c`, `timeout`, `mktemp -d`, `readlink -f`,
`sed -i`) and `ssh`; MSYS2 adds `flock`, `jq`, `rsync` and `shellcheck`. That covers the userland rows. What it does not
cover, and what would have to be written:

| Layer | New helper | Windows implementation | Call sites |
|---|---|---|---|
| Scopes and memory caps | `ws_scope_run <mem> <cmd…>` | `Start-Process` plus a Job Object (P/Invoke); a small helper executable is the honest option | 63 |
| Detached processes | `ws_detach <cmd…>` | `Start-Process` with a new process group | 23 |
| Killing a tree | `ws_kill_tree <pid>` | `taskkill /PID <pid> /T /F`: one forced kill, no graceful stage | ~20 |
| Locks | `ws_lock <file>` | MSYS2 `flock`; locking a `C:\` path through it is not POSIX-correct | 21 |
| Process liveness | `ws_pid_alive <pid>`, `ws_pid_start <pid>` | `Get-Process -Id` and its `.StartTime`, replacing `/proc/<pid>/stat` | 19 |
| Free space | `ws_free_kb <path>` | `Get-PSDrive` or `Get-CimInstance Win32_LogicalDisk` | 4 |
| Zombies | `ws_stopped <pid>` | there are no zombies: the check becomes "the pid is gone" | 4 |
| Timers | `ws_schedule <time> <cmd…>` | Task Scheduler (`schtasks /create`), plus a wrapper for `--every` | the wake and chain watch |
| Paths | `ws_path` | `cygpath -u` / `-w` at every boundary; git writes absolute paths into worktree metadata | many |

The helpers are small; the cost is that they sit under ~150 call sites, and the suite (~885 cases) assumes a POSIX
process model: process groups, zombies, `/proc`. Treat the port as a multi-week branch whose end state is the suite
green on both platforms, not as a week's work.

Two behaviours cannot be shimmed convincingly: **memory caps** (a Job Object can enforce one, but every launcher must
go through the helper, so an out-of-memory run fails differently) and **user timers** (`ws wake --every`, the chain
watchdog, `ws autostart`), which become Task Scheduler entries with different failure and logging behaviour.

## Route C: a PowerShell or Node rewrite

Rejected. The harness's value is in its tested behaviour — one merge at a time, a builder that outlives its terminal, a
wake that survives a reboot, a disk floor that refuses a download — and that behaviour is what the suite checks against
a POSIX process model. Route B keeps the tests; a rewrite throws them away.

## Note to an agent asked to do this

1. Read `scripts/lib.sh` first: it holds the platform assumptions (`pid_file_alive`, `worktree_root`, `disk_free_kb`,
   `load_project`). New helpers belong beside those, not scattered through their callers.
2. Do not start with Route B. Prove Route A end to end — `bin/ws doctor`, `bin/ws init` on a scratch repository, one
   `bin/ws dispatch`, one `bin/ws merge`, one `bin/ws chain` — before changing anything. If one of those fails inside
   WSL, the fault is in the environment, not the port, and you would otherwise fix the wrong thing.
3. If you are told to do Route B, work in this order and prove each step with the suite before the next:
   `ws_free_kb` → `ws_pid_alive`/`ws_pid_start` → `ws_kill_tree` → `ws_lock` → `ws_detach` → `ws_scope_run` → timers.
   The suite already fakes `systemd-run`, `opencode`, `df` and `ps` in stand-in cases; run those cases on Windows
   before writing new ones.
4. Never translate paths by string concatenation. `cygpath -u` / `-w` is the mapping between the two worlds, and git
   writes `C:\` paths into worktree metadata that a POSIX shell then reads.
5. Mark anything you could not run as `unverified` in your result. In this document, MSYS2 package availability and
   Task Scheduler fidelity are expected rather than measured here.
6. Keep the two acceptance checks the same on every platform: `bin/ws doctor` prints every dependency as `ok`, and
   `bash scripts/selftest.sh` passes.

## Note to a person installing this on Windows

- To run the harness today: install WSL 2 with an Ubuntu distribution, set `systemd=true`, install `git`, `jq`,
  `python3`, `rsync`, `shellcheck` and one client, and keep repositories inside the Linux home. Expect the tool to
  behave as it does on Linux, including previews in your Windows browser.
- Without WSL, budget weeks rather than days, and expect two permanent differences: memory caps enforced by a helper
  rather than systemd, and scheduled wakes as Task Scheduler entries. Do not start unless you can run the suite on
  Windows in CI.
- The clients are not the obstacle: OpenCode publishes a Windows build (its npm package declares `darwin`, `linux` and
  `win32`), and Claude Code runs natively on Windows 10 1809 or later, with or without Git for Windows. The harness's
  process model is the obstacle.
- Verify in this order: `bin/ws doctor` (every line `ok`), then `bash scripts/selftest.sh` (it ends `selftest passed`).
  If both are green, a port is real; if not, nothing above matters yet.
