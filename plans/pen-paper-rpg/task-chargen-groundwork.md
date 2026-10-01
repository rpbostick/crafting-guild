# Character generator: groundwork (move, split into data and rules, seedable dice)

`resources/wod-chargen/` holds a working character generator for *World of Dungeons* (1979): one self-contained page, `src/index.html`, with all rules logic in a pure `roll(choice, weird)` function, data tables beside it, and 16 `node:test` tests (`tests/generator.test.js`, loaded through `tests/load.js` in a `vm` sandbox) checked against a paraphrased rules spec, `docs/RULES.md`. Read all of them first, and `resources/wod-chargen/NOTES.md` (the generator's earlier project notes; its content policy no longer applies, everything else is useful background).

The game's rules are being merged from three games into `rules/v1/synthesis.md` (many more classes, skills and abilities, still being decided). This task prepares the generator so the merged classes, and later a career table, can be added as **data** without rewriting code. It does not add any new classes or rules.

## What to do
1. **Move** the generator out of `resources/` (which is for source material) to `chargen/` at the repo root, with `git mv`, keeping its history. Update its README and any paths.
2. **Split** the page into modules, each loadable both in the browser and under Node (the same UMD-style pattern `site/*.js` uses on the open branch: `module.exports` under Node, a global in the browser):
   - `chargen/data/wod1979.js`: every rules table (attributes, skills, abilities, classes, weapons, armor, items, kits) as plain data, with the class structure explicit: granted skills, fixed abilities, the ability choice list and how many to choose. This is the shape the merged classes will later use, so make it general enough for a class that has fixed abilities plus "choose N of M", two granted skills, or a restriction (as in `rules/v1/synthesis.md`'s class entries; read its "Classes" section to check the shape fits, but do not add those classes).
   - `chargen/data/flavor.js`: the original name, spirit, quirk and motivation tables.
   - `chargen/rules.js`: `roll()` and its helpers, pure, taking the data and a random source as parameters.
   - `chargen/ui.js` and `chargen/index.html`: rendering and the page.
3. **Seedable dice.** All randomness goes through one random source passed into `roll()`. Add a seed: the page reads `?seed=<text>` (or makes one), shows it, and offers a "copy link" that reproduces the same character. A re-roll makes a new seed.
4. **Build** a single self-contained file `chargen/dist/chargen.html` (everything inlined, no external scripts, no fetch) with `node chargen/build.js`, and commit it. It must work opened straight from disk.
5. Keep `docs/RULES.md` (moved with the rest) as the spec; drop its "do not paste" content-policy line, which no longer applies.

## Prior art
- **No existing World of Dungeons generator** was found to reuse (searches on GitHub and the web turned up D&D 5e generators only, a different system); this generator, already written, is the base.
- **Seeded random numbers:** use the sfc32 algorithm (public domain, from PractRand; the same generator `rand-seed`, MIT, uses) with a short string-to-seed hash (cyrb128, public domain), inlined in `chargen/random.js` with a comment naming both and their sources. Deliberate: the whole need is about 20 lines, the page must stay one self-contained file, and `seedrandom` (MIT) is unmaintained since 2019 and larger than the code it would replace. If you find a maintained, small, MIT/BSD library that can be inlined at build time with no loader, say so in `open_questions` instead.
- **Dice notation libraries** such as `@dice-roller/rpg-dice-roller` (MIT) are not needed: the generator only rolls pools of d6. Do not add one.
- **Build:** follow the same inline-everything approach as `scripts/build-review.js` on the open `agent/ppr-diff-tool` branch if it is on main when you start; otherwise write a small equivalent. One shared build step comes later, in a separate tool.

## Tests
- Move the existing tests to `chargen/tests/` and keep all 16 passing against the new modules (update `load.js` to load the modules instead of the inline script). Run them once before changing anything and save that run.
- Add: a fixed seed produces the exact same character twice and a known snapshot of `asText()` (the snapshot proves the refactor changed nothing that a seed would show); different seeds differ; the data file passes a shape check (every class's abilities exist, every kit fits 60 silver); the built `dist/chargen.html` contains no `<script src` and no `fetch(` and is up to date with the sources.
- Run with `node --test chargen/tests/`.

## Leave alone
`rules/`, `site/`, `docs/research/`, the other files in `resources/`.

## Commands
`git mv`, `node --test chargen/tests/` (and single test files), `node chargen/build.js`, `git add`, `git commit`. One command per Bash call.

## Done when
The generator lives in `chargen/`, split into data, rules, random and UI modules, rolls reproducibly from a seed with a shareable link, builds to one self-contained file, and all old and new tests pass.
