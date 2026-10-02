# Research: historical prices, wages and costs for the equipment list

**Resume:** an earlier run of this task was cut off before it finished. Start with `git log` and `git status` in the worktree, keep the work already there (committed or not) if it is sound, and continue from it.

Track: light

The rules synthesis's price list (`rules/v1/synthesis.md`, Equipment sections; silver standard, starting money about 60 silver in WoD) should rest on real historical work on the prices of commodities, finished goods, labour and services, instead of the usual fantasy price list. Write `docs/research/prices.md`.

## What to find (use web search and web fetch; cite sources with URLs and dates read)
- Scholarly and well-documented sources on medieval and early-modern prices and wages: e.g. Gregory Clark's English prices and wages series, the Allen–Unger global commodity prices database, Robert C. Allen's welfare ratios, the "Medieval and Early Modern Data Bank", James E. Thorold Rogers' *A History of Agriculture and Prices in England*, Christopher Dyer's *Standards of Living in the Later Middle Ages*, the *Prices and Wages in England* (Beveridge), the Medieval Price List compilations (Kenneth Hodges' "Medieval Price List" for RPGs is a known reference: check its sources), *Mediaeval Lives*, and the RPG work that used them (e.g. ACKS's economy, Harn's price lists, *The Dungeon Alphabet*-era blog posts, Justin Alexander's "Medieval price" posts, the OSR "silver standard" discussions).
- Categories: staple food (bread, grain, ale, meat, salt), lodging and meals at inns, clothing and cloth, tools, rope, candles and lamp oil, horses and draught animals, carts and boats, arms and armour (sword, spear, bow and arrows, mail, plate, shield, helmet), books and parchment, writing materials, medicine; **wages** by trade (labourer, skilled craftsman, mason, soldier, archer, knight's service, clerk, servant), daily and annual; **services** (messenger, guide, scribe, physician, lawyer, ferry, tolls).
- The relation between coins: pennies, shillings, pounds, marks; a labourer's day wage as the unit; how prices changed over time (choose a reference period, e.g. England 1300–1400, and say why).

## Analysis
- A conversion to the game's silver standard: pick one anchor (e.g. 1 silver = a labourer's daily wage, or = 1 penny) and convert every item, showing the arithmetic.
- A proposed price list for the synthesis (gear, weapons, armour, services, lodging, hirelings), each with its historical basis and the conversion, plus a short "how much is a lot of money" table (a year's wages, a horse, a house, a sword) for GMs.
- Where historical prices break the game (e.g. plate armour, horses) and suggested game adjustments, labelled as adjustments.

## Output
`docs/research/prices.md`: summary and anchor, the proposed list as tables, sources cited per row or per category, and unverified figures marked.

## Prior art
This task is the prior-art search.

## Commands
Web search and web fetch for research. The project's own texts are at `/home/patrickb/pen-paper-rpg/resources/text/` (read by absolute path). `git add`, `git commit`. One command per Bash call.

## Leave alone
Everything except `docs/research/prices.md`.

## Done when
The file grounds a full price list for the synthesis in cited historical sources with a clear silver conversion, and is committed.
