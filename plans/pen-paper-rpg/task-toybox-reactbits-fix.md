# chargen-toybox: the React Bits backgrounds stopped working after the switch to the library

Track: light

`chargen-toybox/` now runs on the vendored toybox library (`vendor/toybox/`, README there) and registers the ten React Bits backgrounds through `registerBackground` in `chargen-toybox/plugins/react-bits/`. Reported after trying it: **a bunch of the React Bits backgrounds don't work anymore; clicking the background name button to reach them turns the background off** (nothing shows). The library's own backgrounds and the colour wheel work.

## Find and fix
- Reproduce in headless Firefox: cycle through every background with the name button and screenshot each; note which ten React Bits ones render and which don't (and any console errors).
- Find the cause (likely candidates: the plug-in's mount/size handling, React roots not created or unmounted on switch, ogl canvas not attached or sized to 0, the effects' colour getters or `paused` props not wired through the plug-in API, WebGL context loss on switching, the wash covering them) and fix it in the plug-in. If the cause is in the library, write it up precisely in `chargen-toybox/plugins/react-bits/NOTES.md` (what the library should change) and work around it in the plug-in for now.
- All ten React Bits backgrounds (Waves, Aurora, Iridescence, Threads, Balatro, Liquid Chrome, Galaxy, Plasma, Soft Aurora, Ripple Grid) must render, take the colour wheel's colours, respond to a drag that starts on bare background, and survive cycling through all backgrounds twice and toggling the background off and on.

## Tests
A Firefox test that cycles through every registered background (library and React Bits) twice, asserting a non-blank canvas for each (sample pixels differ from the wash colour) and no console errors; unit tests for whatever was broken in the plug-in. Rebuild both outputs and commit them.

## Commands
`node --test chargen-toybox/tests/<file>.test.js` (one or several), `node chargen-toybox/build.js`, `node chargen-toybox/build.js --public`, `node chargen-toybox/scripts/<script>.js`, `node .ws-evidence/<script>.js`, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
All ten React Bits backgrounds render and behave on the sheet after any amount of cycling, with a test that would have caught the failure, both builds rebuilt, tests passing.
