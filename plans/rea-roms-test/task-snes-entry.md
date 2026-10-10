# rea-roms-test: SNES ROMs get their entry points in Ghidra

Track: light

`scripts/ghidra-list-functions.sh <prefix> <rom>` imports a ROM into a throwaway Ghidra project and prints what `scripts/ghidra/RomFunctionSummary.java` finds. NES and GBA ROMs list functions. SNES ROMs list none: the ghidra-snes loader (joshleaves/ghidra-snes, installed by `scripts/install-ghidra.sh`) detects the mapping (`mode=HiROM source=INTERNAL_HEADER` for Final Fantasy III) and the 65816 language, but creates no entry points, so auto-analysis never starts disassembling.

## 1. Seed the SNES vectors
Add a Ghidra pre-script (`scripts/ghidra/SnesVectors.java`), run by `ghidra-list-functions.sh` only for SNES programs (language `65816:*:snes`). It reads the CPU vector table in bank $00 and, for each non-zero vector, labels it, marks the target as an entry point, disassembles and creates a function:
- native mode: COP $FFE4, BRK $FFE6, ABORT $FFE8, NMI $FFEA, IRQ $FFEE;
- emulation mode: COP $FFF4, ABORT $FFF8, NMI $FFFA, RESET $FFFC, IRQ/BRK $FFFE.

Each vector is a 16-bit little-endian address in bank $00. First measure how the loader maps bank $00 for HiROM and for LoROM (where the vector bytes are, and what address space the targets live in); do not assume. RESET starts in emulation mode (8-bit A and index registers): set the 65816 context registers Ghidra's module uses for M, X and E at that entry if the module has them, and say what you set.

## 2. Fail on zero functions
`ghidra-list-functions.sh` exits non-zero when the summary reports `functions: 0`, with a message naming the ROM. Add that to `tests/ghidra-list-functions.test.sh` with a canned headless log, in the existing stub style.

## 3. Run it
On all three SNES ROMs, which cover both mappings: `research-files/SNES ROMs/Final_Fantasy_III_USA_Rev_1.sfc` (HiROM), `research-files/SNES ROMs/Final_Fantasy_II_USA_Rev_1.sfc` and `research-files/SNES ROMs/Final_Fantasy_-_Mystic_Quest_USA_Rev_1.sfc` (check their mapping). Use prefix `$HOME/tools`, where Ghidra 12.1.4 and the extensions are installed. Set `GHIDRA_HEADLESS_MAXMEM=2G`, or pass it the way the script already does, and run one ROM at a time. Save each log under `.ws-evidence/`. Never commit ROM bytes or disassembly. Re-run the NES and GBA ROMs once (`research-files/NES ROMs/Final_Fantasy_USA.nes`, `research-files/GBA ROMs/Final_Fantasy_V_Advance_USA.gba`) to show nothing changed for them.

## Prior art
The SNES vector layout is standard (the 65816 data sheet; the SNESdev wiki's "CPU vectors" page). ghidra-snes's own loader source may already parse the header and vectors: read it first and reuse its address mapping logic rather than re-deriving it. GhidraNes seeds the NES vectors (NMI, RESET, IRQ at $FFFA–$FFFF) the same way and is a model.

## Commands
`bash scripts/*`, `bash tests/*`, `shellcheck *`, `find *`, `unzip -l *`, WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call. No `sudo`.

## Done when
- `scripts/ghidra/SnesVectors.java` is committed and `ghidra-list-functions.sh` runs it for SNES programs.
- All three SNES ROMs list more than zero functions, with RESET among the entry points; logs saved under `.ws-evidence/`.
- The NES and GBA ROMs still list their functions (192 and about 2,700 last time).
- `ghidra-list-functions.sh` fails on zero functions, and the test for it passes; `bash tests/run.sh` passes and `shellcheck` is clean.
- `README.md` notes that SNES entry points come from the vector table.
