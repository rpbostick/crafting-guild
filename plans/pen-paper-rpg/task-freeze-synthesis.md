# Freeze the original merged rules text

Track: light

`rules/v1/synthesis.md` is the original merge of three games' rules and must stay exactly as it is, as a reference. Decisions and later revisions are kept elsewhere (the review tool's decisions and notes, and generated texts built from them), never by editing this file. Git tag `synthesis-v1-original` marks the commit that added it.

## What to do
- `tests/synthesis-frozen.test.js` (`node:test`): computes the SHA-256 of `rules/v1/synthesis.md` and asserts it equals `7baa44b283001366378a28f9f0aa71462d380a20e35c70cb2ef5610e4438099c`. The failure message says the file is the frozen original, names the tag, and says changes belong in a new file. Show it failing once (for example against a temporary copy with one character changed, passed through an environment variable or a function parameter, not by editing the real file), then passing.
- `rules/v1/README.md`: three or four lines: `synthesis.md` is the frozen original merge (tag `synthesis-v1-original`); it is never edited; decisions live in the review tool and its exports; revised texts are new files generated from the original plus decisions.

## Prior art
None needed: a checksum assertion with Node's built-in `crypto`.

## Leave alone
`rules/v1/synthesis.md` itself, and everything outside the two new files.

## Commands
`node --test tests/synthesis-frozen.test.js`, `git add`, `git commit`. One command per Bash call.

## Done when
The test passes on the real file, has been seen failing on a changed copy, and the README is committed.
