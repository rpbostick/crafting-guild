# retrowright: plan the skate engine as its own module, and a homebrew base

Track: light

The skate physics will live in two games: Skate Mario (a patch on the player's own SMB ROM, the original levels) and later a shareable homebrew game with its own levels, art and music, first on the NES and later rewritten for the GBA in C++. The homebrew cannot use any of SMB's code (its running, jumping, enemies and scrolling are Nintendo's), so it needs its own platformer engine with our skate engine plugged in. Plan how, before any build. Read `patches/smb/skate-pedal.diff` (the bank-0 code, the far call, every hook into SMB's code), its tunables, the README's SMB section, `harness/smbSkate.test.ts`, `docs/research/gba-core.md` and `docs/research/skate-levels.md` first. Write no product code; the result and `docs/research/skate-engine.md` are the output. Never copy SMB code into the repository.

## Research and plan
- **The skate engine's interface today:** list every place the skate code reads or writes SMB's RAM or calls SMB's routines (pad, Player_X_Speed, Player_State, facing, the OAM it draws, the hit and power-up hooks, the sound calls), and which of them a non-SMB engine would provide. Propose a narrow interface: what the host engine hands the skate engine each frame and what it gets back, as a RAM block and a few calls, in 6502 for the NES and as a C++ struct for the GBA.
- **What moves:** which skate code still sits in SMB's own banks (the hooks) and could move behind the interface, what that costs in bytes and cycles, and the order to do it without breaking the movie tests.
- **Shared tests:** how the tunables file and the movie tests could describe the engine's behaviour independently of SMB (inputs and expected speeds, poses, board frames), so both an NES homebrew and a GBA rewrite can be checked against the same cases.
- **An NES homebrew base:** open-source NES platformer engines and frameworks with permissive licences (for example NESmaker's exports are not open; look at nesdoug's tutorials and libraries, famitone/famistudio sound engines, NES game templates on GitHub, ca65/cc65 projects), what each gives (scrolling, metatiles, enemies, collision), licences, and how our skate engine would sit in one.
- **The GBA path later:** what of this plan carries to butano/C++ per `gba-core.md`.
- Recommend the interface, the order of steps (after the physics are settled), and the NES base.

## Prior art
This task is the prior-art step.

## Commands
`npx vitest *`, `npx tsx *`, `npm run *`, `node *`, `git add`, `git commit`, WebSearch, WebFetch. One command per Bash call.

## Done when
- `docs/research/skate-engine.md` covers the above with sources, a proposed interface, the step order, and an NES base recommendation.
