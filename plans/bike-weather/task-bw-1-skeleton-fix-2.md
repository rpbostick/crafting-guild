# Bike Weather skeleton: jest must ignore the worktrees folder

Track: light

**Resume.** Same branch (`agent/bw-skeleton`), through aa77b4f. The merge gate runs `npm test` from the repository's main checkout, where builders' worktrees live under `.worktrees/`. Jest found `.worktrees/bw-skeleton/src/screens/TodayScreen.test.tsx` as well as the real one (76 tests instead of 38) and the worktree copy failed with `Cannot read properties of null (reading 'useRef')` (two React copies). The merge was undone.

## Build
1. In `jest.config.js`: `roots: ['<rootDir>/src']` (or `testPathIgnorePatterns` and `modulePathIgnorePatterns` both including `/.worktrees/`), with a one-line comment saying why (`.worktrees/` holds builders' checkouts of this repo).
2. Also make sure `tsc --noEmit` and Metro ignore `.worktrees/`: `exclude` in `tsconfig.json`, and `metro.config.js` blockList if Expo's default does not already skip dot-folders; say what you found.
3. Prove it: create an empty `.worktrees/x/src/dummy.test.ts` containing one failing test in the worktree, run `npm test` and `npm run typecheck`, show both still pass and the dummy is not collected, then delete the dummy.

## Commands
One command per Bash call, each check through the evidence runner: `npm test`, `npm run typecheck`, `npx jest --runInBand`, `npx tsc --noEmit`, `node`, `mkdir`, `rm`.

## Done when
`npm test` collects only `src/` tests with a `.worktrees/` copy present, `npm run typecheck` ignores it, both pass.
