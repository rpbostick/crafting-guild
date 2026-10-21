# Private settings, sourced after config.sh. Not part of a public release.
WS_ATTRIBUTION_RE="\\bpatrick\\b|\\bbostick\\b|(^|[^@/.])rpbostick\\b([^/:]|$)"   # names only, whole words; roles ("the operator") are the reviewer's rule 19, not a refusal
WS_BENCH_HOURS="${WS_BENCH_HOURS-22-07}"   # the bench runs at night only (WS_BENCH_OUTSIDE=wait): days are for development work
WS_BENCH_OUTSIDE="${WS_BENCH_OUTSIDE-wait}"
