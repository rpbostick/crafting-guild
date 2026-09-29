# skywright demo: theme round 2 (host mode, flash, contrast)

Track: light

Continue branch `agent/sky-theme`; read your commits and `.ws-evidence/` first. The review said merge. This round adds what the host site needs and settles your open questions.

## Your open questions (decided)
- `palettes.ts` holding the palettes is accepted. So is `app.json`'s icon colour.
- Darken the light accent until links reach AA on the light background (about `#1a5fd0`; check it with the test).
- **No flash:** add a custom web `index.html` for the export (Expo's `example/public/index.html` mechanism). It needs an inline script in `<head>` that reads `localStorage.theme` and sets `data-theme` on `<html>`, plus a `<style>` giving `html, body` the light and dark page backgrounds: dark under `:root[data-theme='dark']` and under `@media (prefers-color-scheme: dark) { :root:not([data-theme]) … }`. These two background colours may appear there. Add a test that they equal `palettes.ts`'s values, so they can't drift. Keep everything the default template had (the `#root` styles and the noscript).

## Host mode (web only; native unchanged)
The demo is published inside a host site that draws its own controls and an animated backdrop behind the app. The host signals this with attributes on `<html>`, set before the bundle runs:
- **`data-host-controls`**: hide the app's own theme switch. Follow `data-theme` on `<html>` live (a `MutationObserver`): absent means System, `"light"` or `"dark"` otherwise. The host's switch changes that attribute and writes the same `theme` key.
- **`data-host-backdrop`**: the page and the app's root/scroll backgrounds become transparent, so the backdrop shows around the sections. Each section stays **opaque in the middle**, but its outer **~1 cm (38 px)** is slightly translucent (surface colour at about 70% alpha), fading to fully opaque inward. A smooth fade is preferred. On web, check whether react-native-web passes through `backgroundImage` / `experimental_backgroundImage` (a linear or radial gradient) or a `maskImage`. If neither works, use a stepped version (a translucent outer View and an opaque inner View inset by 38 px, the same corner radius). Say which you used.
- Without either attribute, nothing changes. Put the attribute reads in one small module with unit tests (attribute present or absent, a `data-theme` change is observed).
- Keep the switch in the header when run standalone. Under `data-host-controls`, leave about 280 px of room at the top right for the host's controls, so the title is never covered at 360 px wide.

## Review suggestions
- `test/example-palettes.test.ts:36`: use `%s` so ratios print with decimals.
- Run the same contrast pairs over `light` too.
- The dark `border`, and the light one if needed: reach 3:1 against the surface (WCAG 1.4.11), with a test pair.

## Evidence
You have no browser. Save the export's `index.html`, the host-mode test log, and a note on which edge technique worked.

## Commands
One command per Bash call: `npx jest <files>`, `npx tsc --noEmit`, `npm run demo:typecheck`, `npm run demo:export`, `npm run demo:export:site`, `node …`. Do not run `npm install` or `npx expo install`. Leave `src/` (the library), the root `package.json` and the `example/package.json` dependencies alone.

## Done when
There is no white flash in the exported `index.html`. Host mode works as described and is unit-tested. The contrast tests cover both palettes plus the borders. Type-checks are clean and both exports succeed.
