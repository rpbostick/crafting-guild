# retrowright: cores research, licence fix

Track: light

The review of `docs/research/cores.md` found one blocking problem. The Method line (line 9) says every licence was read from the repository's own files in a shallow clone, but only angelo-wf/LakeSnes was cloned. The table (line 19) gives "MIT (LICENSE.txt)" for the dinkc64/LakeSnes fork too, and that fork is the recommended SNES core.

## What to do
1. Clone https://github.com/dinkc64/LakeSnes shallowly into `.ws-evidence/clones/LakeSnes-dinkc64`. Read its `LICENSE.txt` and the licence headers of the files the fork added (`tracing.c`, the CX4 files). Record what you find, with the file names, in `.ws-evidence/licences.md` and in the table row. If any added file carries a different licence or none, say so in the table and in the SNES recommendation.
2. Reword the Method line so it names the exceptions: the mGBA wasm port (the npm licence field only, line 32), the Cult-of-GBA BIOS (fetched, not cloned) and MesenCE (line 28, no file named). Better still, read MesenCE's licence file the same way and name it.
3. Suggestions that are small enough to do in the same pass: the fork's "90 commits, adds CX4" comes from the project page, so say so; in `.ws-evidence/licences.md`, replace the commit reference `1d0f933` with the current branch tip.

## Prior art
Not applicable: this corrects a research document.

## Commands
`git clone *` (into `.ws-evidence/` only), `cat *`, `ls *`, `grep *`, `head *`, `git add *`, `git commit *`, `git log *`. Read files inside a clone with `cat` or `ls` on their paths; `git -C` is not granted. One command per Bash call.

## Done when
- The dinkc64 fork's licence and the licences of its added files are each verified from the file itself and named in the table and in `.ws-evidence/licences.md`.
- The Method line is true for every row.
- Committed on the branch.
