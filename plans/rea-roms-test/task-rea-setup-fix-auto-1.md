# Fix round 1 for `task-rea-setup.md`

The review of this branch at 3a3e0ca found blocking issues. Fix each one, with a test where the finding is about behaviour, commit, and re-run the covering test files through ws-run. Do nothing else; suggestions are carried to a later task.

## Blocking findings
- `scripts/install-ghidra.sh:3` (rule 3): The header says 'Every download is checked against a SHA-256 before it is unpacked'. That is false for the two source builds. Ghidra's support/gradle/gradlew downloads gradle-9.7.1-bin.zip, and its gradle-wrapper.properties has no distributionSha256Sum. The ghidra-snes build also pulls Gradle plugins with no checksum. Either state that only the JDK, the Ghidra zip and prebuilt extension zips are checksummed (sources are pinned by git commit; Gradle and plugin downloads are not checked), or pin them.
- `README.md:17` (rule 3): Same false claim in the user-facing docs: 'three Ghidra extensions, each download checked against its SHA-256'. GhidraNes and ghidra-snes are fetched by git commit and built with Gradle downloads that are not checksummed. Reword it to match the script.

## The original task (for context)
## rea-roms-test: REA safety checks and live install, plus Ghidra and console loaders

Track: light

REA (github.com/morluto/rea, MIT) inspects native code through Ghidra. This project uses it on NES, SNES and GBA ROMs. REA is installed live from its GitHub main branch, never pinned, so every install must pass our own automated safety checks before any of its code runs. Never run REA's `setup` command: it writes agent configuration globally. This project gets REA through its own MCP config file instead.

Everything is installed under a prefix directory given as an argument (after the merge it will be `$HOME/tools`). In this run, use `.ws-evidence/tools` in the worktree as the prefix. Scripts must not contain absolute home paths or a username.

### 1. `scripts/check-rea.sh <rea-checkout> <state-dir>`: the safety checks
Runs on a fresh clone before any install. Exits non-zero on any failure, prints a report, and writes it to `<state-dir>/check-<commit>.txt`.
- Records the commit SHA and date. When `<state-dir>/last-checked` holds an earlier SHA, lists the files changed since then in sensitive places: `install.sh`, `scripts/`, setup code, `package.json`, lockfiles, `bridge/`, `native/`.
- **Lifecycle scripts:** lists every package in the root lockfile with `hasInstallScript: true`, plus REA's own `preinstall`/`install`/`postinstall`/`prepare` scripts. Fails on any that is not in `checks/rea-allowlist.txt` (committed, one entry per line with a reason).
- **Network hosts:** lists every hard-coded `http(s)://` host in REA's own source (`src/`, `scripts/`, `bridge/`, `native/`; not tests, docs or fixtures). Fails on a host not in the allowlist file.
- **Agent configuration writes:** lists code that writes to agent config locations (`.claude`, `.codex`, `.cursor`, `.gemini` and similar) or to shell profiles. Report only: these belong to `setup`, which we never run.
- After the install, `npm audit --omit=dev`: fails on a high or critical advisory, unless the allowlist names it.
- Seed `checks/rea-allowlist.txt` from today's main branch, with a reason per entry. Keep it short; anything doubtful goes in the result's open questions rather than the allowlist.

### 2. `scripts/install-rea.sh <prefix>`
Shallow-clones main into `<prefix>/rea` (or fetches and resets an existing clone), runs `scripts/check-rea.sh`, and stops if that fails. Only then: `npm ci --ignore-scripts` and REA's build. Writes `<prefix>/rea-mcp.json`, an MCP config for `claude --mcp-config` that starts the local build's MCP server with `GHIDRA_INSTALL_DIR` and `JAVA_HOME` set. On success, records the commit in `<state-dir>/last-checked` (the state dir is `<prefix>/rea-state`).

### 3. `scripts/install-ghidra.sh <prefix>`
- A user-local JDK 21 (Eclipse Temurin, from api.adoptium.net, checksum verified) into `<prefix>/jdk-21`. The machine has no Java, and installing it system-wide is not allowed.
- Ghidra 12.1.4 (REA accepts 12.1.x) from the NationalSecurityAgency/ghidra GitHub release `ghidra_12.1.4_PUBLIC_20260921.zip`, checked against SHA-256 `ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db`, into `<prefix>/ghidra_12.1.4_PUBLIC`.
- Loaders: **GhidraNes** (kylewlacy/GhidraNes; its newest prebuilt zip is for Ghidra 12.1, not 12.1.4) and **gba-ghidra-loader** (pudii/gba-ghidra-loader, Apache-2.0; prebuilt for 12.0.2 only). Ghidra refuses an extension whose version is not its own. Build each from source against 12.1.4 if that works within about 10 minutes; otherwise install the nearest prebuilt with its `extension.properties` version changed to 12.1.4. Record which method each one used.
- **SNES (65816):** stock Ghidra has no 65816 processor. Spend at most 10 minutes finding a maintained 65816 processor module or SNES loader for Ghidra 12. Install it if one works; otherwise report what exists.

### 4. Smoke run
With prefix `.ws-evidence/tools`: run `install-ghidra.sh`, then `install-rea.sh`. Then use REA's CLI (`node <prefix>/rea/scripts/rea.mjs …`; read `docs/cli.md` in the clone) to open one GBA ROM and one NES ROM through Ghidra and list their functions or entry points. The ROMs are under `research-files/` (a link into the main checkout): `research-files/GBA ROMs/Final_Fantasy_V_Advance_USA.gba` and `research-files/NES ROMs/Final_Fantasy_USA.nes`. Save the output under `.ws-evidence/`. Never copy ROM bytes or disassembly into committed files. Set `GHIDRA_HEADLESS_MAXMEM=2G`: the machine has 14 GB and no swap.

### 5. Tests
`tests/run.sh` runs every `tests/*.test.sh` and exits non-zero if any fails (plain bash, no framework). `tests/check-rea.test.sh` builds tiny fake REA checkouts under a temp dir and shows that the check passes a clean one and fails on: an unlisted install script, an unlisted host, and an audit failure (stub `npm` on `PATH`). The installers' download and checksum logic is tested with a stubbed `curl`: a wrong checksum stops the install. `shellcheck` is clean on `scripts/` and `tests/`.

### Prior art
REA's own `setup --dry-run` and `doctor` (we use neither for installing, but read them for what they check). npm's `--ignore-scripts` and `npm query ":attr(scripts, [postinstall])"`. Ghidra's extension install (copying into `Ghidra/Extensions`, or `<ghidra>/support/buildExtension.gradle`). Nothing to reuse for the allowlist check; it is a short script.

### Commands
`git clone *`, `git -C .ws-evidence/tools/rea log -1`, `git -C .ws-evidence/tools/rea fetch *`, `curl *`, `sha256sum *`, `unzip *`, `tar *`, `npm ci --ignore-scripts`, `npm run *`, `npm audit *`, `npm query *`, `npm ls *`, `node *`, `bash scripts/*`, `bash tests/*`, `shellcheck *`, `find *`, `du -sh *`, WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call. Never run an npm install without `--ignore-scripts`. No `sudo`.

### Done when
- `scripts/check-rea.sh`, `scripts/install-rea.sh`, `scripts/install-ghidra.sh`, `checks/rea-allowlist.txt`, `tests/run.sh` and `tests/check-rea.test.sh` are committed; `bash tests/run.sh` passes and `shellcheck` is clean.
- The check passes on today's REA main and the report is in `.ws-evidence/` (commit SHA, install scripts, hosts, audit).
- JDK 21, Ghidra 12.1.4 and the NES and GBA loaders are installed under `.ws-evidence/tools`, each loader's install method recorded; the SNES finding is reported.
- REA opened the GBA and NES ROMs through Ghidra and the output is saved, or the result says exactly what stopped it, with the log.
- `README.md` says how to install (`bash scripts/install-ghidra.sh "$HOME/tools"`, then `install-rea.sh`) and how to start Claude Code with `--mcp-config`.
