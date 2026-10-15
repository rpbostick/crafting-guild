# retrowright: watch the bot play in retrowright

Track: full

The search bot (`harness/bot/`, README "Search bot") saves its winning run as a `.rwmovie.json`. Let the operator watch it in the app: a labelled link that opens a build and plays the movie from power-on. Read the README's Record and replay and test-links sections, `src/movie/`, the `?play=` / `?label=` / `?controls=` handling (`e2e/testLinks.mjs` and the code it tests) and `harness/bot/` first. Another builder is changing `patches/smb/`, `harness/smbSkate.test.ts` and the README's SMB section: do not touch them.

## Build
- **A movie link:** `?play=<rom>&movie=<path>` (beside `label` and `controls`) loads the ROM and plays the movie from its start in the app's movie player, with the usual pause and stop. Movies are served like ROMs: from `local-movies/` under the same local folder rule as `local-roms/` (`RETROWRIGHT_TEST_ROMS` or the configured folder), never committed. A movie for a different ROM (its hash) shows the player's existing mismatch message.
- **Bot output for watching:** `npm run bot -- ... --watch-name <name>` (or always) also writes the movie where the link can reach it, and prints the link with a label naming the build, mode, and frames to the flag.
- **While it plays:** the movie's frame counter and its checkpoints are shown as the player shows them today; nothing new is needed unless the player has no visible frame count, in which case add one.
- Tests: the link parsing and the mismatch path (unit); a Firefox script on a synthetic ROM and a synthetic movie that the link plays to its end with the right final frame hash (add to `e2e:all`).

## Prior art
The app's movie player and test links as they are; emulator front ends' "play movie from command line" (FCEUX `-playmov`, Mesen's `--movie`).

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The Firefox script plays a synthetic movie through the link to its end (log); `npm test`, `npm run a11y` and `npm run build` pass. The README describes the movie link and the bot's printed link.
