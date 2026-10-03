# chargen-toybox: toybox 0.6.0 and reactbits-kit 0.4.0

Track: light

Two public releases to take in (read their READMEs after updating):
- **toybox 0.6.0**: the drawer and each toy open in their own windows (drag, resize, minimize, several toys at once; running cap); the dice tray shares the window code. `node chargen-toybox/scripts/update-toybox.js https://github.com/rpbostick/toybox/releases/download/v0.6.0/toybox-0.6.0.zip`.
- **reactbits-kit 0.4.0**: the `sheet` profile's ten React Bits components accept ripple, sheet glide and spin state; the React adapter's `toyboxState` option maps the toybox plug-in API's state to them. `npm install --prefix chargen-toybox --save-dev github:rpbostick/reactbits-kit#v0.4.0`, then `npx --prefix chargen-toybox rbx update`.

## Steps
- Update both; regenerate the components; wire `toyboxState` in `plugins/react-bits/` so all ten React Bits backgrounds get the ripple, sheet glide and spin the library's own backgrounds have (the Toys button opens the drawer window; the drawer's and toys' windows default to the open side when the sheet position is Left/Right, as the dice tray does).
- Rebuild both outputs.

## Tests
VERSION 0.6.0; `rbx check` passes on 0.4.0; the React Bits plug-in passes the toybox state (unit test with a stub); all chargen-toybox tests pass including the Firefox background cycling test.

## Commands
`node chargen-toybox/scripts/update-toybox.js <url>`, `npm install --prefix chargen-toybox …`, `npx --prefix chargen-toybox rbx …`, `node --test chargen-toybox/tests/<file>.test.js` (one or several), `node chargen-toybox/build.js`, `node chargen-toybox/build.js --public`, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
chargen-toybox runs toybox 0.6.0 and kit 0.4.0, the React Bits backgrounds get ripple, sheet glide and spin, both builds are rebuilt, and tests pass.
