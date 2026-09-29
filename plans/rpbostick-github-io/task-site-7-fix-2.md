# rpbostick.github.io: colorwright's wash back down; skywright license list
Track: light

You are continuing `agent/site-backdrops`. The orchestrator has just committed a rebuilt `public/colorwright/` on it (see `git log -1`). Its light `--text-faint` is now **#5e666f** (it was #687079). That clears the 0.93 wash you needed in the last round.

## Changes
1. In `src/backdrops/wash.ts`, set colorwright's faint color to the new value (read both themes from `public/colorwright/style.css`). Then **lower colorwright's light wash** to the least value `check:backdrops` passes at, rounded up to 0.05, and **no lower than 0.35**, the value Patrick saw on the preview. Keep the dark wash unless the check needs more. Say the final values.
2. Regenerate `public/skywright/THIRD_PARTY_LICENSES.txt` with the American-spelling generator. The license-checker output for skywright's example app is saved (untracked) at `.ws-evidence/skywright-production.json`. Run `node scripts/third-party-licenses.mjs skywright .ws-evidence/skywright-production.json` from the repo root. Nothing else under `public/skywright/` changes.

## Check
`npm run build`, `npm run lint`, `npm run check:backdrops`, and `npm run test:unit` pass. `git grep -niE 'colour|licence|behaviour'` over `public/skywright/THIRD_PARTY_LICENSES.txt` finds nothing outside quoted third-party license texts.

## Commands
One command per Bash call: `npm run build`, `npm run lint`, `npm run check:*`, `npm run test:unit`, `node …`, `git grep …`. Do not run `npm install`.

## Done when
colorwright's light wash is back near 0.35 and the check passes. skywright's license list is regenerated.
