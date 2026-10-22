# The merge gate's test run gets a time limit

Track: light

`scripts/merge.sh` runs the project's `TEST_CMD` with no limit. When a suite finishes but its runner never exits (Jest's "did not exit one second after the test run has completed", from a test that leaves a timer or promise open), the merge waits forever while holding `runs/<slug>/merge.lock`, so every chain and bench behind it waits too. It happened on bike-weather: the suite finished in 145 s and the gate then sat for 24 minutes until the runner was killed by hand.

## Do
1. Run the test command under `timeout --kill-after=30 "$WS_MERGE_TEST_TIMEOUT"` (seconds; add `WS_MERGE_TEST_TIMEOUT="${WS_MERGE_TEST_TIMEOUT-1800}"` to `config.sh` with a comment, and to the env-overridable list in `scripts/lib.sh` next to the bench settings). The test command runs in its own process group, so the whole tree is killed, not only `bash -c`.
2. A timed-out run is a failed run: the merge is undone as for failing tests, and the message says the suite timed out after N s and names the log, with one line suggesting `--detectOpenHandles` (or the runner's equivalent) when the log's last lines show the tests finished.
3. The same limit on `merge.sh --test-only` (the bench's path).
4. A selftest case: a scratch project whose `TEST_CMD` is `sleep 60` with `WS_MERGE_TEST_TIMEOUT=2` fails the merge within a few seconds, leaves the branch unmerged and main where it was, and releases the lock. Build the scratch project the way the selftest's existing dispatch checks do (they make a scratch repo and conf under `$T`).

## Prior art
GNU coreutils `timeout` (`--kill-after`, exit 124 on timeout); CI systems' job timeouts (GitHub Actions `timeout-minutes`). `setsid` for a process group.

## Commands
`bash -n *`, `shellcheck *`, `bash scripts/selftest.sh`, `git add`, `git commit`. One command per Bash call.

## Done when
- A hanging `TEST_CMD` fails the merge after `WS_MERGE_TEST_TIMEOUT` seconds, the merge is undone and the lock released (selftest case).
- A normal suite is unaffected (the existing selftest passes).
- `MODIFYING.md` mentions the setting where it describes `merge.sh`.
