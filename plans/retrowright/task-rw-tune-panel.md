# retrowright: Tune gets its own panel; developer tools behind the Developer setting

Track: full

Resume: an earlier run of this task was cut off by the usage limit. Its work is in the worktree (`git status`, `git log --oneline main..`); read it and keep what fits.

Players who tune a game's feel find the Tune sliders at the bottom of the F4 tools panel, under RAM search, the watch list and the memory viewer, which are developer tools most people never need. In play: "i'm not sure who the tools panel is for, but it doesn't look very useful to most people. where is the tuning panel?" Read the README (Tools, Tune, the developer console, the controls side panel, Display and speed), `src/ui/` (the panels and their layout), the quick menu and the key bindings first. Do not touch `patches/smb/` or `harness/smbSkate.test.ts`: another builder is changing them.

## Build
- **A Tune panel:** a quick-menu item "Tune…" and a key (F3, rebindable) open a side panel beside the picture with only the Tune section (sliders, lists, Save as new version, reset), for any game with a bundled tunables file. It sits beside the picture like the other panels and never covers it; hidden in full screen. Offered only when the game has tunables.
- **Developer tools behind the Developer setting:** rename the Display setting "Developer console" to "Developer tools" (keep the old saved value working). With it off, the menu offers no "Tools…", F4 does nothing, and the console is hidden. With it on, F4 opens the tools panel with RAM search, the watch list and the memory viewer (Tune no longer in it) and backtick opens the console.
- Panels stack sensibly when several are open (controls, Tune, tools, console): say how; never over the picture.
- Update the e2e scripts (`e2e:tune`, the tools and console scripts, a11y) for the new places, and the README.
- Tests: the menu offers Tune only for a game with tunables; F3 opens it; with Developer tools off there is no Tools item and F4 does nothing; the old setting migrates.

## Prior art
The existing panels. Emulator front ends that separate player options from debug tools (Mesen's Tools menu, RetroArch's core options versus its developer settings).

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `git add`, `git commit`, `git merge *`. One command per Bash call.

## Done when
- The tests above pass; `npm run e2e:tune`, the console and tools scripts, `npm run a11y` and `npm run build` pass; `npm test` passes (logs). Screenshots of the Tune panel beside the game at three sizes on `.ws-evidence/page/index.html`.
