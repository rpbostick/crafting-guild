# reactbits-kit: transforms for the other seven components, and a React adapter

The kit (read `README.md`, `src/transforms/`, `src/ast/`, `src/modules/`, `bin/rbx.js`, `tests/`) has transforms for Waves, Aurora and Iridescence. Add the seven other React Bits backgrounds we customized, and a small adapter so a site can wire any transformed component to our modules.

## Reference (read by absolute path; never copy React Bits code into this repo)
- Customized copies of all ten: `/home/patrickb/pen-paper-rpg/chargen-toybox/plugins/react-bits/vendor/reactbits/<Component>/`, with their change list `…/vendor/reactbits/CHANGES.md` (and `CHANGES-site.md` for the three site ones), pinned upstream commit `…/REACT-BITS-COMMIT`.
- How the character sheet wires them: `/home/patrickb/pen-paper-rpg/chargen-toybox/plugins/react-bits/{Effect.tsx,register.tsx,color.js,looks.js}`.

## Build
- **Transforms** for **Threads, Balatro, LiquidChrome, Galaxy, Plasma, SoftAurora, RippleGrid**, one per numbered change in `CHANGES.md` (per-frame colour getters, `paused` prop, accumulated clocks, pointer getter for drag-only feeding, …), in the same style as the existing ones (AST-based, fail loudly with the change name when upstream no longer matches).
- **Waves, Aurora, Iridescence:** if the character sheet's copies have changes the site copies don't, add those transforms too (the site's and the sheet's sets should both be reproducible from the kit; give each project's set a name in `reactbits-kit.json`, e.g. a `profile`).
- **React adapter** (`src/react/`, our code, MIT): `<KitBackground component={Waves} colors={…} pointer="drag" momentum ripple cloth paused />`-style wrapper or hooks (`usePointerFeed`, `useColorDrive`) that connect a transformed component's getter props to our modules (pointerFeed, momentum, rippleField, clothFollow, colorDrive), so a site writes a few lines per background. Document both raw use and the adapter.
- **`rbx add` for all ten**, `rbx list` shows them with their transforms.

## Tests
Each new transform applies to the pinned upstream and type-checks; the full set per component reproduces the behaviour of the reference copy (exported props and key code paths); the adapter wires getters correctly (unit tests with a stub component); `rbx add` for all ten into a temp project from `.upstream/`. The repo still contains no React Bits code (extend the existing guard test to all ten component names). CHANGELOG 0.2.0, README updated.

## Prior art
The kit's own foundation; the reference copies' change lists.

## Commands
`npm ci`, `npm install …`, `npx …`, `node …`, `bash scripts/<script>.sh`, `git add`, `git commit`. One command per Bash call.

## Done when
`rbx add` reproduces our customized versions of all ten components from the pinned upstream, the React adapter connects them to our modules, the repo has no React Bits code, and the tests pass.
