# Fix round 1 for `task-sm-ramp-launch.md`

The review of this branch at 29ecfa9 found blocking issues. Fix each one, with a test where the finding is about behaviour, commit, and re-run the covering test files through ws-run. Do nothing else; suggestions are carried to a later task.

## Blocking findings
- `homebrew/src/skate.s:298` (rule 3): The default rampOllieWindow of 4 leaves a dead frame: SkateJump sets SkateOllieTimer to OllieDelay+1 (7) on the press and pops when it reaches 1, so at the launch frame the timer is 7−k for a press k frames early. main.c:602's test `timer + window > OllieDelay` passes for k ≤ 4, k = 6 pops on the launch frame itself and stacks, but k = 5 (timer 2) fails the test, ramp_launch() sets io_state to a jump, and SkateOlliePop then discards the pending pop because it pops only with io_state 0. A player pressing A 5 frames (15 px at top speed) before the lip gets no ollie at all, the exact case the window exists to catch, and the README's 'pressed within rampOllieWindow frames before it adds the ollie's pop' reads as covering every pending press. Fix: default the window to OllieDelay − 1 (5) here and in skate.tunables.json:613, update homebrewLaunch.test.ts:179's expectation and the '(start 4)' and '(4)' in smb3-model.md:209 and README.md:43, and refresh romSha256.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `make *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. Read files outside the worktree with the Read and Grep tools.

## The original task (for context)
## skate-mario: ramps launch the board

Track: full

On the board, a ramp should throw the player into the air: riding off a ramp's lip launches higher than an ollie on flat ground, and higher than the best jump on foot on flat ground. Read `homebrew/src/main.c`'s `ride()`, `slope_ground()`, `snap_down()` and `slope_floor()`, `homebrew/src/level.h`'s slope tables, the ollie in `engine/skate.s` (`SkateJump`, `SkatePop`) and how the host sets `io_vy`/`io_state` first.

### Build
- **Kickers.** Add one or two kickers to the test level, each a rising slope (one 45-degree, one gentle if it fits) whose top is a lip with air or a drop beyond it, with enough run-up to reach the board's top speed. Put them in a new room or after the hill; keep the earlier rooms as they are so their tests hold.
- **The launch.** On the board, when the player leaves a rising slope's high end moving uphill, the speed along the slope becomes upward speed: the upward speed is the horizontal speed times the shape's rise per pixel (1 for 45 degrees, 1/2 for gentle) times `rampLaunch` (a tunable, 256 = 1.0; choose a start that meets the done-when and say why). The horizontal speed is kept. `snap_down()` must not pull a launched player back onto the ground.
- **Ollie at the lip stacks.** An ollie pressed on the launch frame, or within `rampOllieWindow` frames before it on the slope (a tunable; start at 4), adds the ollie's pop to the launch.
- **Toggle.** A tunable `rampLaunchAll` (0 or 1, start 0): at 0 only a lip with air or a drop beyond launches (a kicker); at 1 every rising slope's high end launches, including the hill's slope into its flat top.
- All tunables in `homebrew/skate.tunables.json`'s homebrew section, so F3 tunes them live. On foot, no change. Keep `engine/` untouched unless the launch cannot be set from the host; then say why first. Update the SHA-256 with the build.

### Tests
A new `harness/homebrewLaunch.test.ts`, measuring peak height above the take-off point in the ROM:
- At the board's top speed, riding off the 45-degree kicker with no button peaks higher than (a) an ollie on flat ground at the same speed and (b) the highest jump on foot on flat ground (full running speed, A held).
- An ollie timed at the lip peaks higher than the launch alone.
- The launch grows with speed (three speeds, ordered); the gentle kicker launches lower than the 45-degree one at the same speed.
- With `rampLaunchAll` 0 the hill's slope into its flat top does not launch (the feet stay on the surface, as `homebrewSlope.test.ts`); with 1 it does.
Show the new cases failing on main first (log). `harness/homebrew*.test.ts` pass, including `homebrewCycles.test.ts` (no lag).

### Prior art
Ramp and kicker launches in open-source platformers with slopes (`docs/research/smb3-model.md` section 3's engines; SMB3 itself has no launch). The common approach (Sonic-style physics, as described in the Sonic Physics Guide's slope and jump sections) keeps the ground speed's direction along the surface when the ground ends, so leaving a 45-degree ramp sends the player along that angle; this task uses that rule. Cite it in the docs.

### Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `make *`, `sha256sum *`, `diff *`, `grep *`, `git add`, `git commit`. One command per Bash call. Read files outside the worktree with the Read and Grep tools.

### Done when
- The new cases fail on main and pass on the branch (logs); `harness/homebrew*.test.ts` pass (logs).
- The result gives the peak heights measured for: flat ollie, best flat jump on foot, kicker launch, kicker launch with ollie, at top speed; and where the kickers are in the level.

### Carried from the sm-foot-5 review (suggestions; do them where the code is yours to touch)
- `homebrew/src/main.c:544`: on a jump's take-off frame from a slope, `on_slope` still holds the previous metatile while `io_state` is JUMPING, so the uphill cap applies in the air for one frame; test `io_state == SKATE_STATE_GROUND` in the uphill condition.
- `docs/research/smb3-model.md:135-137`: slope_floor()/snap_down() figures and the worst-frame sum are from an older build; re-measure and make them agree with section 4.1 and the summary.
- Label before-runs per commit so each failing run's log survives.
