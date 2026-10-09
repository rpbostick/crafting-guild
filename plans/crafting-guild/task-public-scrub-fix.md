# Fix round: the public scrub, and the name is now Crafting Guild

Track: light

Continue on this branch (agent/ws-public-scrub). The review of 29e784e found one blocking defect; the public name also changes from **Waystation Guild** to **Crafting Guild** (the operator's decision: "Waystation" is crowded by other AI-agent products).

## Behaviour
- **Blocking (MODIFYING.md:40):** the `VERSION, CHANGELOG.md` row and the `state/current` row ran together ("...the notes for each one.state/current ..."). Put `state/current` back on its own line, and check the rest of the file map for the same break.
- **Rename:** every "Waystation Guild" / "Waystation" in the branch's files (README.md, CHANGELOG.public.md, CLAUDE.md, CLAUDE.local.md, MODIFYING.md, bin/ws, config.sh, projects/agentic-workspace-v2.conf) becomes "Crafting Guild"; a slug or repository name becomes `crafting-guild`. Leave `plans/` alone. Afterwards `git grep -i waystation` outside `plans/` finds nothing.
- README.md:95: say `.gitignore` ignores `runs/`, `state/` and logs (it also ignores `*.log`).
- `lessons/builder.md` (and any other text file you touched) ends with a newline.
- selftest: a check that `ws review`'s prompt includes `lessons/reviewer.local.md` after `lessons/reviewer.md` (a dry-run or prompt-print path like the dispatch one), and a check that no `RELEASE_PATHS` entry in any `projects/*.conf` names a `*.local.*` file or `config.local.sh`, so a private file cannot be published by mistake.

## Commands
`bash scripts/selftest.sh`, `git grep`, `git ls-tree`, `git add`, `git commit`, `bash -n`, `shellcheck`. One command per Bash call.

## Done when
MODIFYING.md's file map has one row per line; the name is Crafting Guild everywhere outside `plans/`; the README line and the newlines are fixed; both new selftest checks exist and the selftest passes; the public-tree scan from the first round is still clean (save it again in `.ws-evidence/`).
