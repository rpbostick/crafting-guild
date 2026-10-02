# Character generator: attribute methods (rolled, standard array random, standard array chosen)

Track: light

You are continuing on the branch that made every chargen field editable. Read `chargen/README.md`, `rules.js`, `edits.js`, `ui.js`, `index.html`, `build.js` and the tests first.

## Behaviour
- **Drop the dice line under each attribute** (the `3+4=7` text, `.roll`) and the `crit` highlight that marks a rolled 12. Nothing on the sheet shows the attribute dice any more. (The hit-dice "(rolled …)" note stays.)
- **A control at the top of the page** (with the other controls, above the sheet) picks the attribute method, three options, as a segmented button group or radio group with a visible label "Attributes":
  1. **Roll 2d6** (default; today's behaviour, values from `rules.roll()`).
  2. **Standard array, random**: the values `+2, +1, +1, 0, 0, -1` assigned to STR, DEX, CON, INT, WIS, CHA in a shuffled order, deterministic from the seed (draw from a separate stream, e.g. `random.fromSeed(seed + "/array")`, so `roll()`'s draw order and the snapshot do not change).
  3. **Standard array, choose**: each attribute becomes a `<select>` offering the six array values. The array is used exactly once: picking a value for one attribute swaps it with the attribute that held it. It starts from the same shuffled assignment as option 2.
- Switching back and forth is always possible. Switching method clears `attrs.*` free-text edits and keeps every other edit.
- Values display with a sign (`+2`, `+1`, `0`, `-1`); rolled values keep their current format.
- **CON recomputes hit dice and HP** in the array methods: hit dice = `data.hitDice.base` + CON value, **minimum 1** (CON -1 would otherwise give 0). Keep the rolled hit-die results as a prefix; any extra dice come from a separate seeded stream (e.g. `seed + "/hd"`), so raising CON adds dice without changing the ones shown. HP = highest kept die + ability HP effects, as in `roll()`. A hand edit of `hd` or `hp` still wins (edits overlay the derived values as they do today).
- **Copy as text** and **Copy link** follow the method: the link carries the method (e.g. `attrs=roll|array|pick`) and, for "choose", the assignment in attribute order (compact, e.g. `arr=2.1.0.1.-1.0` or similar URL-safe form). A link without these params is today's link. A malformed value falls back to Roll 2d6 with the existing short notice.
- **Roll a character** keeps the selected method and applies it to the new seed.
- Accessible: the method control is keyboard operable with a label; each `<select>` has an accessible label (`STR value` …); print shows the chosen values as plain text, no select chrome or method control.

## Design
- Put the array logic in a pure function, e.g. `rules.withAttributes(character, values, { data, random })` returning a new character with `attrs[*].v`, `hd`, `hdRolls`, `hp` recomputed. `roll()` stays unchanged in behaviour; its tests and the snapshot pass unchanged. The standard array lives in `data/wod1979.js` (`standardArray: [2, 1, 1, 0, 0, -1]`) and `validateData` checks it has one value per attribute.
- If anything besides hit dice/HP reads attribute values, recompute it too and say what.

## Prior art
Native `<select>` and a radio group / `<fieldset>` cover the controls; Fisher–Yates with the existing seeded `random.js` covers the shuffle. No library needed.

## Tests
`node:test` in `chargen/tests/`: `withAttributes` (array values applied; CON +2 gives more hit dice with the rolled prefix kept; CON -1 gives 1 hit die; deterministic per seed); random assignment is a permutation of the array and stable per seed; UI through the stub-window approach: no `.roll` dice line in the sheet; switching to each method; choosing a value swaps; link round trip for each method; malformed `attrs`/`arr` falls back; a hand-edited HP survives a CON change. Existing snapshot and build tests still pass. Rebuild `chargen/dist/chargen.html` with `node chargen/build.js` and commit it.
Take a screenshot of each method for the reviewer: `firefox --headless --window-size=900,1400 --screenshot <worktree>/.ws-evidence/after-<method>.png "file://<worktree>/chargen/dist/chargen.html?seed=abc&class=Wizard&attrs=<method>"` (one per call, absolute paths).

## Leave alone
`roll()` behaviour, everything outside `chargen/`.

## Commands
`node --test chargen/tests/<file>.test.js` (one or several files), `node chargen/build.js`, `firefox --headless …` as above, `git add`, `git commit`. One command per Bash call.

## Done when
The dice line is gone, the three methods work and travel in links and text, CON drives hit dice and HP in the array methods, the dist file is rebuilt, and all tests pass.
