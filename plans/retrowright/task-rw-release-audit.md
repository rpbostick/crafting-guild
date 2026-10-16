# retrowright: release audit for the first public release (0.1.0)

Track: full

retrowright is going public: a public GitHub repo with a fresh history and, later, the app on a public site. Run the release audit and fix what can be fixed without a decision; list the rest for the operator. Read the checklist below, the README, `docs/`, `patches/`, `harness/`, `e2e/`, `src/`, `package.json` and the licence files first. Another builder is changing `patches/smb/skate-pedal.diff`, `patches/smb/super-skate-bros.diff` and `harness/smbSkate.test.ts`: list findings in them but do not edit them.

## The checklist
1. **Secrets and machine details** in the tree and in the built output (`npm run build`'s `dist/`): keys, tokens, passwords, `.env`, home paths, the username, hostnames, IPs, local ports, emails. Use `git grep` patterns and a secret scanner if one runs (`npx --yes secretlint` or gitleaks).
2. **Journey and personal text:** the operator's name outside intended credits; "the operator", "<name> said", quotes, dated decision comments; conversation or journal voice and process words (builder, orchestrator, reviewer, spike, fix round); `.ws-evidence/` references. Code comments and docs become plain technical explanations in the present tense.
3. **Licences and third-party content:** every dependency's licence (jsnes is Apache-2.0; check each runtime dependency and anything vendored, such as the BPS typing), a `LICENSE` file for retrowright (propose one; the operator decides), `THIRD_PARTY_LICENSES` for the bundle, and nothing shipped that can't be redistributed.
4. **Nintendo and other commercial content (the most important section here):** a public repository must hold no bytes of a commercial game, no disassembly text, and no graphics. Check every file under `patches/smb/` and elsewhere: the `.diff` files (do their context lines or comments quote SMBDIS source? list each), the `.bps` files (do they carry any run of the original ROM's PRG or CHR bytes, beyond what `harness/smbPixels.test.ts` already checks?), drafts, demo data, tests, fixtures, screenshots and docs (any SMB or Final Fantasy screenshots, ROM names, or quotes of code). Propose what the public repo can carry: for example the `.bps` patches and their `.json`/tunables but not the `.diff` files, and how the SMB build would then work for someone with their own SMBDIS tree. Also check the movies policy: no movies of commercial games ship.
5. **Built output:** the same scans on `dist/`; minified with comments stripped and licence headers kept out of the bundle.
6. **What ships:** propose `RELEASE_PATHS` (the paths the public repo carries), what stays private, and whether a short `AGENTS.md` and `docs/design.md` would help other people.

## Fix now (no decision needed)
- Rewrite process and journey wording in code comments, README and docs into plain technical text; remove dated decision comments; remove absolute paths and the username where they appear in tracked files.
- Add a `THIRD_PARTY_LICENSES` generated from the dependencies (a small script, run by `npm run licenses`).

## Report
`.ws-evidence/release/findings.md` (not committed) and the result: each finding with file and line, what was changed, and the decisions left for the operator (licence choice, what ships under `patches/`, the public repo name, whether to publish the site).

## Prior art
The workspace's release audit; `license-checker` / `license-report` style tools for dependency licences (choose one, licence noted).

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `npm test`, `npm view *`, `npx --yes secretlint *`, `node *`, `git grep *`, `grep *`, `sha256sum *`, `git add`, `git commit`, `git merge *`. One command per Bash call.

## Done when
- The findings file covers all six sections with file and line; every no-decision fix is made; `npm test` and `npm run build` pass (logs).
