# chargen-toybox: get the React Bits backgrounds from reactbits-kit

`chargen-toybox/plugins/react-bits/` registers ten React Bits backgrounds with the toybox library, using customized copies kept in `plugins/react-bits/vendor/reactbits/` (with a change list). Our customizations now live in **reactbits-kit** (private repo `github:rpbostick/reactbits-kit`, tag `v0.2.0`; local checkout `/home/patrickb/reactbits-kit`, read its README), which recreates the customized components from upstream React Bits with `rbx add` and ships our modules and a React adapter. Switch the plug-in to the kit.

## Behaviour
- Add the kit as a dev dependency (`npm install --prefix chargen-toybox --save-dev github:rpbostick/reactbits-kit#v0.2.0`; if the private GitHub install fails, use `file:/home/patrickb/reactbits-kit` and say so).
- `chargen-toybox/reactbits-kit.json` records the components, the `sheet` profile and the pinned upstream commit; `npx --prefix chargen-toybox rbx add <Component> --to chargen-toybox/plugins/react-bits/components` (all ten) generates the customized copies there (committed: React Bits code inside a website project is allowed by its licence) with their `CHANGES.md`.
- The plug-in imports from `components/` and uses the kit's React adapter and modules where they replace the plug-in's own glue (colour wiring, pointer feed); delete `vendor/reactbits/` and glue the kit replaces.
- Add `npx rbx check` to the toybox's tests (a test that runs it and fails on drift; skips with a message when offline).
- Behaviour on the page is unchanged: all ten backgrounds render, take the colour wheel, react only to a drag on bare background, survive cycling (the Firefox cycling test must pass).

## Prior art
reactbits-kit (ours).

## Tests
All chargen-toybox tests pass, including the Firefox background cycling test; a test that `rbx check` reports no drift; no file under `plugins/react-bits/` differs from what `rbx add` produces. Rebuild both outputs and commit them.

## Commands
`npm install --prefix chargen-toybox --save-dev …`, `npx --prefix chargen-toybox rbx …`, `node --test chargen-toybox/tests/<file>.test.js` (one or several), `node chargen-toybox/build.js`, `node chargen-toybox/build.js --public`, `firefox --headless …` (absolute paths, one per call), `git add`, `git rm`, `git commit`. One command per Bash call.

## Leave alone
Everything outside `chargen-toybox/`.

## Done when
The plug-in's ten components come from `rbx add` with the sheet profile, `rbx check` guards drift, the old vendored copies are gone, the page behaves as before, both builds are rebuilt, and tests pass.
