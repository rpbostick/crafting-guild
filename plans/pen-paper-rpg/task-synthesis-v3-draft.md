# Rules synthesis: a v3 draft from the balance pass and the research, for review

`rules/v2/synthesis.md` (block format, `status=open` marks; `README.md`, `CHANGES.md`) is the second version of the World of Dungeons-family merge. Since it was written: `rules/v2/BALANCE.md` (logic, consistency and balance findings with suggested fixes and a calculator in `scripts/balance/`), `docs/research/spells.md` (spell lists and a per-tier power budget; the heroic HDd6 damage concern with three options in §4.3), `docs/research/group-combat-and-tiers.md` (fast group battle and tier/scale drafts A–C), `docs/research/prices.md` (historical prices, 1 silver = 1 English penny, 1300–1400). The second review round has not happened yet. Write a **v3 draft** that turns these into proposals the reviewer can accept or reject.

## Rules for this draft
- **Do not decide any open item.** Every `status=open` block stays open. Where the balance findings or research give a recommendation for an open item, add it to that item's discussion as a recommendation (with the evidence), not as a decision.
- **Proposals, not edits by stealth:** every change from v2 is a proposal block (new or rewritten) whose discussion cites the BALANCE.md finding or research section that motivates it; anything that changes a number cites the calculator command and output. Mark each changed proposal `status=open` so it shows in the review page's open list.
- **Balance fixes:** apply BALANCE.md's suggested fixes for findings marked "breaks play" and "unbalanced" as proposals; "unclear" and "polish" ones too where the fix is wording only.
- **Spells:** add a "Spells" section with a starter list built to the research's per-tier budget in the game's terms (d6 damage, heroic +HD default, Classic optional), original text only (no copied spell text from Dungeon World, Class Warfare or OSE), about 6 spells per tier for tiers 1–3 and 4 per tier for 4–5, each with tier, range, duration, effect and cost. Present the heroic damage concern's three options in the Magic discussion with the calculator's numbers.
- **Group combat:** add an optional "Groups and scale" section from the research's Draft A (size steps and a break point) with Draft C (tier tag) as an optional module, each with its worked example, and an optional "Not to Be Fucked With"-style class ability (original wording) for the Fighter-family; all `status=open`.
- **Prices:** add a proposal replacing the equipment price list with the research's converted list (silver = penny anchor), keeping the old list in the discussion for comparison, with "how much is a lot of money" table; `status=open`.
- Keep v2 unchanged; v3 is `rules/v3/synthesis.md` with `rules/v3/CHANGES.md` (one line per changed or new id: what, why, source) and `rules/v3/README.md`.

## Tests
The format and coverage checks on v3 (add v3 to them); a test that every v2 `status=open` id is still open in v3; every changed or new proposal has a discussion citing a source; CHANGES.md covers every changed or new id; the calculator's tests still pass.

## Prior art
This is writing work in the project's own format; sources are the repo's research and balance files (cite them), plus web search and web fetch where a discussion compares with other games (cite URLs).

## Leave alone
`rules/v1/`, `rules/v2/`, `chargen*/`, `site/` (the review page gets v3 in a later task).

## Commands
`node --test tests/<file>.test.js`, `node scripts/<script>.js`, `node scripts/balance/<script>.js`, `git add`, `git commit`. One command per Bash call.

## Done when
`rules/v3/` holds a draft that turns the balance findings and research into cited, open proposals without deciding any open item, passes the format and coverage checks, and CHANGES.md accounts for every change.
