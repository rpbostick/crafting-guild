# reactbits-kit: ripple, sheet glide and spin for the sheet profile's components

The kit's `sheet` profile (used by a character-sheet page that registers ten React Bits backgrounds with the toybox library) regenerates Waves, Aurora, Iridescence, Threads, Balatro, LiquidChrome, Galaxy, Plasma, SoftAurora and RippleGrid. Today they take only a pointer position (mouse events or a pointer getter). The site profile's Waves already takes the full dynamics: a ripple-field displacement getter, sheet follow and sphere-spin sampling (`src/transforms/Waves/*`, modules `rippleField`, `clothFollow`, `sphereSpin`). The toybox library 0.5.0 passes plug-in backgrounds an inertial pointer and, optionally, ripple/sheet/spin state through `registerBackground` (see its README: https://github.com/rpbostick/toybox).

## Build
- New transforms (sheet profile; optional for others) so each of the ten components can take that state:
  - **Line/field components** (Waves, RippleGrid, Threads): the displacement getter (ripple and swirl), sheet offset and sphere-spin sampling, as the site's Waves does.
  - **Shader components** (Aurora, Iridescence, Balatro, LiquidChrome, Galaxy, Plasma, SoftAurora): a per-frame **coordinate transform getter** (offset, rotation, scale applied to the shader's UV/sampling coordinates) for the sheet glide and spin, and the ripple as a local UV displacement uniform where the shader structure allows; say per component what it takes.
- The React adapter: a `toyboxState` option that maps the toybox plug-in API's state to those getters, so a page wires all ten in one place.
- Keep the licence boundary: transforms only, no React Bits code in the repo.
- Version 0.4.0, CHANGELOG, README.

## Tests
Each new transform applies to the pinned upstream and type-checks; the sheet profile reproduces the previous components plus the new props; adapter mapping unit tests; the licence boundary test passes.

## Publishing note
This repository is the private development copy (`rpbostick/reactbits-kit-dev`). Do not push anywhere; the public release is made separately after an audit.

## Commands
`npm ci`, `npm install …`, `npx …`, `node …`, `bash scripts/<script>.sh`, `git add`, `git commit`. One command per Bash call.

## Done when
All ten components in the sheet profile accept the ripple, sheet and spin state, the adapter maps the toybox state to them, version 0.4.0, tests pass.
