# colorwright: clean static build, fix round 1

Track: light

Continue branch `agent/cw-clean`. Blocking review finding: `scripts/static-leak-check.sh` hard-codes the owner's name and username (`patrick`, `patrickb`) in its patterns, in a repo meant to be publishable.

- Build the personal patterns at runtime: the current username (`id -un`), the git author name (`git config user.name`, each word of it), the home directory (`$HOME`), plus an optional untracked file `scripts/.leak-patterns` (one extended regex per line; add it to `.gitignore`). No personal string appears in any tracked file. If `id -un` or `git config user.name` gives nothing, fail loudly (do not silently skip).
- Keep the generic patterns (`operator`, `plans/`, `evidence`, `scripts/`, ISO dates, TODO/FIXME, emails, localhost/127.0.0.1).
- `git grep -n -i -E 'patrick'` over the tracked tree of this branch's changed files returns nothing new.
- Re-run the planted-leak build (plant the current username in a copied JS file) to show it failing, then the clean build; save both logs.

## Commands
One command per Bash call. `bash scripts/build-static.sh`, `bash scripts/static-leak-check.sh ...`, `node ...`, `git grep ...`. Do not install packages.
