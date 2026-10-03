# Toybox: a movable, minimizable drawer, and several toys open at once

Read `README.md`, `NOTES.md`, `src/` (the drawer and panel code, the dice tray's window code), `tests/`.

## Behaviour
- **The drawer is a window:** `<toy-drawer panel="floating">` can be **dragged** by its title bar anywhere (kept on screen), **resized** from its corner, **minimized** to a small tab/button (and restored), and closed; position, size and minimized state remembered per page key. Reuse the dice tray's window code (drag, resize handle, on-screen clamp, persistence) rather than writing a second one; factor it into a shared window module both use.
- **Several toys at once:** opening a toy from the drawer opens it in **its own floating window** (title = toy name, Pause, Reset, minimize, close), so several toys can be open side by side; each window is draggable, resizable, minimizable and remembered (which toys are open, where, how big). New windows cascade from the drawer's position so they don't stack exactly. A toy can be opened only once at a time (opening it again focuses its window). Clicking a window brings it to the front.
- **Performance:** every open, visible, un-minimized toy runs; minimized or off-screen ones pause; a page-wide cap (attribute `max-running`, default 4) pauses the least recently focused toys beyond it, with a small "paused, click to resume" overlay.
- `panel="inline"` keeps the current single in-place panel behaviour.
- The GPL/MPL toys (music box, twisty cube) keep running in their iframes inside their windows.
- Keyboard and screen readers: windows are labelled dialogs (non-modal), focusable title bars, Esc closes the focused window, arrow keys move it when its title bar is focused.
- CHANGELOG 0.6.0; docs and demo page updated (the demo opens two toys side by side).

## Prior art
The library's dice tray window (drag, resize, persistence) — share it; no window-manager library.

## Tests
Shared window module (drag clamp, resize minimum, minimize/restore, persistence, z-order); drawer drag/resize/minimize; opening two toys gives two windows, reopening focuses, closing destroys the toy (no leaked frames/listeners, using the existing leak checks), the running cap pauses the oldest, minimized windows pause; `panel="inline"` unchanged. Firefox e2e: open three toys, move one, minimize one, close one. Build via `bash build.sh`; tests that read `dist/` run after it.

## Commands
`npm ci`, `npx …`, `node …`, `bash build.sh`, `bash scripts/<script>.sh`, `firefox --headless …` (absolute paths, one per call), `git add`, `git commit`. One command per Bash call.

## Done when
The drawer moves, resizes and minimizes; toys open in their own windows, several at once, each movable, resizable, minimizable and remembered; a running cap protects performance; version 0.6.0; tests pass.
