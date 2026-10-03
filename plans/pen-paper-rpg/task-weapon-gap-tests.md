# chargen and chargen-toybox: the suite runs the weapon-gap browser checks

Track: light

`chargen/scripts/check-weapon-gap.js` and `chargen-toybox/scripts/check-weapon-gap.js` measure the weapon damage gap in headless Firefox (about 2 s each) and exit non-zero when it is wrong, but no test runs them, so they run only when someone remembers.

## Prior art
`chargen-toybox/tests/toybox-firefox.test.js` and `backgrounds-firefox.test.js` already wrap a browser check script in a `node:test` test: spawn the script, assert exit 0 and its output line, skip with the reason when `firefox` is not on the PATH. Copy that pattern; add no dependency.

## Steps
1. Add `chargen/tests/weapon-gap-firefox.test.js` and `chargen-toybox/tests/weapon-gap-firefox.test.js`, each spawning its own folder's `scripts/check-weapon-gap.js` with a screenshot path in a temp directory (so the run leaves nothing in the repo), asserting exit 0 and the `weapon gap right in 8 slots` line, with a timeout, skipped where Firefox is missing.
2. In each folder's README, where the script is described, say the suite runs it.

Do not change the check scripts or the pages. If a check fails on the current build, stop and report it rather than editing the page.

## Tests
Both new tests pass; `node --test chargen/tests/weapon-gap-firefox.test.js` and the toybox one each finish in a few seconds.

## Commands
`node --test chargen/tests/weapon-gap-firefox.test.js`, `node --test chargen-toybox/tests/weapon-gap-firefox.test.js`, `node chargen/scripts/check-weapon-gap.js <png>`, `node chargen-toybox/scripts/check-weapon-gap.js <png>`, `git add`, `git commit`. One command per Bash call.

## Done when
`node --test` from the repo root runs both weapon-gap checks and passes.
