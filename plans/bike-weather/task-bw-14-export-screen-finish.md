# Bike Weather: finish back up and restore (the native pieces)

Track: light

The earlier run of `task-bw-14-export-screen.md` built the "Back up and restore" section (`src/screens/wardrobe/BackupRestore.tsx`) and ended partial because `npx expo install` was not granted; it is granted now. Run `git status` and `git log --oneline main..` first; keep what is there and read it before changing it. Finish the task below, in the same worktree.

## What to finish
1. Install, with one command, `expo-file-system`, `expo-sharing`, `expo-document-picker` and `expo-clipboard` (`npx expo install expo-file-system expo-sharing expo-document-picker expo-clipboard`), then `npm ls` each and record the installed size of each (`du -sh node_modules/<pkg>`) and its licence from its package.json.
2. Behind the existing native interface in `src/transfer/`, implement: "Share file" (write `bike-weather-wardrobe-<date>.json` with expo-file-system and open the share sheet with expo-sharing; on the web, the existing download), "Copy text" (expo-clipboard; on the web the clipboard API), "Choose file" (expo-document-picker reading the file's text). The screen's tests keep using the fake; add a test that the real implementation is selected on native and the web one on web (platform-keyed module or `Platform.OS`), without calling the packages in tests.
3. README: the back-up section names the four packages with licence and size.
4. The web export still builds (`npx expo export --platform web`, output not committed) and the whole suite passes.

## Commands
One command per Bash call, each check you cite through the evidence runner: `npx expo install <packages>`, `npm ls <package>`, `du -sh <path>`, `cat`, `npx jest --runInBand <paths>`, `npm test`, `npm run typecheck`, `npx tsc --noEmit`, `npx expo export --platform web`, `git status`, `git diff`, `git log`, `git add`, `git commit`, `git restore --source=<ref> -- <path>`, `git clean -f -- <path>`, `grep`, `ls`, `mkdir`. No plain `rm` or `mv`.

## Done when
`npm test && npm run typecheck` pass and the web export builds; the three native actions are implemented behind the interface with the selection test; the README lists the packages with licence and size; the result states the number of tests with the log it comes from (the whole suite), the four packages with licence and size, and whether `package-lock.json` changed. Commit after each numbered item.
