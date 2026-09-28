# rpbostick.github.io: a scroll strip at the bottom of the figurewright hero

Track: light

You are continuing branch `agent/site-fw`. Read your earlier commits first: the hero captures the wheel for the colours once it is activated by a click.

Patrick asked: "there should be a little hint at the bottom so if they leave their mouse there, the mousewheel will scroll normally when it's down there."

## Build
- Along the bottom edge of the hero, a strip (about 64–80 px tall, full width) with a small hint centred in it: "↓ Scroll here for more" (a gentle arrow is fine; respect `prefers-reduced-motion` for any bounce).
- While the pointer is over the strip, wheel events are **not** captured: the page scrolls normally, even when the hero is active. The hero stays active (no deactivation just because the pointer is in the strip); moving back up into the hero resumes wheel colour control.
- Clicking the strip (or pressing Enter/Space on it; it is a button) scrolls smoothly to the first section below the hero.
- Visible in both themes and at phone width; the strip must not cover the splash lineup's feet (move the lineup up if needed).
- Update the hero's active hint if it mentions how to leave, so it stays accurate (e.g. "Scroll to shift colours · Esc to leave · scroll at the bottom to move on").

## Check
`npm run build` and `npm run lint` pass; serve with `npx vite preview --host 127.0.0.1 --port 8791 --strictPort` and fetch the page with 200.

## Commands
One command per Bash call. `npm run build`, `npm run lint`, `npx vite preview ...`, `curl ...`, `node ...`. Do not run `npm install`.

## Done when
With the hero active, the wheel over the bottom strip scrolls the page and the wheel elsewhere in the hero shifts the colours; the strip's button scrolls to the content; build and lint pass.
