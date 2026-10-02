# Research: twenty small open-source web toys for the character sheet page

Track: light

The character generator page (`chargen/`, a self-contained HTML page on a static site, no server) will get a drawer of small desk toys to play with between rolls. Find about 20 well-made, lightweight, highly rated open-source browser toys and write the findings to `docs/research/toys.md`.

## What to look for
Physical and fidget toys, for example: Newton's cradle, cat's cradle (string figures), pin art / pin box (pinscreen), liquid motion bubbler / oil-and-water wave toys and drip timers, zen sand garden / sandbox (falling sand), fidget spinner, stacking blocks, marble runs, magnetic desk sculptures, Rubik-style twisty puzzles, kinetic sand, wave machines, bubble wrap, slinky, executive desk pendulums, lava lamp, kaleidoscope, string art, tangram, Etch A Sketch, snow globe, wind chimes, music boxes. Also check collections of open-source web toys (e.g. "neal.fun"-style toys only when the source is open, Codepen collections with clear licences, GitHub topics such as `physics-simulation`, `fidget`, `falling-sand`, `creative-coding`), and physics engines used by small toys (matter.js, planck.js, Rapier, p2.js) in case a toy is best built on one.

## For each toy (aim for 20, at least 15)
- What it is, a link to a live demo and to the source.
- Licence, read from the actual LICENSE file (MIT, BSD, Apache, ISC, CC0, or GPL; mark GPL ones clearly since they would have to live on their own page). CodePen pens are MIT by default on public pens; say so only when the pen is public.
- Size (the files a toy needs, minified/gzipped where possible), dependencies (a physics engine? WebGL? React?).
- Quality signals: stars, last commit, issues, mentions or awards, how polished it looks and feels (try the demo; describe it).
- Whether it runs offline in one page, works with touch and mouse, respects reduced motion, and can sit in a panel about 400 × 400 px.
- Effort to adapt: drop-in, small changes, or a rewrite on our side using its idea.

## Output
`docs/research/toys.md`: a ranked table of the 20, details per toy, sources with the date checked, and a recommended first set of 6 that together stay under about 300 KB gzipped. Facts you could not verify are marked as such.

## Prior art
This task is the prior-art search.

## Commands
Web search and web fetch for research. `git add`, `git commit`. One command per Bash call.

## Leave alone
Everything except `docs/research/toys.md`.

## Done when
The file lists at least 15 (aim 20) verified open-source toys with licences, sizes, quality notes and demos, ranks them, recommends a first set, and is committed.
