# retrowright: a slow push animation on the arrows, a faster one on B taps; a nose manual on Up+B

Track: full

Today the push frame (draft A, long kick) shows only on a B-tap push (and the direction-tap style's pushes). Holding the direction alone walks Mario up to walking speed on the board with no push shown. In play: "can we get a little of the pedal animation even just from the arrows? with more of faster pedal / push when tapping b, but also a reasonable slow pedal from just using the arrows." Read the README's SMB section (pushing, the push frame and its tunable, the walking push), `patches/smb/skate-pedal.diff`, its tunables and `harness/smbSkate.test.ts` first. Build with the untracked config in `.ws-evidence/scratch/` as before; never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository.

## Build
- **Slow push on the arrows:** while the direction along the roll is held and the walking push is adding speed, Mario shows the push frame in a slow rhythm (a push every N frames, a tunable `arrowPushRhythm`, default about one push a second, each shown for the push frame's frames), between which he stands in the riding stance. It stops once he is at walking speed and only coasting.
- **Faster on B taps:** each B-tap push shows the push frame as now, and quick taps read as quick pushes (each tap restarts the frame). If it reads better, B-tap pushes show a slightly longer kick than the arrow rhythm's (say which).
- Nothing changes in the speeds: looks only.
- **Nose manual on Up+B:** in play: "there should be a nose manual. it seems like if you are riding fakey and go into manual, it just does a regular manual." Chosen: Up+B held on the ground riding is a nose manual: the board on its front wheels (the end Mario faces, nose down, tail up), forward or fakie, mirroring the manual's steep frame; Down+B stays the manual on the back wheels (the end behind Mario), forward or fakie, so the two always look different. Up+B in the air stays the pop shove-it. It keeps a combo alive as the manual does and uses the manual friction. Movie tests: Up+B on the ground shows the nose manual (OAM: the front end down), forward and fakie; Down+B in fakie shows the back-wheel manual; Up+B in the air is still the shove-it.
- **Movie tests:** holding the direction from a stop shows the push frame at the rhythm until walking speed and not after; B taps show it on each tap; no lag frames. The bot finishes 1-1 on the board.

## Prior art
The push frame code. Build on the existing patch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`, `git merge *`. One command per Bash call.

## Done when
- The movie tests pass with no lag frames; the bot finishes 1-1 on the board (logs).
- `npm test`, `npm run e2e:tune` and `npm run build` pass. The README describes the arrow push rhythm.
