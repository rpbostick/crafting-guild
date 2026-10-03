# chargen-toybox: use the public reactbits-kit v0.3.0

Track: light

`chargen-toybox/package.json` pins `github:rpbostick/reactbits-kit#v0.2.1`, which now lives in the renamed private repo `rpbostick/reactbits-kit-dev`. The kit is public at **`github:rpbostick/reactbits-kit#v0.3.0`** (one audited commit; same API plus the site profile sync and `sphereSpin`). Switch to it.

## Steps
- `npm install --prefix chargen-toybox --save-dev github:rpbostick/reactbits-kit#v0.3.0` (package.json and lockfile); keep any npm script-policy entry the kit's `prepare` needs.
- `npx --prefix chargen-toybox rbx update` for the `sheet` profile; `rbx check` passes; commit regenerated components if they changed (they should not, apart from CHANGES.md headers).
- README: the kit's public URL.

## Tests
All chargen-toybox tests pass, including the `rbx check` test and the Firefox background cycling test. Rebuild both outputs and commit them.

## Commands
`npm install --prefix chargen-toybox …`, `npx --prefix chargen-toybox rbx …`, `node --test chargen-toybox/tests/<file>.test.js` (one or several), `node chargen-toybox/build.js`, `node chargen-toybox/build.js --public`, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
chargen-toybox installs the public kit v0.3.0, components match it, both builds are rebuilt, and tests pass.
