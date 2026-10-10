# Emulators for rea-roms-test: research

2026-10-10. Systems: NES, SNES / Super Famicom, Game Boy Advance. Purpose: run the ROMs, and drive and inspect them while reverse engineering with REA (which does static analysis through Ghidra, Hopper or IDA). Repo facts (licence, last push, stars, archived) come from the GitHub API on this date.

## Recommendation
1. **MesenCE** as the main emulator: one program covers all three systems, it has the strongest debugger of the lot (disassembly, memory viewers, breakpoints, event viewer, trace logger), and it runs Lua scripts. Note that `SourMesen/Mesen2` was archived around v2.1.1 in mid-2025 and points to MesenCE.
2. **mGBA** as a second GBA emulator and the easiest one to automate: MPL-2.0, Lua API with breakpoints, watchpoints, savestates, input, screenshots and TCP sockets (0.11 dev builds; latest stable 0.10.5), Python bindings in `src/platform/python`, and a GDB stub.
3. **ares** if we ever modify an emulator and want to ship the result under a permissive licence (ISC). Its debugger is weaker than Mesen's.

## Candidates

| Emulator | Systems | Licence | Last push | Stars | Scripting / debug | Notes |
|---|---|---|---|---|---|---|
| [MesenCE](https://github.com/nesdev-org/MesenCE) | NES, SNES, GB, GBA, PCE, SMS, WS | GPL-3.0 | 2026-10-07 | 566 | Lua, full debugger | v2.2.1 (2026-06-05); Linux build needs SDL2; .NET UI |
| [Mesen2](https://github.com/SourMesen/Mesen2) | same | GPL-3.0 | 2026-06-04 | 2414 | same | **archived**, use MesenCE |
| [mGBA](https://github.com/mgba-emu/mgba) | GBA, GB | MPL-2.0 | 2026-10-08 | 7486 | Lua, GDB stub, Python | `mgba-qt` 0.10.2 in apt |
| [ares](https://github.com/ares-emulator/ares) | NES, SNES, GBA and many more | ISC | 2026-10-06 | 1830 | basic debugger | permissive; accuracy-focused |
| [bsnes](https://github.com/bsnes-emu/bsnes) | SNES | GPL-3.0 | 2026-10-07 | 2001 | little | accuracy reference |
| [bsnes-plus](https://github.com/devinacker/bsnes-plus) | SNES | no licence file | 2025-03-22 | 365 | strong SNES debugger | older; licence unclear for reuse |
| [FCEUX](https://github.com/TASEmulators/fceux) | NES | GPL-2.0 | 2026-10-10 | 1569 | Lua, debugger, hex editor | classic NES RE tool |
| [Nestopia UE](https://github.com/0ldsk00l/nestopia) | NES | GPL-2.0 | 2026-09-13 | 945 | little | accurate player |
| [VBA-M](https://github.com/visualboyadvance-m/visualboyadvance-m) | GBA, GB | GPL-2.0 | 2026-10-10 | 3929 | GDB stub | older core |
| [SkyEmu](https://github.com/skylersaleh/SkyEmu) | GBA, GB, NDS | MIT | 2026-10-10 | 1280 | HTTP control server | permissive |
| [BizHawk](https://github.com/TASEmulators/BizHawk) | many (NES, SNES, GBA cores) | MIT frontend, mixed GPL cores | 2026-10-06 | 2777 | Lua, TAS tools | Windows-first; licence file calls itself a mixed combination |
| [RetroArch](https://github.com/libretro/RetroArch) | all, via cores | GPL-3.0 | 2026-10-10 | 14284 | none for RE | a player, not an RE tool |
| [EmulatorJS](https://github.com/EmulatorJS/EmulatorJS) | all, in the browser | GPL-3.0 | 2026-09-20 | 4250 | none | useful only if we want a web page |
| [Snes9x](https://github.com/snes9xgit/snes9x) | SNES | non-commercial custom | 2026-09-24 | 3357 | little | not open source by OSI terms; avoid for modification |
| [NanoBoyAdvance](https://github.com/nba-emu/NanoBoyAdvance) | GBA | GPL-3.0 | 2026-06-21 | 1307 | little | **archived** |

## Agent bridges (MCP servers)
Young projects with almost no users, so read them before running anything and treat them as prior art.
- [mesen-for-ai](https://github.com/paulomanrique/mesen-for-ai) (GPL-3.0, 2026-09-02): runs Mesen/MesenCE headless with a Lua bridge and exposes the debugger over MCP, aimed at SNES/NES/PCE/GBA reverse engineering.
- [mcp-mgba](https://github.com/Canadadry/mcp-mgba) (MPL-2.0, 2026-09-06): headless GBA debugger on libmgba (load, step, memory, breakpoints, watchpoints). [mgba-live-mcp](https://pypi.org/project/mgba-live-mcp/0.3.0/) keeps one mGBA process alive across calls.
- BizHawk has MCP bridges too, listed on [mcpmarket](https://mcpmarket.com/zh/server/bizhawk); not checked.

## Ghidra side (static analysis through REA)
- NES (6502): [GhidraNes](https://github.com/kylewlacy/GhidraNes) loader, active (2026-05-31), **no licence file** (fine to use, not to copy code from).
- GBA (ARM7): [gba-ghidra-loader](https://github.com/pudii/gba-ghidra-loader), Apache-2.0, 2026-02-09. Ghidra handles ARM natively.
- SNES (65816): [ghidra-snes-loader](https://github.com/achan1989/ghidra-snes-loader), MIT, archived. Stock Ghidra has no 65816 processor; this is the weakest link and needs a closer look.

## Modifying an emulator: licence consequences
- GPL-3.0 (MesenCE, bsnes) and GPL-2.0 (FCEUX, Nestopia, VBA-M): changes are fine for our own use; anything we distribute must ship its source under the same licence.
- MPL-2.0 (mGBA): only the files we change must stay open; new files can be ours.
- ISC / MIT (ares, SkyEmu): do anything, keep the notice.
- Snes9x: non-commercial terms, avoid.

## Open questions
- Does MesenCE's headless test-runner mode (Lua, no UI) still exist on Linux v2.2.1, and is it enough for an agent loop without mesen-for-ai?
- Which 65816 processor module for Ghidra works today?
- Nothing is installed on this machine yet (no emulator, no Ghidra).

## Legal note
The README's plan stands: freely licensed homebrew first, then dumps of games we own. ROMs stay out of git (`roms/`, `research-files/` are ignored).
