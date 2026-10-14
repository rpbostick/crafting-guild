# retrowright: research a game-playing bot for testing games

Track: light

We want a bot that plays a game through our Node harness to test it: can World 1-1 still be finished with the skate patch, on the board and on foot, how long it takes, and where Mario dies or gets stuck, with the winning run saved as a movie retrowright can replay. Research before building. Read `harness/smb.ts`, `harness/smbSkate.test.ts` and the README's harness section first (savestates, movies, RAM reads). Write no product code; the result and `docs/research/game-bots.md` are the output.

## Research
- Search bots: Tom Murphy VII's learnfun/playfun (objectives learned from a played movie, search ahead with savestates), Robin Baumgarten's A* Mario from the Mario AI Competition, BizHawk's Basic Bot, and any newer search or "go-explore" style players.
- Learning bots: stable-retro (Farama), gym-super-mario-bros, MarI/O, with Stable-Baselines3 or CleanRL.
- Screen-reading AI model harnesses that press buttons from frames (VideoGameBench and similar): cost and speed per frame.
- For each: licence, maintained or not, language, whether it can drive our jsnes harness or needs its own emulator, how long it takes to finish SMB 1-1, and what it would tell us that a movie test does not.
- Measure our harness's speed: frames a second headless, and savestate save and load time, so the search budget is real numbers.

## Prior art
This task is the prior-art step.

## Commands
`npx vitest *`, `npx tsx *`, `npm run *`, `node *`, `git add`, `git commit`, WebSearch, WebFetch. One command per Bash call.

## Done when
- `docs/research/game-bots.md` compares the options with sources and the measured harness numbers, and recommends one design for a search bot on our harness with what it reuses, its objective (Mario's X position, level, deaths), and how it saves its run as a movie.
