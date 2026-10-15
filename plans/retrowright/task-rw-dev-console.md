# retrowright: a developer console beside the game

Track: full

A console for poking at a running game: type a command, see the answer. It lives in retrowright only, as a side panel beside the picture like the controls and tools panels, never over the game; in full screen it is hidden. Read the README (the tools panel, the controls side panel, Tune, RAM search, save states, fast-forward, the movie player, key bindings), `src/ui/` (how the side panels are laid out), `src/core/types.ts` (`EmulatorCore`, debug hooks) and the memory map code first. Do not touch `patches/smb/` or `harness/smbSkate.test.ts`: another builder is changing them.

## Build
- **The panel:** a setting "Developer console" (off by default) and a key to show or hide it (backtick, rebindable, not taken while typing in it). A scrollback of commands and answers, an input line with history (Up/Down), Tab completion of command names, `help` and `help <command>`. Typing in it never reaches the game; Escape returns focus to the game.
- **Commands for any game:** `pause`, `resume`, `step [n]` (frames), `speed <x>` (0.25 to 4), `reset`, `peek <addr> [n]`, `poke <addr> <value>`, `watch <addr>` (shows the value each frame in the panel until `unwatch`), `save <slot>`, `load <slot>`, `screenshot`, `record`, `stop`, `replay` (the instant replay's last minute), `clear`.
- **Commands from the game's data:** where the game has a memory map (Final Fantasy) or a tunables file (the SMB skate builds), its named values work by name: `get <name>`, `set <name> <value>` (tunables write as the Tune section does), `list` names them. For SMB skate builds also: `warp <world>-<level>` (set through RAM at a safe moment, as the vine movie did, or say it is not possible), `board` (give the board and mount), `lives <n>`, `big`, `small`, `fire`, `star`, `time <n>`. Keep game-specific commands in a per-game table next to the tunables or memory map, not in the console code.
- Errors are plain sentences ("No value named ollie_pop; did you mean olliePop?").
- Tests: the parser and each command against a stub core (unit); a Firefox script on a synthetic ROM that opens the panel, pokes a value the ROM shows, steps frames, and checks the answer (add to `e2e:all`); the panel never overlaps the picture at three window sizes; `npm run a11y` with the panel open.

## Prior art
Quake-style consoles, Mesen's and FCEUX's debugger and Lua consoles, RetroArch's command interface, the browser's devtools console. Build on the existing panels and tools.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `git add`, `git commit`, `git merge *`. One command per Bash call.

## Done when
- The Firefox script passes (log); the panel sits beside the picture at three sizes and is hidden in full screen (screenshots on `.ws-evidence/page/index.html`).
- `npm test`, `npm run a11y` and `npm run build` pass. The README describes the console, its key and its commands.
