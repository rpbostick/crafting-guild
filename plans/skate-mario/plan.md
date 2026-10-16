# skate-mario: plan

**In flight right now**

**RUNNING (2026-10-16 02:xx MDT):** chain `engine.queue` at step 4 (merged: sm-engine-2 b209af2, sm-engine-3 87ff016): skate engine split steps 2-4 (skate-engine.md 3.2: ground movement, air/hop/ollie, the engine computes the speed), pure refactors merging on evidence; step 1 merged in retrowright (33cec6e) before the split.

**Where we are:** split out of rpbostick/retrowright-dev on 2026-10-16 into rpbostick/skate-mario (private) with `git filter-repo --subdirectory-filter skate` (history from the split commit on; the earlier history stays in retrowright-dev). Depends on retrowright as a sibling checkout (`file:../retrowright`). Holds: the SMB patches (expand, run-speed, skate levels, skate-pedal, super-skate-bros), the SMB harness and tests, the search bot, the fall fuzzer, the drafts tools, the SMB e2e scripts, the skate and SMB research, Super Skate Bros.' home build (`npm run smb -- demo`, ROM to ~/retrowright-test-roms, never published). All 468 tests pass with the ROM folder named.

**Direction and history:** see plans/retrowright/plan.md (Direction, Roadmap, Level design rule): Skate Mario (patch on the player's ROM, original levels) and Super Skate Bros. (household-only demo, no signature) are done; next the fork: the skate engine as its own module (this queue), then an NES homebrew with our own engine, levels, art and music (levels follow the design rule: speed into the obstacle), later a GBA rewrite in C++. The patch gets its own public release later, with its own audit.
