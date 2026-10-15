# retrowright: big board, check the climbing pose and fix

Track: full

This continues this branch (`112f877`). Read your earlier result and `git log --oneline main..` first; keep what is there. Build with the untracked config in `.ws-evidence/scratch/` as before; never keep SMBDIS source, even emptied, in `.ws-evidence/` or the repository: work on SMBDIS copies outside the worktree as earlier runs did through the scratch tools, and leave none behind.

## Blocking, from the review
The diff (line 44), the README and bank 9's design say tile `$2C` shows only in water. SMB's `PlayerGraphicsTable` likely builds big Mario's climbing frames from the swimming rows, with `$2C-$2D` as the legs, and the flagpole slide draws the climbing pose; then bank 9 puts the long board's middle into big Mario's leg at every flagpole and on every vine.
- Test first: a movie or RAM set-up with big Mario climbing (`Player_State` 3 on 1-2's vine, and the flagpole through `PlayerEndLevel` with OAM sampled during the slide), asserting no Mario sprite shows `$2C` while bank 9 is in. Record whether it fails on `112f877`.
- If it shows, pick a tile only the swimming frames use, or have the bank switch put bank 0 in while Mario is climbing or swimming, and correct the README's reason.

## Also, from the review
- README line 98: name `harness/pushDrafts.test.ts` for the push-drafts pixel check.
- A RAM-edit test pinning the long loose board's right-edge bound (65 and 66 past the edge).
- `harness/bot/bot.test.ts`: assert the report names its movie and screenshot relative to the working folder.
- Run `npm test` in full this time.

## Prior art
SMB's `PlayerGraphicsTable` and `PlayerGfxHandler`. Build on this branch.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `node *`, `firefox --headless *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call.

## Done when
- The climbing test passes (and the result says whether it failed on `112f877`); no Mario sprite shows a board tile while climbing, on the flagpole or swimming (logs).
- `npm test`, `npm run e2e:tune` and `npm run build` pass (logs).
