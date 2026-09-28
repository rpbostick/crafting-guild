# Release audit

Run before anything goes public: a repo made public, a package published, or files deployed to a public site. Patrick decided the policy on 2026-09-28. A release is not done until every section passes and Patrick has seen the findings.

## Policy
- **Fresh history.** The private repo keeps its full history. The public repo starts from one audited commit (an orphan branch pushed to the public remote), and later releases are audited and pushed on top of it. Never make a private repo with development history public.
- **Straight to the point.** The public repo reads like a tool for anyone to use, not the record of how Patrick and Claude built it.
- **Agent-readable material is welcome when it helps others.** Examples: a concise `AGENTS.md` or `CLAUDE.md` that explains how to work in the repo, or design notes that explain why the code is shaped the way it is. Agree with Patrick on what to include for each release; see "Open question" below.

## 1. Secrets and machine details
Scan the tree **and** the built output for:
- API keys, tokens, passwords, private keys, `.env` files, credentials in config
- home paths, `patrickb`, hostnames, IP addresses, local ports, emails (other than an intended contact)

Tools: `git grep` with patterns for each, and a secret scanner if one is installed (e.g. `npx --yes secretlint` or gitleaks).

## 2. Journey and personal text
Remove or rewrite:
- Patrick's name outside intended credits
- "the operator", "Patrick said", quotes of him, and dated decision comments
- conversation or journal voice, and AI-process wording (builder, orchestrator, reviewer, spike, fix round)
- `plans/`, `reviews/`, `runs/`, `lessons/`, `.ws-evidence/`, handoffs, backlogs, `docs/history.md`-style logs

Code comments become plain technical explanations: what the code does and why, never who asked for it or when. Commit messages in the fresh history are neutral.

## 3. Licences and third-party content
- Every asset has a known licence and its credit is present (Open Peeps CC0, React Bits MIT + Commons Clause, Open-Meteo CC BY 4.0).
- Nothing is shipped that can't be redistributed: reference photos, non-commercial data (BodyM), vendored code without a licence.
- A `LICENSE` file is present, and `THIRD_PARTY_LICENSES` exists where bundles ship dependencies.

## 4. Built output
Bundles, static builds and packages (`npm pack --dry-run`) get the same scans as sections 1 and 2. Minify with comments stripped (`--legal-comments=none` keeps licence headers out of the bundle; credit third parties in `THIRD_PARTY_LICENSES` instead). Trim data files to the fields the app reads. Builds that publish should fail on a leak pattern (as colorwright's `build-static.sh` does).

## 5. Sign-off
Write a short findings list (what was found, what was changed) for Patrick. Publish only after he approves.

## Open question (to settle with Patrick per release)
Which agent-readable material adds value for other agent and human teams without oversharing. Candidates:
- a concise `AGENTS.md` (how to build, test and extend; conventions)
- `docs/design.md` (the model and its reasons, in present tense)
- a generic, anonymised version of useful lessons

Journals, dated decisions and quotes stay private.
