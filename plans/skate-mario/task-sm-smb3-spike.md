# skate-mario: research spike, the homebrew's platformer on Super Mario Bros. 3's model

Track: light

The NES homebrew (`homebrew/`) becomes a shareable game of its own whose platformer engine plays like Super Mario Bros. 3: slopes (and sliding down them), the camera following both ways and vertically, the run meter, and SMB3's movement and physics. Everything is our own code, built from documentation and observation; no SMB3 code, data or graphics, and nothing copied from a disassembly (ideas only). The skate engine (`engine/`) stays as it is and plugs in through its host interface (`docs/research/skate-engine.md` section 2). This spike researches and plans; it builds nothing in `homebrew/`.

Read first: `homebrew/README.md`, `homebrew/src/main.c`, `docs/research/skate-engine.md`, `docs/research/smb-slopes.md` (it already looks at how SMB3 and SMW do slopes), `docs/research/skate-levels.md`.

## Research
- **SMB3's movement and physics, from public documentation:** walking and running speeds and accelerations, the run meter (P-meter), jump heights by speed, gravity, friction, sliding down slopes, the speeds on each slope angle, the camera's rules (dead zone, vertical follow). Cite each number's source page; mark which are measured by someone and which are guessed. Where sources disagree, say so.
- **SMB3's slopes and level format, as ideas:** which slope angles, how a slope tile's height is found, how the player follows a slope, how levels are stored (objects vs. tiles) and what that saves in ROM.
- **Open-source NES homebrews and engines with slopes and two-way scrolling** (cc65/neslib or ca65): what each does, its licence, whether any part can be used as is (MIT, zlib, public domain) instead of written.
- **The frame budget:** the homebrew's longest frame today in CPU cycles (measure it in the retrowright core, as the README's NMI figures for SMB were measured), and an estimate of what slope collision and a vertical camera add. Does the skate engine plus an SMB3-style engine fit in an NTSC frame, and with how much to spare?
- **The skate engine's fit:** what the host interface lacks for slopes (a slope's angle for the board's speed: rolling down speeds up, up slows down), and where that belongs (engine or host), so the same engine still serves the SMB build.

## Write
`docs/research/smb3-model.md`: the findings with sources, then a plan of small build steps, each with a done-when and a test (in the retrowright core, as `harness/homebrew*.test.ts` do), in order: the first is the one that gets a single slope ridden on the board soonest. Note for each step whether it touches the skate engine. End with what is unknown and how to measure it.

## Prior art
This spike is the prior-art research for the build.

## Commands
`npx vitest *`, `npx tsx *`, `npm run *`, `node *`, `make *`, `grep *`, `git add`, `git commit`. One command per Bash call. Read files outside the worktree with the Read and Grep tools; web pages with WebFetch and WebSearch.

## Done when
- `docs/research/smb3-model.md` is committed, with sources for every number, the measured frame budget (log), and the ordered build steps.
