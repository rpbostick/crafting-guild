# skywright demo: a relative "More demos" link, a static React Bits credit, American spelling

Track: light

The web export is published on the demo site (Patrick, 2026-09-29).

1. **Relative link.** On web, "← More demos" links to `/`, the site's root on the same origin, so a local preview's link stays local. Native shows no link, as today.
2. **Credit.** Under `data-host-backdrop` only (the host-mode module in `example/src/`), add a static line to the credits panel, next to the Open-Meteo credit: "Background animation: React Bits (reactbits.dev)", with `https://reactbits.dev` as the link. Standalone shows nothing new.
3. **American English in everything visible in the demo:** text, accessibility labels and the export's `index.html` comments aside. For example: "Colour theme" → "Color theme", colour → color, licence → license. Leave code identifiers and the library in `src/` alone. List every string you changed.

## Check
Run `npx jest test/example-*.test.ts`, `npx tsc --noEmit`, `npm run demo:typecheck`, `npm run demo:export` and `npm run demo:export:site`. Update any test that asserts the old strings, and add one that the web link is `/`.

## Commands
One command per Bash call: `npx jest <files>`, `npx tsc --noEmit`, `npm run demo:typecheck`, `npm run demo:export`, `npm run demo:export:site`, `node …`. Do not run `npm install` or `npx expo install`. Leave `src/` (the library), the root `package.json` and the `example/package.json` dependencies alone.
