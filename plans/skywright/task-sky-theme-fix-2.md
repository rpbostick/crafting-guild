# skywright demo: theme round 3 (chip outlines, credits on a panel)

Track: light

Continue branch `agent/sky-theme`; read your commits and `.ws-evidence/` first. `npm run demo:export:site` is granted now (the orchestrator ran it on 34eaf7f and it exported cleanly).

## Blocking (review of 34eaf7f)
- The ThemeSwitch chips draw their outline on `colors.background`, not on a section. In light, `#8595a8` on `#e3ebf3` is about 2.55:1, below the 3:1 the code claims. Add border-on-background pairs to `BORDER_PAIRS` for both themes and adjust `light.border` (and dark, if needed) until border-on-surface and border-on-background both reach 3:1. Update the ratios quoted in `palettes.ts` and fix its comment so it states exactly which pairs are tested. Save a failing run of the new pairs on the old value.

## Your open question (decided)
- Under `data-host-backdrop`, put the credit lines (Open-Meteo and "← More demos") inside a section-style panel with the same translucent edge, so they never sit straight on the backdrop. Do the same for the title row, keeping the space for the host's controls. Standalone, nothing changes.
- The host's controls are at most **64 px** tall. Set `HOST_CONTROLS_HEIGHT` to match.

## Suggestions
- `test/example-host.test.ts`: save one failing run (for example, `attributeFilter` removed) as evidence.
- Narrow the scope comment in `palettes.ts` to the pairs actually tested, and list what is left out (the selected-chip fill as a boundary, ActivityIndicator's default colour).

## Commands
One command per Bash call: `npx jest <files>`, `npx tsc --noEmit`, `npm run demo:typecheck`, `npm run demo:export`, `npm run demo:export:site`, `node …`. Do not run `npm install` or `npx expo install`. Leave `src/` (the library), the root `package.json` and the `example/package.json` dependencies alone.

## Done when
The border pairs reach 3:1 in both themes and are tested. Under host-backdrop the credits and title sit on panels. Both exports succeed and the type-checks are clean.
