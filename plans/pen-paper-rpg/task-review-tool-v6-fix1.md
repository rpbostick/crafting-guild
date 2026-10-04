# Review page round 4: fix round

Track: light

Continue on this branch. The review found two blocking issues, quoted in `/home/patrickb/agentic-workspace-v2/runs/pen-paper-rpg/ppr-review-v6.review.md` (read it):

1. **`scripts/export-round.js:134`**: `shown()` drops every note's database id, but a reply keeps `parent`, which is a database id, so in the exported file a reply's parent names no note and the thread cannot be rebuilt. Keep an `id` on each note that a reply points to (and on each reply that another reply points to). A round with no replies must export exactly as now, so the committed round 3 files are still reproduced byte for byte.
2. **`tests/export-round.test.js:84`** asserts the reply's exact keys and a parent of `'z001'` without checking that `'z001'` names a note in the output, which locks the defect in. Change it to assert that every reply's `parent` resolves to a note or reply in the exported file, and add a case with a reply to a reply.

Show one failing run of the changed test before the fix (through ws-run), then the passing run.

## Commands
`node --test tests/<file>.test.js`, `node scripts/export-round.js …`, `git add`, `git commit`. One command per Bash call.

## Leave alone
Everything except `scripts/export-round.js` and `tests/export-round.test.js`.

## Done when
An exported round with replies keeps each thread intact, round 3's files are still reproduced exactly, and the export tests pass.
