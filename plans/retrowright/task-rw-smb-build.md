# retrowright: SMB build check and the first patch

Track: full

Toolkit step 7 (`docs/research/toolkit.md` section 8). It needs the patch module from rw-patches (merged). Read section 4 of that document in full, then `harness/cli.ts`, `src/patch/` and how the movie tests skip when a ROM is missing.

The SMBDIS source has no licence and its asm6f port ships Nintendo's graphics, so neither the disassembly nor the ROM ever enters the repository. The source lives in a folder named by the environment variable `RETROWRIGHT_SMB_SRC`, the way `RETROWRIGHT_MESEN` names MesenCE's path. The player's ROM is `roms/Super Mario Bros. (World).zip`, not committed. "World" is No-Intro's current name for the "Japan, USA" image. The `.nes` inside is 40,976 bytes, SHA-256 `0b3d9e1f01ed1668205bab34d6c82b0e281456e137352e4f36a9b2cfa3b66dea`. Xkeeper0/smb1's `build.sh` expects `f61548fd…` for its build. The source is already cloned for you at `~/retrowright-smb/smb1` (Xkeeper0/smb1 at 1cc3c92); run with `RETROWRIGHT_SMB_SRC` set to that folder, and never write its path into the repository. The ROM's header is NES 2.0 (byte 7 is `08`), while `smb1.asm` writes a plain iNES header, so the whole files cannot match; compare PRG+CHR without the 16-byte header (the ROM's is `fcb6a0ef3a20c19b356005fbb21dc8009563b1cb5a9aaebc8e9386b4a8c5912e`). Measure before deciding: hash the whole file and PRG+CHR without the 16-byte iNES header, compare both with the clean build, and make the check compare whichever is right (most likely without the header). Say which in the result.

## Build
- **asm6f:** the build needs it as a separate program. Look for it on the PATH first. If it is missing, clone freem's asm6f into `.ws-evidence/`, build it with `make` or `cc`, and use it from there. Record the commit and how it was built. Do not commit asm6f.
- **`npm run smb -- check`:** reads the SMB ROM from `roms/`, a `.nes` or a `.zip` (read the zip in Node with a small dependency such as fflate, or the `unzip` command into a temp folder outside the repository), and checks its SHA-256 against the known "Super Mario Bros. (Japan, USA)" image. It assembles the tree in `RETROWRIGHT_SMB_SRC` untouched with `asm6f smb1.asm -n -c -L` (Xkeeper0/smb1's layout), hashes the result, and fails unless the hashes are equal. It also writes the `.mlb` and `.nl` label files asm6f makes, beside the build, outside the repository.
- **Where builds happen:** the harness never writes into `RETROWRIGHT_SMB_SRC`. It copies the tree into a temp folder (Node's `fs.cp` into `os.tmpdir()`), applies any source change there, assembles there, and removes it afterwards. Shell `cp` from outside the worktree is denied to you, so do the copying in the harness code.
- **`npm run smb -- patch <name>`:** builds the tree as it stands, refuses if the clean build has not passed the check, and writes `patches/smb/<name>.bps` from the original ROM to the result, with the patch module's BPS creator. Write it with the source and target SHA-256 in a small `.json` beside it.
- **The first patch, `run-speed`:** in a copy of the tree, change `MaxRightXSpdData` `$28` → `$30` and `MaxLeftXSpdData` `$D8` → `$D0`. Build it and write the BPS. Commit only the BPS, its `.json` and a `-U0` diff of the source change.
- **A movie test:** record a short World 1-1 run holding B and Right on the patched ROM, with a checkpoint `$0057 == 48`. It skips when the ROM or `RETROWRIGHT_SMB_SRC` is missing, like the existing movie tests.

- **Carried from the rw-patches review:** a truncated or damaged BPS can hang the page (the vendored `BPS_readVLV` loops past the end of the file). In `src/patch/patch.ts`, check the BPS's trailing CRC32 over everything before it before parsing, and refuse a damaged patch with a clear message. Add a truncated case to the 'refuses a damaged BPS' test. In the e2e, make the wrong-ROM refusal assert the CRC32 text, not just any alert.

## Prior art
`docs/research/toolkit.md` section 4: Xkeeper0/smb1 (SMBDIS in asm6f, with a SHA-256 check in its `build.sh`), pgattic/smb1-disasm (`make check`), and Bojidarist/smb1dg (changes kept as source patches) are the models; asm6f is the assembler. Build on that layout; write nothing it already does.

## Commands
`git clone *` (into `.ws-evidence/`, or into the folder `RETROWRIGHT_SMB_SRC` names), `make *`, `cc *`, `unzip *` (into a temp folder outside the repository), `sha256sum *`, `npx vitest *`, `npx tsc *`, `npx tsx *`, `npm run *`, `node *`, `git add`, `git commit`. One command per Bash call.

## Done when
- `npm run smb -- check` passes on the clean tree: the build matches the ROM's SHA-256 (log in `.ws-evidence/`).
- The `run-speed` patch changes only the two table bytes (shown by comparing the two builds byte for byte), and it applies to the ROM in the library (from rw-patches) to give the patched build's SHA-256.
- The movie test reaches `$0057 == 48` while running in 1-1 on the patched ROM, and skips cleanly without the ROM.
- No SMB code, graphics or ROM bytes are committed: the precheck and `git diff main --stat` show only the harness, the patch, its `.json`, the `-U0` diff and tests.
- A BPS cut short by any number of bytes is refused quickly, with no hang (unit test).
- The tests for what changed pass, and `npm run build` passes. The README describes setting up `RETROWRIGHT_SMB_SRC` and the two commands.
