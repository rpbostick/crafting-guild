# retrowright: research spike, ROM toolkit and the remake path

Track: light

A research spike: the output is one document, `docs/research/toolkit.md`, plus any small probe scripts under `.ws-evidence/`. No change to `src/`.

retrowright is also a toolkit for taking games apart. A sister project analyses ROMs with Ghidra and REA (function lists for NES, SNES and GBA ROMs) and runs MesenCE and mGBA. retrowright already has record and replay, a Final Fantasy memory map and a frame-by-frame comparison with MesenCE (`harness/`, `docs/accuracy.md`). The aim is to remake games from existing ones, for example Super Mario Bros. with skateboarding mechanics in the style of Skate or Die and Tony Hawk's Pro Skater. Such remakes start as ROM hacks shared as patches (IPS or BPS) that the player applies to their own ROM; a remake published on its own later gets its own art and code. Read `README.md`, `src/core/types.ts`, `harness/` and `docs/accuracy.md` first.

## Research
Search thoroughly for existing software before proposing to build anything; list every candidate found. Licences: check each one from the repository's own LICENSE file. Code that ships in retrowright must be permissive (MIT, BSD, ISC, zlib, Apache-2.0 or MPL-2.0); GPL tools may be studied for features and used as separate programs, but their code is not copied or read to write ours.

1. **The toolkit pieces:** a memory viewer with RAM search (find the address that changes when Mario jumps); tile, palette and nametable or map viewers; a CPU trace logger and breakpoints (on an address, a memory read or write); a patch maker and applier (IPS and BPS). For each: what Mesen, FCEUX, BizHawk, mGBA and no$ offer and what players of those praise; which browser or JS libraries already do it (for example Rom Patcher JS for patches); what jsnes exposes today and what it would need (CPU step hooks, memory access hooks). Recommend for each piece: use a library, port an idea, or write it.
2. **Joining with the Ghidra work:** how labels and function names from Ghidra (or REA) could show in the trace and memory views (formats such as Mesen's `.mlb`, FCEUX's `.nl`, or a plain symbol file).
3. **The remake path for Super Mario Bros.:** the community disassemblies (which one, its licence and status, which assembler builds it back byte for byte); the SMB hacking tools and documents (level editors, physics write-ups, RAM maps); what a skateboarding feel needs in SMB's physics (momentum, ollie, grinds, tricks) and which parts of Skate or Die and Tony Hawk's Pro Skater are worth studying, with any existing write-ups of their mechanics; the toolchain to build the patched ROM (assembler licences); how to share the result as a patch without shipping any of the original game.
4. **SNES and GBA:** which of the above carries over (the GBA's and SNES's own viewers and disassemblies), briefly.

## Prior art
This task is the prior-art search for the toolkit build tasks and the first remake. Note anything from `docs/research/emulator-ux.md` that bears on the toolkit's interface.

## Commands
WebSearch, WebFetch, `git clone *` (into `.ws-evidence/` only, to read LICENSE files), `npm install *` (into `.ws-evidence/` only, for a probe), `node *`, `npx tsx *`, `git add`, `git commit`. One command per Bash call.

## Done when
- `docs/research/toolkit.md` has, for each toolkit piece, the candidates found with verified licences (the file named) and a recommendation: use, port the idea, or write.
- It says what retrowright's `EmulatorCore` and jsnes need for trace and breakpoints, with the jsnes source lines that matter.
- The remake section names the disassembly and assembler to use, the build-back-byte-for-byte check, the patch format, and a first small step (for example: change Mario's run speed, build the ROM, make a BPS patch, play it in retrowright).
- It sketches the build tasks that follow: their order, sizes and done-whens.
- Committed on the branch.
