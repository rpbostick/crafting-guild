# Bike Weather: the wardrobe model, kept on the device, with export and import

No screens in this task: `src/model/` and its tests only. Leave `src/screens/`, `src/ui/` and `src/weather/` alone.

The app needs a wardrobe of the user's own clothing: each item made from a garment template, with a name and a colour the user chooses, swappable in and out of outfits. Today `src/model/` has `Garment` (id, name, warmth, wind and water ratings, optional brand and model), `Outfit`, `ComfortRating` and an in-memory `WardrobeStore`. This task makes the wardrobe real and durable.

Read first: `README.md`, everything in `src/model/`, `jest.config.js`, `package.json`.

## What to build
1. **Garment templates** (`src/model/templates.ts`): a small catalog of the kinds of garment a wardrobe item can be. Each template has an id, a label, the body region it covers (head, neck, torso, hands, legs, feet), a layer role (base, mid, outer, shell, accessory), the modes it suits (ride, everyday or both), and default warmth, wind and water ratings. About twenty templates across ride and everyday (for example: short-sleeve jersey, long-sleeve jersey, base layer, thermal jacket, rain shell, wind vest, bib shorts, tights, tee, sweater, coat, jeans, shorts, gloves light and warm, cap, beanie, shoes, overshoes, arm warmers). The default ratings are provisional: a separate research report will set them; say so in one comment at the top and keep them in one table so they are easy to replace.
2. **Garment**: add `templateId` (must name a template) and `color` (a `#rrggbb` string). Name, colour and ratings are the user's to change; a new garment made from a template starts with the template's label and ratings. Keep `brand` and `model`. Existing validation stays strict: a bad record throws with a message that names the field.
3. **Outfit rules**: an outfit may layer several garments on one region, but not two garments with the same region and layer role; the error names both garments.
4. **A device store** behind the existing `WardrobeStore` interface, so the in-memory store stays for tests. It must work in Expo Go on iOS and Android, in the Expo web preview and under Jest. One versioned document (a schema version, garments, outfits, ratings), written after each change; a store opened on a document from an older version migrates it; a document it cannot read throws rather than being silently replaced.
5. **Export and import**: `exportWardrobe(store)` returns the versioned JSON text; `importWardrobe(store, text, mode)` with mode `replace` or `merge` validates every record before changing anything and throws with the reason when the text is not a wardrobe. The export holds garments, outfits and ratings and nothing else: no place, no coordinates, no device identifiers. A function `describeExport(text)` returns the counts and the list of what the file contains, for the screen that will show it.
6. **A starter wardrobe**: `starterWardrobe(mode)` returns a handful of garments made from templates, for a first run.

## Privacy rules
Never log garments, ratings or measurements. The export carries no location history. Comfort ratings keep conditions only, as today.

## Tests
Unit tests beside the code (`src/model/*.test.ts`): templates are consistent (unique ids, ratings in range, every region covered for each mode); garment validation including `templateId` and `color`; the outfit rule; the device store against a fake of its storage (round trip, migration from an older version, an unreadable document throws); export then import round trip in both modes; import refuses bad text without changing the store; the export contains only the allowed keys. Run `npm test` and `npm run typecheck`.

## Prior art
Reuse rather than write:
- **Storage**: choose between `@react-native-async-storage/async-storage` (MIT) and `expo-sqlite` with its key-value store (MIT), both installable with `npx expo install`; `react-native-mmkv` needs a development build and does not run in Expo Go, so it is out. Pick the one that meets point 4 with the least code, check that Jest can run with its official mock, and say in the result which and why.
- **Validation**: the model's own `valid…` functions already check every record; use them for import. `zod` (MIT) is the alternative if a schema with error paths turns out shorter; say which was used.
- **Ids**: `expo-crypto`'s `randomUUID` (MIT) if ids must be generated here; otherwise leave id creation to the caller.

## Commands
One command per Bash call: `npx expo install <package>` for the chosen storage package, `npm test`, `npx jest <path>`, `npm run typecheck`, `npx tsc --noEmit`, `git add`, `git commit`, `git status`, `git diff`, `grep`, `ls`, `cat`.

## Done when
`npm test && npm run typecheck` pass; the model has templates, named and coloured garments, the outfit rule, a device store with migration, export and import with `describeExport`, and a starter wardrobe, all with tests; the README's model section lists them; and the result states the storage package chosen and the number of tests with the log it comes from. Safe to re-run from scratch.
