# Fix round 3 for `task-rw-ux-research.md`

The review of this branch at 90056f2 found blocking issues. Fix each one, with a test where the finding is about behaviour, commit, and re-run the covering test files through ws-run. Do nothing else; suggestions are carried to a later task.

## Blocking findings
This is the last round on this document: fix the blocking findings **and** the review's suggestions below, then check every summary row (the ranked list, the front-end table, the licence table) against the detailed sections, so each row cites only the sources that back that exact claim, with the same single-source markers. Use only the source-kind markers listed in the Method section, adding any new one there.

### Suggestions to fix too
- `docs/research/emulator-ux.md:9`: The Method section lists the allowed source-kind markers, but the doc also uses '(review aggregator)' (line 44), '(help page)' (line 48) and '(single forum thread)' (line 141). Add these to the list or switch them to the listed markers.
- `docs/research/emulator-ux.md:40`: [14] is OpenEmu's own page and [15] is a SourceForge mirror of the same project, so the 'drop a file in' claim effectively rests on project docs. The table marks it that way, but the ranked list at line 23 does not. The builder also lists the independence of [14] and [15] as unknown.
- `docs/research/emulator-ux.md:39`: RetroArch's 'Breadth' praise cites two Wikipedia articles [23][24]. They describe features rather than community opinion, and they are not really independent of each other. Consider calling it a feature list, not praise.
- `docs/research/emulator-ux.md:29`: The 'repeated complaints [29][30][31][32]' list includes [31], a news report about the default menu changing. That report backs only the XMB point, not the other complaints. Narrow which sources back which complaint.

- `docs/research/emulator-ux.md:44` (rule 3): The Delta row lists 'skins' as praised, cited to [9][12][13] with no single-source marker. Line 113 says only one review [9] praises Delta's skins, and the builder lists 'whether [12] praises Delta's skins' as unchecked. Either split the cell so skins cite [9] (single review), or confirm that [12] or [13] praises skins. As it stands, done-when item 2 is reported met but not delivered.
- `docs/research/emulator-ux.md:47` (rule 3): The Afterplay row cites 'autosave and cross-device sync' praise to [33][34]. Line 93 marks the same praise as coming from [33] alone (single review). Line 33 makes the same multi-source attribution for autosave and sync. Mark both places single-review or cite a second source; otherwise only the flagged line was changed and the claim still stands unmarked elsewhere (rule 16).

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
