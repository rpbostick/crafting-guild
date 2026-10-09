# Bike Weather research: what CharacterStudio does, and whether it fits our stack (research only, no product code)

Track: light

Bike Weather will show the suggested outfit on the user's avatar, with clothing layered like real clothing: underwear to coat, several garments at once with the lower layers visible, added and removed in order (read `README.md`, `package.json` and `src/model/` here for our garments, regions and layers, and the Expo stack). CharacterStudio (github.com/M3-org/CharacterStudio, MIT) is a web avatar creator for glTF/VRM on three.js and `@pixiv/three-vrm`. Its logic lives in a `CharacterManager` class, and it does face culling under layers, mesh merging with texture atlasing, a colour picker, and export.

**Safety:** the repository commits `cert.pem` and `key.pem` and depends on web3 packages. Read before installing anything, and never run install scripts.

## Steps

1. Clone it, shallow, into `.ws-evidence/scratch/characterstudio` (untracked): `git clone --depth 1 https://github.com/M3-org/CharacterStudio .ws-evidence/scratch/characterstudio`.
2. Read `README.md`, `CLAUDE.md`, `docs/`, the `CharacterManager` class and what it uses, the trait and manifest format, the culling and optimisation code, and `package.json`. Look up the licences of its asset packs (`github.com/m3-org/loot-assets`, `github.com/memelotsqui/character-assets`) with WebFetch.
3. **Optional:** if reading leaves question 5 open, install with scripts off (`npm ci --ignore-scripts` in the clone) and build (`npx vite build`). Report the bundle size and whether it builds. Don't start its dev server.
4. Answer, with file and line references into the clone:
   1. **Slots and layers:** how traits and slots are defined, how the layer order and culling work, how a trait is added or removed at run time.
   2. **Bodies:** how body variation works (VRM blend shapes, separate bases) and how clothing follows it.
   3. **Asset pipeline:** what an asset pack contains, how a new garment is authored and registered, and the tools named in the docs.
   4. **Customisation interface:** picking, colouring, randomising, exporting.
   5. **Our stack:** whether `CharacterManager` (React-free) could run in Expo. On web that is three.js in the browser. On iOS and Android it is `expo-gl` with three.js, or `@react-three/fiber/native`. Look up the current state of each with WebSearch, and give bundle size and likely frame rate on a mid-range phone, with sources. Say what 3D costs and gains against a 2D SVG avatar.
   6. **Reuse:** per piece, whether we could use the code (MIT, with attribution in our third-party licences), its assets (their own licences), or only the idea.

## Output

`docs/research/avatar-characterstudio.md`: the six answers, short, with a reuse table (piece, licence, use as code / asset / idea). Name the commit read. Cite web sources with the date read. Mark anything unverified as unverified.

## Prior art

This is the prior-art step for the avatar build.

## Commands

`git clone --depth 1 https://github.com/M3-org/CharacterStudio .ws-evidence/scratch/characterstudio`, `ls`, `cat`, `grep`, `git -C .ws-evidence/scratch/characterstudio log -1`, `npm ci --ignore-scripts`, `npx vite build`, `du -sh`, WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call.

## Done when

- The report is committed at `docs/research/avatar-characterstudio.md` and answers all six questions with file references and cited web sources.
- It names the commit read, and includes the reuse table with a licence per row.
- No install script was run.
