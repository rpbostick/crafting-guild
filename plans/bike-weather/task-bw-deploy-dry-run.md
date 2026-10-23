# Bike Weather: a repeatable deploy dry run for the Worker

Track: light

Nothing checks that `server/` still builds and migrates cleanly before the first deploy. The deploy plan (steps 3 and 4) will run `wrangler d1 migrations apply --remote` and `wrangler deploy` on a Cloudflare account; a broken migration or bundle should fail here first, without an account.

## What to build (in `server/`)

1. **`server/scripts/deploy-dry-run.sh`**, run from anywhere:
   - create a fresh temp persist directory under `.ws-evidence/scratch/deploy-check/` (wipe it first);
   - apply every migration with `npx wrangler d1 migrations apply bike-weather-ratings --local --persist-to <dir>` (not file by file, so the migration ledger is exercised);
   - read the ledger back (`npx wrangler d1 execute … --command "SELECT name FROM d1_migrations"` or the migrations list command) and fail if the count is not the number of files in `migrations/`;
   - build the Worker with `npx wrangler deploy --dry-run --outdir <dir>/out` and fail if it does not exit 0 or writes no bundle;
   - print one line per check with the bundle size, and exit non-zero at the first failure. It must not log in, deploy, or touch the real database.
2. **`server/package.json`:** `"deploy:check": "bash scripts/deploy-dry-run.sh"`.
3. **`server/README.md`:** a "Before deploying" section with the one command and what it proves.
4. Prove the failure path: copy the script's temp tree, add a broken migration (`CREATE TABLE` with a syntax error) in the temp dir only, and show the script failing. Save both runs under `.ws-evidence/`. Do not commit a broken migration.

## Prior art
wrangler's `d1 migrations apply`, `d1 execute` and `deploy --dry-run` pages; the project's existing wrangler scripts.

## Commands
`bash server/scripts/deploy-dry-run.sh`, `npx wrangler *`, `npm --prefix server *`, `npx tsc *`, `node *`, `cat *`, `git add`, `git commit`. One command per Bash call.

## Leave alone
`wrangler.toml`'s bindings and database id, the migrations' SQL, the Worker code, and `.gitignore` (the scratch dir is already untracked).

## Done when
- `bash server/scripts/deploy-dry-run.sh` exits 0 on a clean tree and prints the migration count and bundle size.
- A broken migration in the temp tree makes it exit non-zero; both runs are saved under `.ws-evidence/`.
- `npm --prefix server test` and `npm --prefix server run typecheck` still pass.
- The README names the command and what it checks.
