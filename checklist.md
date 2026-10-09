# Review checklist

Twenty rules. A rule is removed when it proves wrong and fine-tuned when it proves imprecise; rules are not folded into one another to make room. A rule earns its place by having cost real time twice; the twenty are distilled from two earlier checklists of 101 and 46 rules.

1. No silent fallbacks where missing or invalid data should fail loud (`.get(x, 0)`, bare `except: pass`, default branches that hide a bad state).
2. A test proves it can fail and tests the real thing: the branch shows a failing run before the fix, or the task log does, and the test exercises the production code path, not a copy or a fixture alone.
3. Every claim of scope or verification in a commit message, docstring or doc ("all", "every", "verified", "confirmed", a count) matches the diff and the evidence saved with it (under `.ws-evidence/` in the worktree, or committed).
4. Every file, path, script or command referenced in prose exists at that commit.
5. A change to the shape of persisted data (a table column, a JSON field, a manifest key) migrates old data or fails loud on it, with a test for the old shape.
6. Deleting or renaming a file, function or route is followed by a grep for every reference, and they are updated in the same change.
7. A bug fix carries a regression test. A refactor that claims to preserve behavior leaves the existing tests unchanged and passing.
8. A docstring states a non-obvious why (a constraint, a workaround, an invariant), never restates what the name and signature already say. No docstrings for completeness.
9. One responsibility per function. No catch-all `utils` or `helpers` modules. No single-letter names outside a trivial loop counter.
10. A UI change re-checks every code path that resets or defaults state (a click handler that re-runs a defaulting function is the known bug class), and regenerates any icon, thumbnail or render that depicts the thing that changed.
11. An asset carries its license trail; an SVG is well-formed; "looks correct" is backed by a render the reviewer can open (in `.ws-evidence/`, or committed when the task asked for it), not asserted.
12. A read-check-write on a file that more than one process can touch takes a lock.
13. Imports fail loud. No `try/except ImportError` that logs and continues.
14. Broad staging (`git add -A`, `git commit -a`) does not sweep in logs, databases, scratch files or unrelated edits.
15. A check worth running twice is code that re-runs itself. An e2e script, probe, render comparison or approved render the branch relies on is a test, or a committed script the project's test command runs; a one-off check stays in `.ws-evidence/`. Evidence runs go through `ws-run`, which records each command's exit code (a count cannot tell a clean run from one that aborted).
16. A commit that answers a review finding fixes the finding; it does not reword the claim the finding was about.
17. Dates written into docs are the author's local calendar date from `date` (`TZ=$WS_TZ date` when `config.sh` sets `WS_TZ`), never the UTC date after 18:00 local.
18. No secrets, credentials, absolute home-directory paths or personal identifiers in tracked files.
19. Tracked files state reasons, never who asked, decided or approved, or when: no names outside intended credits, no "the operator", no dated decisions or quotes. A fixed choice reads "Deliberate: <reason>".
20. New code does not reimplement what a maintained open-source library already does (a diff, a Markdown or date parser, a CSV reader, an HTTP client, a UI widget) unless the task's `## Prior art` section says why. A hand-written replacement without that reason is a finding; name the library and its licence.
