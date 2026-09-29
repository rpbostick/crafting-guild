# colorwright: a darker light-theme --text-faint
Track: light

The demo site draws a translucent backdrop behind colorwright's panels. In the light theme, `--text-faint` (#687079, `frontend/style.css:23`) reaches only about 4.5:1 on a light panel even with no backdrop. So the site has to wash its backdrop out almost completely (0.93) to keep that text readable.

## Change
- Set light `--text-faint` to **#5f666e**. If that fails any existing contrast test, use the lightest gray of the same hue that passes. The dark theme's values stay as they are.
- In `frontend/tests/theme-contrast.test.js`, add a test that light `--text-faint` reaches **at least 5.2:1 on `#f2f2f2`**, the site's light panel edge (name it for what it guards: faint text over a lighter host backdrop). Watch it fail on #687079 before the change.
- Change nothing else. Where --text-faint is drawn now, it is still the palest text.

## Check
`node --test frontend/tests/theme-contrast.test.js` passes, and so does `bash scripts/build-static.sh` (ending "leak check: clean"). Run one command per Bash call.

## Done when
Light `--text-faint` is darker, the new test guards it, and the static build is clean.
