# Colorwright 5b-3: saved looks keep carried hair and bandana picks

**Done.** Current colorwright work: `plan-19-rest.md` (in-flight block) and `plan-20-heads-hair-hats.md`.

## Requirements (Patrick, 2026-09-25)
- A saved look stores the session's carried head-colour picks (`state.chosenHeadColors`: `hair`, `hair-outline`, and the bandana roles), including picks that the head it's wearing doesn't show. Loading the look restores them, so a later switch to a head with hair uses them.
- Storage: a new nullable column `carried_colors_json` on looks, added by the same one-off in-place migration pattern as `look.hat` (`backend/toolkit/db.py`). Old code ignores the column.
- Rollback tolerance: loading and re-saving must not 400 on data another version wrote. Unknown colour roles are dropped instead of refused, for saved looks and stored browser state. A `look.hat` that isn't valid for the look's pose loads as that pose's no-hat. This closes the hats known issue (re-save 400 after a rollback).
- Carried from 5b-2: `frontend/tests/hair.test.js:216-218` can't fail; the hair evidence README's "fixed" entry and its latest-suite line (882, not 887).

Guessed: the rollback tolerance applies on load and on the server's validation of colour roles, not to unknown item ids in other slots (those still 400).

## Steps
1. `task-5b3.md`: one builder, one branch (`cw-5b3`). It is one feature across backend and frontend with shared tests, and splitting it would leave a half-saved look format on master. Retryable from scratch until merged. After merge, the migration has run on the live db, so copy `backend/colorwright.db` aside before merging.

## Done when
Merged, the suite passes, and Patrick has saved a look on a bald head with a hair pick on the preview server, reloaded it, and switched to a head with hair to see the pick.
