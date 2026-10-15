# retrowright: research skate features for SMB levels

Track: light

The skate game will change levels next: ramps, rails and gaps in World 1-1 first. Research how, before any build. Read the README's SMB section, `docs/research/game-bots.md` and `harness/bot/` first. Write no product code; the result and `docs/research/skate-levels.md` are the output. Never copy SMB level data or code into the repository.

## Research
- How SMB stores a level (SMBDIS area data: object and enemy data, the metatiles the area parser places, the block buffer) and what a level change costs in bytes, and where new level data can live on the MMC3 cartridge (banks 0-11 are ours).
- Which existing SMB metatiles can serve as skate features (a slope does not exist in SMB: what can stand in for a ramp, such as the staircase blocks with an ollie, a launch block, a half-pipe built from pipes), and what a real slope or rail would need (new metatiles, collision code, new tiles in the free CHR).
- Existing SMB1 level editors and hacks that add new terrain (romhacking.net, SMB Utility, the SMB1 level format documentation; licences noted, ideas only), and skate platformers' level design (Skate or Die 2, Tony Hawk's 2D games, OlliOlli) for which features fit SMB's grid.
- How the bot (`npm run bot`) can check a changed level: whether it finishes, and where it gets stuck.
- Propose 2-3 concrete changes to 1-1 for the operator to choose from, each with a rough cost (bytes, new code, new tiles) and a sketch (an ASCII grid of the changed screen is enough).

## Prior art
This task is the prior-art step.

## Commands
`npx vitest *`, `npx tsx *`, `npm run *`, `node *`, `git add`, `git commit`, WebSearch, WebFetch. One command per Bash call.

## Done when
- `docs/research/skate-levels.md` covers the above with sources and proposes 2-3 changes to 1-1 with costs and sketches.
