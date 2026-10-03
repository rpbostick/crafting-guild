# chargen-toybox: install reactbits-kit from GitHub, not a sibling folder

Track: light

Continue on this branch. Review findings (blocking): `chargen-toybox/package.json` has `"@rpbostick/reactbits-kit": "file:../../reactbits-kit"`, which only resolves on this machine's main checkout (not in a worktree or a fresh clone), and `register.tsx` imports `@rpbostick/reactbits-kit/react/wiring.ts`; the README says a plain `npm install --prefix chargen-toybox` gets the kit, which is false.

The kit now ships compiled JavaScript: **v0.2.1** (`github:rpbostick/reactbits-kit#v0.2.1`; README in `/home/patrickb/reactbits-kit/README.md`), so a git install runs `rbx` and imports work without `.ts`.

## Steps
- `npm install --prefix chargen-toybox --save-dev github:rpbostick/reactbits-kit#v0.2.1` (replacing the `file:` dependency in package.json and package-lock.json).
- Imports use the compiled entry points (e.g. `@rpbostick/reactbits-kit/react/wiring`, no `.ts`).
- Regenerate the components with the installed `rbx` (`npx --prefix chargen-toybox rbx update`) and check there is no drift; keep the `rbx check` test.
- Fix the README lines about installing the kit (lines ~122 and ~204).

## Tests
All chargen-toybox tests pass, including the Firefox background cycling test and the `rbx check` test; a test (or the existing build test) that fails if package.json has a `file:` dependency. Rebuild both outputs and commit them.

## Commands
`npm install --prefix chargen-toybox …`, `npx --prefix chargen-toybox rbx …`, `node --test chargen-toybox/tests/<file>.test.js` (one or several), `node chargen-toybox/build.js`, `node chargen-toybox/build.js --public`, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
The kit comes from GitHub v0.2.1, nothing points outside the repository, components regenerate without drift, README is right, both builds are rebuilt, and tests pass.
