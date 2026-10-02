# Character generator: a public build (comments stripped, leak check)

Track: light

`chargen/build.js` inlines the scripts into one self-contained `chargen/dist/chargen.html`. That page is published on a public website, and its code comments name files in this private repository (`docs/RULES.md`, `rules/v1/synthesis.md`, …). Add a public build that ships the same page without comments and refuses to build if anything private leaks.

## Behaviour
- `node chargen/build.js --public` writes `chargen/dist/chargen.public.html`. `node chargen/build.js` with no flag keeps writing `dist/chargen.html` exactly as today (its test stays).
- The public page behaves identically: same markup, same CSS rules, same JavaScript behaviour. Only comments and the build notes are gone: JS comments (`//`, `/* */`, including the `/* file.js */` markers build.js adds), CSS comments, and HTML comments. Minifying whitespace and identifiers is fine if the tool does it safely; readable output is also fine. Licence and credit text in the visible page (the footer) stays.
- **Leak check:** the public build fails with a clear message (file and matched text) if the output contains any of: a home path (`/home/`, `/Users/`, `C:\\Users`), the current user's name and home directory (read at build time from `os.userInfo().username` and `os.homedir()`, never written into the code), an email address, an IP address or `localhost`, a private repo path (`docs/`, `rules/`, `resources/`, `plans/`, `runs/`, `.ws-evidence`, `synthesis`), or development wording (`builder`, `reviewer`, `TODO`, `FIXME`; match whole words and check each against the real page text first, since game text such as equipment names must never trip it). Keep the patterns in one list at the top of the build code, each with a short reason. Make sure the check runs on the final output, after stripping.
- `chargen/package.json` gets a `build:public` script.

## Prior art
Use **esbuild** (MIT; `transform` with `minify` or `minifySyntax`/`minifyWhitespace` and `legalComments: "none"`) for the inline JS and CSS rather than a hand-written comment stripper: string and regex literals that contain `//` or `/*` make regex stripping unsafe. Add it as a devDependency in `chargen/package.json` (`npm install --prefix chargen --save-dev esbuild` from the worktree root, so `chargen/package-lock.json` is committed and `node_modules/` stays ignored). HTML comments outside `<script>`/`<style>` can be removed with a simple regex, since the page's markup is ours and has no `<!--` inside attribute values (check that). If esbuild cannot be installed, say so and stop rather than hand-rolling a stripper.

## Tests
`node:test` in `chargen/tests/public-build.test.js`:
- the public output contains no `//` line comments, `/*` comments or `<!--` in its scripts, styles or markup (check by re-parsing with esbuild or by targeted assertions);
- the leak check catches each pattern category (feed it a sample string per category) and passes on the real output;
- the public page's scripts still work: load the public build's inlined scripts the way `tests/load.js` loads the sources (or extract and evaluate them) and check one seeded roll matches the snapshot for the same seed, and that `ui.render` produces the same sheet HTML as the source build for a seed;
- `node chargen/build.js --public` exits non-zero when a leak pattern is injected (e.g. via a test-only option or a temp copy of index.html).
Rebuild both outputs and commit both.

## Leave alone
`rules.js`, `ui.js`, `edits.js`, `data/` behaviour; everything outside `chargen/`.

## Commands
From the worktree root: `npm install --prefix chargen --save-dev esbuild`, `node chargen/build.js`, `node chargen/build.js --public`, `node --test chargen/tests/<file>.test.js` (one or several files), `git add`, `git commit`. One command per Bash call.

## Done when
`node chargen/build.js --public` writes a comment-free `dist/chargen.public.html` that behaves like the normal build, the leak check fails on each pattern and passes on the real page, both outputs are committed, and all tests pass.
