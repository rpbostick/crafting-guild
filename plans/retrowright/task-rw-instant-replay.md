# retrowright: instant replay, save the last minute as a movie

Track: full

When a player spots a bug, recording starts too late: by then the moment has passed. Keep a rolling buffer while playing, so one key saves a movie of the last minute that replays exactly. Also fix a recording that came out empty. Read the README's Record and replay section, `src/movie/`, the movie recorder and player, the save-state code, the quick menu and the key bindings (`src/input/keyBindings.ts`) first. Another builder is changing `patches/smb/` and `harness/smbSkate.test.ts`: do not touch them.

## Bug first
A recording made in play on an SMB build came out as `{"frames": 0, "inputs": [], "checkpoints": [mark 1, mark 2, mark 3 all at frame 0]}` with `start: power-on`. The player is not sure how it was made: probably F9 and F8 pressed mid-game, maybe through the menu. Reproduce it (try F8 before F9, F9 then F8 then F9, a recording started from power-on mid-game, stop right after start) with tests, find how a movie with marks but no frames gets saved, and fix it: a movie with no frames is not saved (say so on screen), and marks only count while recording.

## Build
- **The buffer:** while a game runs and no movie is recording or playing, keep a ring of save states (one every few seconds) and every input since the oldest, covering the last 60 seconds (a setting: 30, 60 or 120). Keep memory use bounded and measured (states in a ring, no growth over a long session); say how many MB it holds for SMB and for a large game.
- **Save it:** a key (one the browser does not take; F10 or the research's choice) and a quick-menu item "Save the last minute" write a `.rwmovie.json` that starts from the oldest state (the movie embeds it, as *the current state* recordings do) and replays every input to now, with a checkpoint at the end holding the screen hash. It downloads like a recorded movie, named after the game and time, and shows a short notice.
- **It replays exactly:** loading the saved movie and playing it reaches the same final screen hash.
- A setting to turn the buffer off; on by default.
- Tests: the ring keeps the right window; a saved replay replays to the same final hash (unit test on a synthetic ROM and a Firefox script, added to `e2e:all`); memory stays bounded over a long synthetic run.

## Prior art
RetroArch's rewind buffer and its "replay" recording; console "save the last 30 seconds" clips; BizHawk's TAStudio greenzone (states at intervals plus inputs). Build on the existing recorder and save states.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The empty-movie bug is reproduced by a test that fails before the fix and passes after (logs).
- A saved last-minute movie replays to the same final hash (unit test and Firefox script, logs); memory is bounded (numbers in the result).
- `npm test`, `npm run a11y` and `npm run build` pass. The README describes the instant replay and its key.
