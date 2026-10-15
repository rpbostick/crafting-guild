# retrowright: Super Skate Bros., the stand-alone demo

Track: full

Turn the skate build into a stand-alone home demo called **Super Skate Bros.**: its own title screen and credits, SMB's 2-player game back with Luigi taking turns, title-screen attract demos of Mario skating, a complete ROM for any emulator, and a retrowright mode that opens straight into it. This copy is for the operator's household only and is never published; what is public stays the patch. Read the README's SMB section, `patches/smb/` (all levels, the MMC3 base, the free room), `harness/smb.ts`, `harness/smbSkate.test.ts`, `harness/bot/` and the movie-link and test-link code first. Build with the untracked config in `.ws-evidence/scratch/` as before; never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository; store only our own pixels and data; never commit a built ROM.

## Build
- **Title:** the title screen reads SUPER SKATE BROS. in place of SMB's logo, drawn fresh in the logo's style and size (2-3 drafts on the page, the best used, the others kept), with a small skateboard if it fits. 1 PLAYER GAME and 2 PLAYER GAME are back.
- **2 Player, taking turns:** restore SMB's own 2-player game (Luigi's name, colours, the player swap, the second joypad, the thanks message) now that there is room. Each player has his own board state (has a board, riding, loose board), saved and restored on the swap as SMB saves the rest. Movie test: a 2-player game where Mario loses a life without a board and Luigi starts riding with one, then Mario's next life starts as the rules say (with a board).
- **Credits:** a credits screen after the end (or on the title after a few seconds idle, between demos): Super Skate Bros., a fan demo built on Super Mario Bros. (Nintendo), the skate engine and art by this project, and the tools used. Plain, in SMB's font.
- **Attract-mode demos:** SMB plays a recorded demo of 1-1 on the title screen when idle (removed earlier for room, as its inputs assumed walking). Bring the mechanism back and play skating demos instead: one or more recorded runs of Mario skating 1-1 doing tricks (ollies, a kickflip, a shove-it, a manual, a stomp combo) and looking good. Make them with the bot (a "style" objective that rewards tricks and combos as well as progress, or scripted segments joined by the bot) or by script; each demo's inputs are stored in the free banks. Replicate every demo the original had (check SMBDIS for how many and which level), with skating.
- **The ROM:** `npm run smb -- demo` builds the complete Super Skate Bros. ROM from the player's own SMB ROM into a local path (never the repository), with a short local readme (controls, the tricks, the credits).
- **App mode:** `?game=super-skate-bros` (or a local shortcut the README describes) opens retrowright straight into the demo ROM from the local folder, with the controls panel, the label and the title, ready to play; the app remembers it as a library entry named Super Skate Bros.
- **Movie tests:** the title shows the new logo and both menu items; 2 Player swaps to Luigi with his own board state; the attract demo plays from the title after the idle time and returns to the title; no lag frames. The bot still finishes 1-1 on the board.
- **A page** (`.ws-evidence/page/index.html`, not committed): the title drafts, the title screen, the credits, and the attract demos as animated captures.

## Prior art
SMB's `DemoEngine`/`DemoActionData` and 2-player code (SMBDIS), our earlier removal notes in the README; title hacks' logo replacement (ideas only). Build on the existing patch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`, `git merge *`. One command per Bash call. Run bot searches in the foreground.

## Done when
- The movie tests above pass with no lag frames; the bot finishes 1-1 on the board (logs).
- `npm run smb -- demo` builds the ROM locally; the app mode opens it (Firefox script).
- `npm test`, `npm run e2e:tune`, `npm run a11y` and `npm run build` pass. The README describes Super Skate Bros., its build, the app mode, and that it is for home use only.
