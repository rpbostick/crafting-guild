# Fix round 1 for `task-rw-ux-research.md`

The review of this branch at 8001007 found blocking issues. Fix each one, with a test where the finding is about behaviour, commit, and re-run the covering test files through ws-run. Do nothing else; suggestions are carried to a later task.

## Blocking findings
- `docs/research/emulator-ux.md:27` (rule 3): Line 9 promises that any thread seen only through a search summary is marked as such. r/Roms [21], which the builder's own report says was seen only through a search summary, is cited unmarked here and in the table at line 46. That makes line 9 a false claim. Mark [21] as 'seen through a search summary only', as line 21 does for [16].
- `docs/research/emulator-ux.md:160` (rule 3): 'Afterplay reviewers praise its touch controls' rests on one source, Chrome Unboxed [34]. The plural overstates it, and done-when item 2 requires single-source claims to be marked. Change it to 'a review praises…' and add '(single review)'.

## Commands
WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call.

## The original task (for context)
## retrowright: research the emulator interfaces players love

Track: light

Research only: no code. retrowright is a browser-based retro emulator (React, a static page on GitHub Pages; NES on jsnes today, SNES and GBA later; the player loads their own ROMs, which stay in the browser). Before building more interface, find out which emulator interfaces, game browsers and user experiences the community actually loves, and why, so retrowright can be good rather than merely working. Read `README.md` for what exists today (file picker and recent games, keyboard and gamepad, battery saves, save-state slots, record and replay).

### Questions
1. **Which front ends are community favourites, and for what?** Desktop, mobile and browser, for example: OpenEmu, RetroArch (and its menus: XMB, Ozone, MaterialUI, RGUI), ES-DE / EmulationStation, LaunchBox and Big Box, Playnite, Pegasus, Mesen, Delta, Provenance, Lemuroid, RetroDECK, and browser ones such as EmulatorJS, webretro, Afterplay.io and the Internet Archive's emulation. Find what people praise and complain about, from r/emulation, r/RetroArch, r/SBCGaming, r/EmulationOnAndroid, r/Roms-style discussion threads (cite the thread, not the subreddit), reviews, and the projects' own docs. Weight repeated opinions over single posts.
2. **The game library / browser:** cover art and box art, grids against lists, collections, search and filters, metadata, "continue playing", favourites. Where cover art and metadata come from (libretro-thumbnails, ScreenScraper, IGDB, TheGamesDB) and their licences and terms, because retrowright is public and open source and must not ship or hotlink art it may not use.
3. **In-game experience:** the pause or quick menu, save states (thumbnails, slots, auto-save on close), rewind, fast-forward, screenshots, shaders and CRT filters, aspect ratio and integer scaling, controller mapping and auto-configuration, on-screen touch controls and skins (Delta's skins are much praised), achievements (RetroAchievements: what integration needs, and its terms).
4. **First run and onboarding:** what a newcomer sees with no games; how legal ROM handling is explained; homebrew offered as a first game.
5. **Browser-specific:** what browser emulators get right and wrong (audio start, fullscreen, keyboard focus, mobile, offline and PWA install, storage limits, file handling), and which features need care on a static page with no server.
6. **Accessibility:** remapping, contrast, motion, screen-reader use of the menus.

### Output
`docs/research/emulator-ux.md`, committed:
- A ranked short list (about five) of the interfaces most worth learning from, each with what to take and what to avoid, with sources.
- For each area above: the patterns players praise, the patterns they complain about, and a recommendation for retrowright, marked **now** (next few builds), **later**, or **not for us** (with why).
- A proposed interface roadmap for retrowright: three to six steps, each a build task in one sentence with its done-when idea, ordered by value to a player.
- A licence and terms table for any art, metadata, shader or skin source mentioned.
- Links only for other apps' screenshots: do not copy their images or code into the repo.

### Prior art
This is the prior-art step for retrowright's interface. The emulator research in rea-roms-test (`/home/patrickb/crafting-guild/plans/rea-roms-test/emulator-research.md`) covers the emulators themselves, not their interfaces.

### Commands
WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call.

### Done when
- `docs/research/emulator-ux.md` is committed with the ranked list, the per-area findings with sources and now/later/not-for-us recommendations, the roadmap, and the licence table.
- Every claim about what the community likes cites at least one source (a thread, a review or project docs); claims made from a single post are marked as such.
