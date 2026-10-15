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

## Carried from the rw-bot-watch review (suggestions; do them where the code is yours to touch)
- `e2e/movieLink.mjs:110`: The script listens on port 5191, the same port e2e/mouse.mjs uses. e2e:all runs them in sequence so it works today, but a parallel or overlapping run would fail to bind; the other scripts each take a distinct port (5190, 5192), so 5193 would keep the convention.
- `e2e/movieLink.mjs:136`: Rule 2: `check("Esc again resumes it", true)` (and `check("the movie lets go of A...", true)` at line 152) is an assertion that cannot fail on its own; it only records that the preceding waitFor did not throw. Passing the waited-for value into the check (e.g. the frame reached, or the hash matched) would make the PASS line carry its own evidence.
- `src/ui/App.tsx:912`: Rule 1: a movie fetch that rejects (network error rather than a non-OK response) falls into the outer catch, which reports 'Test link: <ROM> could not be opened' and never starts the game, whereas the README says a movie that cannot be fetched leaves the game running. Wrapping the movie fetch in its own try so the ROM still opens would match the documented behaviour.
- `src/ui/testLink.ts:26`: Rule 1: a page URL with movie= but no play= returns null, so the movie parameter is silently ignored with no notice. A user who drops play= from a printed link gets the library with no hint why; naming the missing play= would fail loud.
- `harness/bot/bot.ts:293`: Rule 15: the runBot branch that calls writeWatchFiles is covered only by the real run in .ws-evidence/bot-watch-run.log via a scratch script. The existing bot tests that run to the node cap could pass a `watch` target and assert that nothing is written on an unfinished run, which covers the 'writes nothing there' claim in the README without a full search.
