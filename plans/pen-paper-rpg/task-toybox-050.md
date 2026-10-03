# chargen-toybox: update to toybox 0.5.0

Track: light

Update the vendored library to the public release 0.5.0 (drag dynamics on every background: coasting pointer, ripple and swirl, sheet glide, gentle ball spin; `dist/` is now built for releases only).

## Steps
- `node chargen-toybox/scripts/update-toybox.js https://github.com/rpbostick/toybox/releases/download/v0.5.0/toybox-0.5.0.zip` (or the same zip at `/tmp/claude-1000/toybox-public/release/toybox-0.5.0.zip` if the download is blocked; say which).
- The React Bits plug-in backgrounds receive the library's inertial pointer through `registerBackground` as documented in 0.5.0's README; wire the extra state (ripple/sheet/spin) where it fits the React Bits components, otherwise leave them on the coasting pointer only. Say which.
- Rebuild both outputs.

## Tests
VERSION reads 0.5.0; all chargen-toybox tests pass, including the Firefox background cycling test and `rbx check`.

## Commands
`node chargen-toybox/scripts/update-toybox.js <url or path>`, `node --test chargen-toybox/tests/<file>.test.js` (one or several), `node chargen-toybox/build.js`, `node chargen-toybox/build.js --public`, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
chargen-toybox runs toybox 0.5.0, the backgrounds coast after a fling, both builds are rebuilt, and tests pass.
