# Upgrading to a new OpenCode (or Claude) release

The procedure the 2.x migration produced. One version at a time, each step proved by a test or a live probe,
and nothing switched until the bench matches the current line.

## 1. Notice

- `ws maintenance` reports the installed OpenCode lines against the latest, the model list and privacy table
  against `runs/models.snapshot`, and pin drift (`WS_MIN_OPENCODE`, `WS_OPENCODE_MODEL_NAMES`,
  `WS_ALLOWANCE_LIMITS`). It never upgrades. Cold start says when it is stale.
- `ws models` names free-model additions and the privacy page to check.

## 2. Read before writing any task

- The current line's code paths: `scripts/opencode-builder.sh`, `scripts/opencode-review.sh`,
  `scripts/ask-run.sh`, the `ws oc` config in `bin/ws`, `scripts/opencode_run.py`, `scripts/wake.sh`.
- The target's own docs, fetched whole (`https://opencode.ai/docs/llms.txt`; for Claude,
  `https://code.claude.com/docs`). Record what the docs do not say as unresolved, not as inferred.
- For Claude Code, `docs/opencode-orchestrator.md` maps every harness mechanism; it is the checklist.

## 3. Map

- Write `docs/opencode-<version>-api.md`: one row per mechanism in `docs/opencode-orchestrator.md`, the new
  surface, the source (page or binary string), resolved or unresolved. The 2.x map is the model.
- Install the new version in a throwaway prefix with `XDG_DATA_HOME`/`XDG_CACHE_HOME`/`XDG_STATE_HOME` under
  it; never test against `~/.local/share/opencode`: a 2.x start runs its database migrations there, so a 1.x session
  already using the same database can fail with `SQLiteError: database is locked`.

## 4. Line and instructions

- `WS_OPENCODE_LINE` detects the line (1 or 2 today); `ws oc`, the builder, the reviewer and `ws ask` load the
  matching instruction set.
- `AGENTS.md` stays version-neutral; the mechanics live in `docs/opencode-1x.md`/`opencode-2x.md` (or the
  new version's file) and in `lessons/opencode-<line>.md`; the builder/reviewer text names that line's tool and
  flags. The project config must not override the line lesson away.

## 5. Config, plugins, launchers

- Translate every config shape (permissions, subagents, MCP), the plugin package, the review isolation and the
  builder's plugin wiring in one task per surface, each with its own review, so no surface is split across stages;
  what costs rework is an unverified premise, not the number of stages.
- The 2.x review runs from a tree that cannot load the reviewed branch's plugins.

## 6. Prove

- `ws doctor --parity` on the new line; `scripts/opencode_run.py` and the server probes against a live server;
  a builder dispatch, a two-pass review and a wake end to end; the full selftest.
- The bench: the same recorded tasks and reviews, compared with the current line. The quality gate
  is the merge verdict rate and the findings named, not wall time alone.

## 7. Switch and roll back

- Back up the OpenCode data directory before the first 2.x run; the database migration is one-way.
- Set the line, run the doctor and a smoke build, then the bench; keep the old binary and data backup until a
  week has passed.
- Any step that fails: restore the data backup and set `WS_OPENCODE_LINE` back; do not leave a half-migrated
  database.

## 8. Keep

- Add the version's project-specific lesson to a private lessons file and a generic line to
  `lessons/orchestrator.md` if one fits, and update `MODIFYING.md` with the files a version change touches.
