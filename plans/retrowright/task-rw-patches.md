# retrowright: IPS and BPS patches in the library

Track: full

Toolkit step 3 (`docs/research/toolkit.md` section 8). Read sections 1.4 and 4 ("Sharing without the original game") of that document, then `src/storage/` (the game store and how entries are keyed by ROM SHA-256), `src/ui/Library.tsx`, `harness/cli.ts` and `NOTICE`.

## Build
- **Vendor Rom Patcher JS's BPS and IPS modules** (MIT): only the format modules and what they need, not its web app. Put them under `src/vendor/rompatcher/` (or the existing vendor location), unmodified where possible, with their licence and an entry in `NOTICE`. Wrap them in a small TypeScript module of our own (`src/patch/`): `applyPatch(rom, patch)` and `createBps(source, target, metadata?)`.
- **Library:** "Apply patch…" on a library entry. It picks an `.ips` or `.bps` file, applies it to that stored ROM, and saves the result as a new library entry keyed by the patched ROM's SHA-256. Name it after the original plus the patch file's name, and record which ROM and patch it came from. A BPS for the wrong ROM is refused with a clear message naming the CRC32 it expected. The original entry stays as it is.
- **Harness:** `npm run patch -- create <source.nes> <target.nes> <out.bps>` and `npm run patch -- apply <rom> <patch> <out>`, using the same module in Node.
- Follow the library's existing keyboard, focus and announcement rules; the accessibility check (`npm run a11y`) must still pass.

## Prior art
`docs/research/toolkit.md` section 1.4: Rom Patcher JS (MIT, LICENSE file) is the one to use; Flips (GPL-3.0) is the reference tool, run only as a separate program to cross-check. Clone Rom Patcher JS into `.ws-evidence/` to copy its modules, and record the commit you took them from in `NOTICE`.

## Commands
`git clone *` (into `.ws-evidence/` only), `cp *` (from `.ws-evidence/` into the worktree), `npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `firefox --headless *`, `flips *` (only if it is installed; say so if not), `git add`, `git commit`. One command per Bash call.

## Done when
- A BPS made by the harness from two synthetic ROMs applies in the page and gives the target's SHA-256 (Firefox script); an IPS applies too.
- A patch for the wrong ROM is refused with its CRC32 message (unit test and in the page).
- The patched game appears as a new library entry, plays, and the original entry is unchanged (Firefox script, screenshots on `.ws-evidence/page/index.html`).
- If Flips is installed, it applies the same patch to the same result; if not, the result says so.
- `npm run a11y` passes, the tests for what changed pass, and `npm run build` passes. NOTICE names Rom Patcher JS with its licence and commit. The README describes applying a patch.
