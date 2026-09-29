# colorwright: a relative "More demos" link, a static React Bits credit, American spelling

Track: light

The static build is published on the demo site (Patrick, 2026-09-29).

1. **Relative link.** `MORE_DEMOS_URL` becomes `/`, the site's root on the same origin, so a local preview's link stays local. Remove the leak-check allowance added for the old absolute URL (`scripts/demo-site.sh` and `static-leak-check.sh`), so the leak check again allows no word of the author's name anywhere. Update the README line and the tests that expected the absolute URL.
2. **Credit.** Under `data-host-backdrop` only, add a static line to the footer, next to the Open Peeps credit: "Background animation: React Bits (reactbits.dev)", with `https://reactbits.dev` as the link. Standalone and backend mode show nothing new.
3. **American English in everything visible:** page text, `aria-label`s, titles and the README. For example: "Colour theme" → "Color theme", colour → color, licence → license, grey → gray. Leave code identifiers and CSS custom property names alone unless they are also shown to users. List every string you changed.

## Check
Run `bash scripts/build-static.sh` (it ends with "leak check: clean"), then `node --test "frontend/tests/*.test.js"` and `node scripts/theme-e2e-check.js --static --port 8791`. Update any test that asserts the old strings.

## Commands
One command per Bash call: `bash scripts/build-static.sh`, `bash scripts/static-leak-check.sh`, `node …`, `node --test …`, `backend/.venv/bin/pytest …`, `curl …`. Do not install packages.
