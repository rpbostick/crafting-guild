# Bike Weather research fix: two false claims in the version 1 method, and its examples

Track: light

One file only: `docs/research/clothing-weather.md` on this branch. No code and no new research. Run `git merge main` first: main now has the wardrobe model (`src/model/templates.ts`), which the report must agree with.

## Blocking
1. **Line 705, example 2's feet.** Step 8 (line 641) admits any combination with at most one garment per region and layer, so light rain overshoes alone (feet, shell, warmth 1, wind 3, water 3) is a candidate that costs 0.2 against the 2.4 shown for shoes plus overshoes; the method as written recommends overshoes with no shoes, and the result on line 707 is false for the stated rules. Add a wearability rule to step 8 beside the core base-layer rule (a feet shell or accessory needs footwear under it; say the same for any other region where an outer piece cannot be worn alone, such as leg warmers without shorts), then re-check every example against the corrected rules and fix what changes.
2. **Line 641, the search size.** "Twenty garments over six regions and five layers gives at most a few thousand combinations" is false for the report's own 19-garment ride wardrobe: by slot it is 104 × 8 × 3 × 12 × 2 = 59,904, over the 20,000 threshold on line 642. Correct the count, and say how the search stays small (the cost separates by region group apart from garments that cover several regions), or change the threshold; make the examples consistent with whichever is chosen.

## Also fix, same file
- Step 4's rain classes overlap (30 % with 1.0 mm/h is both "possible" and "showers"; a dry window also satisfies "R < 0.5"): state the order they are evaluated in.
- Line 636: "when T_cold and T_warm fall in the same band, the second term equals the first" is not generally true (a superfluous packable; everyday's wind threshold at 15 °C inside the 14 to 18 band): correct it.
- Line 708: example 2's gaps list only water shortfalls, but the light gloves are also one step short on wind; list every shortfall as "Missing garments" says.
- Line 693: example 2's inputs do not give "showers likely 30 to 45 minutes in"; reword the scenario so they do (for example a 15-minute series with 0.8 mm/h from minute 30 to 45).
- Line 714: "every alternative only adds excess" is not right once the wearability rule exists or not; restate it against the corrected rules.
- Line 354: "thin trousers (0.15–0.24)" should read thin to thick trousers, as §1.1's table has it.
- Lines 146 and 19: apparent wind is called a vector difference in one place and a vector sum in the other; use one term.
- Line 3: "every source was read" contradicts the summary-only tags below it; say consulted, and that the fetched pages are not saved with the report.
- Line 525: head the section "Open questions".
- **The wardrobe model.** The context section says garments have no body region and no layer role. On main each garment now names a template with one region (head, neck, torso, hands, legs, feet), a layer role and the modes it suits. Update the context, §3.1 and the migration question to say what is there and what the method still needs on top of it (the regions a garment covers, with core and arms split, and `packable`), and map the model's regions to the report's.
- The skywright names the report cites (`RideSummary` and its fields, `rideWindow`, `RIDING_SPEEDS_KMH`, `relativeWindKmh`, `feelsLikeAtSpeedC`, `windChillC`, `heatIndexC`) were checked against skywright's type declarations and exist; nothing to change there.

## Prior art
None needed: this corrects a report against its own rules and the repo's code.

## Commands
One command per Bash call: `git merge main`, `grep`, `cat`, `ls`, `git diff`, `git status`, `git add`, `git commit`. Nothing else.

## Done when
Both blocking claims are corrected, every worked example follows from the rules as written (say in the result which example results changed), the smaller fixes are in, the report agrees with `src/model/templates.ts`, and the change is committed.
