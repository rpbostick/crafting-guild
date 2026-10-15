# retrowright: crouch, as part of the ollie only; a vine movie to watch

Track: full

This continues this branch. Read your earlier results and `git log --oneline main..` first; keep what is there. Never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository. Main has moved (the movie link `&movie=local-movies/<file>`, README "Watch it"; the harness leftovers): run `git merge main` first and resolve any conflict.

In play on SKATE 19: "i think the ollie should just have a crouch as part of the animation, but holding A does not keep the crouch. holding down while ollying can keep the crouch though. i haven't found a vine to climb up, so i dunno about that part. maybe you could have the runner test it and take some video on a level where there's a vine."

## Change
- **The ollie's crouch is animation only:** big Mario crouches through the ollie delay and pops; holding A after the pop does not keep him crouched (he stands in the air as before). Pressing A in the air does not crouch him.
- **Down keeps the crouch:** Down held through the pop keeps him crouched in the air, and Down pressed in the air crouches him, with the duck box; letting go stands him up.
- Update the movie tests and the comparison page for both.

## A vine movie to watch
- Make a movie of Mario riding to a vine and climbing it, on the default skate-pedal build: World 2-1's vine (in a brick near the start; check where in SMBDIS's area data), reached by a movie that starts from a save state at 2-1's start (the movie format can embed one; a RAM-set world and level at the title is fine to make that state). Riding, he hits the brick, the vine grows, he jumps to it: he steps off carrying the board, climbs, and after the bonus area or on letting go is on foot carrying it; Select gets him back on. Use `npm run bot` with `--to` if it helps, or script the inputs.
- Write the movie as `SKATE vine 2-1.rwmovie.json` and print the watch link (`?play=local-roms/<rom>&movie=local-movies/<file>&label=...`) in the result, with the ROM name it needs. Write both to `.ws-evidence/watch/`; the orchestrator copies them to the local folder.
- Also save a short animated capture (GIF or WebM, from the movie's frames) of the step-off and climb on the comparison page.

## Prior art
The movie link and `harness/movieScript.ts`; SMBDIS area data for 2-1. Build on this branch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`, `git merge main`. One command per Bash call.

## Done when
- Movie tests: the crouch shows in the delay, A held after the pop does not keep it, Down held keeps it with the duck box, Down in the air crouches (logs, no lag frames).
- The vine movie replays from its state to Mario climbing and back on the board with Select (replay log), with the watch link in the result.
- `npm test`, `npm run e2e:tune`, `npm run a11y` and `npm run build` pass; the bot finishes 1-1 on the board (logs). The README describes the crouch as changed.
