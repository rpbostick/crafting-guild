# Character sheet: art style switch, theme switch, printer-friendly print, blank sheet, links

Continue on this branch (the character on the redrawn, letter-width World of Dungeons sheet). New assets are committed in `chargen/assets/`:
- `wod-sheet-bw.png`: the printer-friendly black-and-white sheet from the official B&W PDF, 1350 × 2250 px at 300 dpi, the same crop and pixel positions as `wod-sheet.png` (grey bars, black lettering, white boxes).
- `paper-texture.jpg`: the worn paper scan from the color PDF (1400 × 1810, portrait, with a fold and speckles), for the color style's page background.

## Behaviour
- **Art style switch** on the sheet (a small two-way toggle at the top edge of the sheet, labelled "Color" and "Printer friendly"):
  - Color: the current teal art on the worn paper texture (`paper-texture.jpg` as the page background behind the sheet, covering the page; the white boxes stay readable).
  - Printer friendly: the B&W art: frame, bars and lettering in the B&W PDF's greys and black on plain white. Take the cropped lettering for this style from `wod-sheet-bw.png` the same way as from `wod-sheet.png`, and sample its grey for the bars.
  - The lines (frame, boxes, ruled lines, field positions) are identical in both: only colors, lettering images and background change. Default: Color. The choice is remembered per browser (`localStorage`, wrapped in try/catch) and is not part of the link.
- **Theme switch** in the controls above the sheet: a three-way segmented control "Light / Dark / System" (System default), remembered per browser. It changes the page around the sheet and the controls (the existing light and dark tokens), never the sheet itself and never the print.
- **Print uses the printer-friendly art by default**, whatever the switch shows: switch to it on `beforeprint` (and in `@media print`) and restore the chosen style on `afterprint`. Print is always light, one Letter page, no controls.
- **"Print in full color" checkbox** next to the art switch, unchecked by default and remembered per browser: when checked, printing (character and blank sheet alike) uses the Color art on the worn paper instead. Set `print-color-adjust: exact` (and `-webkit-print-color-adjust: exact`) on the sheet for this mode so the paper texture and teal bars print without the person having to turn on the browser's "Print backgrounds" option; check the printed output keeps the boxes readable.
- **Print blank sheet** button in the controls: prints the sheet (printer friendly, or full color when that box is checked) with every field empty (no name, values, marks, weapons, gear, notes, coin; LEVEL, NEEDED FOR NEXT LEVEL and XP empty too), then restores the character on screen. It does not change edits or the link.
- **Filled-in text looks like the original generator's sheet:** Courier Prime (already loaded) in the original indigo ink (`--ink: #3B2A7A`) with its "spirit-duplicator ink bleed" (`text-shadow: 0 0 1.2px rgba(59,42,122,.28)`), not thin black. Name, class, level and the attribute values bold; other fields regular weight, slightly heavier than now if it reads thin. Check Courier Prime actually renders in the sheet fields (not a Courier New fallback). In the printer-friendly art and its print, the same font and weight in a near-black ink (`#1E1A2E`, lighter bleed) so it prints crisply on any printer; in Color and full-color print, the indigo.
- **Equipment pre-fill is one paragraph:** items separated by commas, wrapping onto the ruled lines (not one item per line). Repeated items are merged with a count in parentheses: two "Quicksilver (1 dose)" become "Quicksilver (2)"; an item with no count bought twice becomes "Chalk (2)"; an item that already carries a count adds them ("Torches (4)" twice → "Torches (8)"). Do the merge in the UI's equipment text (`edits.js` base fields or `ui.js`), not in `rules.js`, so the roll and the snapshot are unchanged; Copy as text uses the same merged list.
- **Links** in the footer line, which stays one line: "Built on *World of Dungeons* by John Harper (free PDF on itch.io), CC BY 3.0. The same seed, class and quirk setting always roll the same character." The title and "free PDF on itch.io" both link to `https://johnharper.itch.io/world-of-dungeons`; "CC BY 3.0" links to the licence. If it no longer fits one line at Letter width, shorten the second sentence to "Same seed, class and quirk: same character." Do not host or link any PDF file directly.

## Design
- Build inlines the new images as `data:` URIs like the others; keep the page one file and the public build's leak check passing. Mind the size: compress if the built page grows past about 1.5 MB, and say what it is.
- Keep the art-style colors as CSS custom properties on the sheet (`--sheet-ink`, `--sheet-bar`, …) switched by one attribute (`data-art="color|bw"`), so print, blank print and the switch share them.

## Prior art
Character-sheet sites commonly offer the sheet in color and grayscale/ink-saver versions (e.g. Fast Character), with ink saving as the default; here that is one checkbox. `prefers-color-scheme` with a `data-theme` override is the usual light/dark/system pattern; `beforeprint`/`afterprint` events (all current browsers) plus `@media print` for the print-time art swap. No library needed.

## Tests
UI tests through the stub window: the art switch sets `data-art` and remembers it; the theme switch sets `data-theme` (or removes it for System) and never touches the sheet; `beforeprint` selects the B&W art and `afterprint` restores it; the blank-print path renders a sheet with every field empty and restores the character after; with "Print in full color" checked, `beforeprint` keeps the color art and the box state is remembered; the footer text and both itch.io links; the equipment pre-fill is a comma-separated paragraph with merged counts (Quicksilver (2), an uncounted duplicate, a counted duplicate); the build inlines every image and the public build passes. Rebuild both outputs and commit them. Screenshots (one per call, absolute paths): `after-fix3-color.png`, `after-fix3-bw.png` (with the switch set via its stored value or a test hook), `after-fix3-dark.png` (theme dark: the sheet unchanged), and `after-fix3-blank.png` if you can render the blank state on screen.

## Leave alone
`rules.js` behaviour, `data/`, the asset files, everything outside `chargen/`.

## Commands
`node --test chargen/tests/<file>.test.js` (one or several), `node chargen/build.js`, `node chargen/build.js --public`, `firefox --headless …` (as before), `git add`, `git commit`. One command per Bash call.

## Done when
The art switch flips between color-on-worn-paper and printer-friendly art with identical lines, the theme switch works without touching the sheet, printing always uses the printer-friendly art, a blank sheet can be printed, the footer links to itch.io, both builds are rebuilt, and the tests pass.
