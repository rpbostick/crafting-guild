# retrowright: Super Skate Bros., a player-like demo and a logo in SMB's own style

Track: full

This continues this branch (`c351816`). Read your earlier result and `git log --oneline main..` first; keep what is there. Never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository; store only our own pixels (SMB's tiles are referenced or composed at build time from the player's ROM, never committed).

In play: "the demo needs to try to do some stuff a regular player would do, like grab the mushroom in the first few blocks, do some tricks, and complete the level. try again with the logo. copy the style on the letters, have the shadow underneath, chunkier font, etc. maybe just cut+paste all the letters that already there, and then invent the few that aren't in the same style."

## The attract demo
- One demo of 1-1 that plays like a good player: rides, hits the first ? blocks and takes the mushroom (riding a board or not, as the state gives), does tricks (ollies, a kickflip, a shove-it, a manual, a stomp combo or two), and finishes the level at the flagpole. If SMB's demo engine or the title's timer cuts a demo short, lengthen what it allows (say how), so the whole run plays and then returns to the title.
- Make it with the bot where it helps (a style objective with waypoints: the mushroom block, tricks at set places, the flag), or by script, and keep the inputs in the free bank as now. Test: the demo, played from the idle title, reaches big Mario, lands at least three tricks, and reaches the flagpole, with no lag frames.

## The logo
- Build SUPER SKATE BROS. from SMB's own title logo: use SMB's existing logo letters (from its title tiles: S, U, P, E, R, M, A, I, O, B and the full stop, as SMB's logo has them) for every letter they cover, composed at build time from the player's ROM, with the same chunky shape, outline and the shadow underneath. Draw only the missing letters (K and T, and any other) fresh in exactly that style, as our own pixels. Keep the logo's box and layout like SMB's. One or two layouts on the page beside SMB's original title, the best built.

## Blocking, from the review
## Blocking
- harness/superSkateBros.test.ts:93 (rule 3): The demo test's `each` callback calls core.frame() and then `until` calls core.frame() again, so two frames pass per iteration and the lag check (FRAME_COUNTER before/after), the off-board check and the trick sampling see only every other frame; the buil

## Suggestions (carry forward, do not block)
- src/ui/App.tsx:1080: The rename-to-title branch is exercised by nothing that could fail: the library's default title for "Super Skate Bros.nes" already reads Super Skate Bros., so the Firefox check passes without this line. Add an App.test.tsx case where the stored game has another title and ?game
- e2e/ssbDemo.mjs:4: The header says the script checks that the game "shows its title screen", but it only screenshots it; either compare a pixel or two of the logo box, or drop the words.
- e2e/all.mjs:24: Rule 15: e2e:ssb is not in the e2e:all list. Add it with a SKIP line when the ROM folder is missing, as e2e:tune does without the SMB ROM, so the app-mode check reruns with the rest.
- harness/superSkateBros.ts:76: "crafting guild" appears nowhere else in the repository. If it names a person or an organisation rather than the project, it belongs in RETROWRIGHT_SSB_NAMES locally, not in a tracked file (rules 18/19).
- harness/superSkateBros.test.ts:91: The limit `length + 60` is in iterations of two frames, so the demo could overrun its 1,300 frames by up to 1,360 frames before "the demo's end" fails; after the fix above, keep the bound at `length + 60` frames so an overlong demo is caught.
- harness/ssbTitle.test.ts:44: The test that the demo folder holds exactly ["1-1"] fails the moment a second demo is added, which the README invites ("another demo moves no code"). Assert that 1-1 is among them instead.
- harness/superSkateBros.test.ts:120: Both lives are ended by poking the game timer to zero rather than through play; fine for the swap checks, but the builder's unknown about Select-then-wait shifting the demo's timing is untested. A second demo run that presses Select on the title first, then asse

## Prior art
SMB's title screen data and `DemoEngine`; the bot's waypoints. Build on this branch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. Run bot searches in the foreground.

## Done when
- The demo test above passes, checking every frame; the logo test checks the built title against SMB's letters where they are reused (logs).
- `npm test`, `npm run e2e:tune`, `npm run a11y` and `npm run build` pass in full (logs).
