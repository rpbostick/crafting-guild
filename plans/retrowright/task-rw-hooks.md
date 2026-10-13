# retrowright: core debug hooks

Track: full

The first toolkit step (`docs/research/toolkit.md` section 8, task 1). Read section 2 of that document first (where jsnes's hooks go, the probe, and the interface to add), then `src/core/types.ts`, `src/core/jsnesCore.ts` and `harness/replay.ts`.

## Build
- Add the optional members from toolkit.md section 2 to `EmulatorCore`: `setDebugHooks`, `romOffset` and `ppuSnapshot`, with `CpuState`, `AccessKind` and `DebugHooks`. Leave `step` out for now. A core without them still plays and replays.
- Implement them in `JsnesCore` by wrapping methods on the jsnes instance, as the probe did. Install the wrappers only while hooks are set, and remove them on `setDebugHooks(null)`, so a plain run pays nothing (the same pattern as jsnes's Game Genie swap). Hooks go on the paths section 2 names: the execute hook before the opcode fetch in `CPU.emulate`, with PC = `REG_PC + 1`; read and write hooks in `load`, `write`, `push` and `pull`, filtered by `accessRanges`; operand and opcode fetches are left out.
- `romOffset`: wrap the mappers' `loadRomBank` and `load8kRomBank` to record which PRG bank sits in each 8 KB slot. Return null for RAM and registers.
- `ppuSnapshot`: copies of pattern memory, nametables after mirroring, OAM and the 32 palette indices (indices, not jsnes's RGB).
- A hook that returns true stops the frame at its end, not mid-instruction: record the hit and let `frame()` finish. Report it so a later UI can show "stopped at …" with the CPU state.
- Hooks stay out of save states and movies. Nothing outside `src/core/` imports jsnes (`boundary.test.ts`).

## Prior art
`docs/research/toolkit.md` sections 1.3 and 2: no JS library hooks jsnes. FCEUX and Mesen's breakpoint kinds (execute, read, write) and jsnes's own Game Genie instance swap are the models. Write it; there is nothing to vendor.

## Commands
`npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `git add`, `git commit`. Run vitest on the files you touch; `src/core` and `harness` are the relevant suites. One command per Bash call.

## Done when
- A movie the harness already replays gives the same frame hashes with hooks on and off (test).
- A synthetic-ROM test sees an execute hook at its known PC, a write hook on `STA $6000` with value `$42` (`WRITE_BATTERY_RAM_PROGRAM`), and `romOffset($8000) == 0`.
- A test shows a mapper bank switch moves `romOffset` for that slot.
- `ppuSnapshot` returns the sizes and the known tiles of a synthetic ROM (test).
- With hooks off, replay speed is within 5% of today's, and the hooks-on cost is measured on a busy frame (not an idle title screen). Both numbers go in the result, with the log they came from.
- The tests for what changed pass, and `npm run build` passes.
