# chargen-beta: footer link that works on the site and from disk

Track: light

Continue on this branch. Review finding (blocking): the footer link `href="../chargen/"` is copied unchanged into `chargen-beta/dist/chargen-beta.html` and `chargen-beta/dist/chargen-beta.public.html`, where it points at `chargen-beta/chargen/`, which does not exist; opened from disk it also lands on a directory listing.

## Behaviour
- The **public** build (`--public`, published at `/chargen-beta/` next to `/chargen/` on the site) keeps `../chargen/`.
- The **local** build (`dist/chargen-beta.html`, opened from disk or a local server) links to `../../chargen/dist/chargen.html`.
- Do it in `build.js` (one href per output), with a test on each built file's href; correct the README lines that describe opening the page and the link.
- Carry forward from the review where cheap: none required.

## Prior art
The existing build. No library.

## Commands
`node --test chargen-beta/tests/<file>.test.js`, `node chargen-beta/build.js`, `node chargen-beta/build.js --public`, `git add`, `git commit`. One command per Bash call.

## Done when
Each built page's footer link resolves where that page is used, a test pins both, both outputs are rebuilt and committed, and the tests pass.
