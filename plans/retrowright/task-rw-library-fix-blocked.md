# retrowright: the library must not fail silently when another tab holds the old database

Track: light

Found by the operator on the preview: pressing Add games added nothing and showed nothing. Reproduced in headless Firefox: when another tab on the same origin still has the version-1 `retrowright` IndexedDB open (an earlier build's tab), `IndexedDbGameStore.open` asks for version 2, the browser fires `blocked` and waits, the open promise never settles, `opened` stays null in `src/ui/App.tsx`, and `addFiles` returns at `if (!opened) return;` with no message. Closing the other tab makes it work. Real users will hit this whenever a new version ships while an old tab is open.

## Fix
- `IndexedDbGameStore.open` (`src/storage/gameStore.ts`): handle `onblocked`: report it (a callback or a state the UI can show) instead of waiting silently: "retrowright is open in another tab with an older version. Close that tab to continue." When the block clears, carry on opening without a reload.
- Every opened connection sets `db.onversionchange` to close itself and tell the UI ("A newer version of retrowright was opened in another tab. Reload this page."), so this build never blocks a future one.
- `addFiles`, `playGame` and every other action that needs the store never return silently while it is opening: show "The library is still opening…" (or the blocked message), or wait for it and then act.
- Unit tests with a fake IndexedDB: a blocked open reports the blocked state and completes once unblocked; `versionchange` closes the connection and notifies; an Add pressed while the store is opening adds the game once it opens (or shows the message). Extend the Firefox e2e script with the two-tab case above: an old-version connection open in one page, the library in another: the message shows, and after closing the old connection Add works in the same page.

## Commands
`npm run *`, `npm test`, `npx vitest *`, `npx tsc *`, `node *`, `firefox --headless *`, `git add`, `git commit`. One command per Bash call.

## Done when
- With another page holding the version-1 database open, the library shows the "open in another tab" message, and after that page closes the database opens and Add works without a reload (Firefox e2e).
- A connection closes itself on `versionchange` and the page says to reload (unit test).
- No store action returns silently while the store is opening or blocked (unit tests).
- `npm test` and `npm run build` pass.
