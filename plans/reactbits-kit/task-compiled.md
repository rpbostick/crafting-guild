# reactbits-kit: ship compiled JavaScript so a git or registry install works

Track: light

Installing the kit as `github:rpbostick/reactbits-kit#v0.2.0` succeeds, but `rbx` and the modules cannot run from `node_modules`: Node refuses to strip TypeScript types there (`ERR_UNSUPPORTED_NODE_MODULES_TYPE_STRIPPING`), and consumers import `@rpbostick/reactbits-kit/react/wiring.ts`.

## Behaviour
- Compile `src/` to `dist/` (ES modules + `.d.ts`) with `tsc` (or esbuild for JS + tsc for types; say which); `bin/rbx.js` runs the compiled CLI.
- `package.json`: `exports` map the public entry points to `dist/` (`.`, `./modules/*`, `./react/*`, the CLI), with `types`; consumers import without `.ts` (e.g. `@rpbostick/reactbits-kit/react/wiring`). Keep the source-path exports out.
- Make a git install build itself: a `prepare` script that compiles (npm runs it for git dependencies), and commit nothing generated; or commit `dist/` if `prepare` proves unreliable for git installs (test it and say which you chose).
- Bump to 0.2.1, CHANGELOG, README install section (`npm install -D github:rpbostick/reactbits-kit#v0.2.1`).

## Tests
A test that packs the package (`npm pack`), installs the tarball into a temp project, and runs `rbx list` and imports a module and the React adapter from it with plain `node` (no type stripping). Existing tests pass.

## Commands
`npm ci`, `npm install …`, `npx …`, `node …`, `npm pack`, `bash scripts/<script>.sh`, `git add`, `git commit`. One command per Bash call.

## Done when
A git or tarball install of 0.2.1 runs `rbx` and imports the modules and adapter as JavaScript, documented and tested.
