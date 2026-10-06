# Bike Weather fix: the README's swatch count, and one comparator's names

Track: light

On this branch only. Two edits, one commit.

1. `README.md:48` says the editor offers "twelve named swatches"; `SWATCHES` in `src/ui/palette.ts` has fourteen. Drop the number from the sentence so it cannot go stale ("a palette of named swatches").
2. `src/screens/wardrobe/WardrobeScreen.tsx:45`: the sort comparator's parameters `a` and `b` get names (for example `first` and `second`).

## Prior art
None needed.

## Commands
One command per Bash call: `grep`, `cat`, `npx jest src/screens`, `npx tsc --noEmit`, `git diff`, `git add`, `git commit`.

## Done when
Both edits are committed, `npx jest src/screens` and `npx tsc --noEmit` pass, and the result gives the commit.
