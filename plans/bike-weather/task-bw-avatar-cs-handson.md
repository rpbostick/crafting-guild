# Bike Weather research: CharacterStudio hands-on (sandboxed install, run, safety report)

Track: light

`docs/research/avatar-characterstudio.md` read CharacterStudio (github.com/M3-org/CharacterStudio, MIT, a three.js / VRM web avatar creator) but did not run it, because its install pulls in cryptocurrency-wallet libraries. This round installs it **in a sandbox**, removes anything harmful, runs its editor, and measures how its layering behaves. The avatar decisions (2D layered SVG, per-sub-region covering, figurewright's body) are in the earlier report's sources and in figurewright's garment engine (`node_modules` has no figurewright; read its design in the report and in `docs/research/avatar-cozybuilder.md` §5). Research only: nothing from CharacterStudio enters `src/`.

## Steps

1. **Clone fresh**, shallow, into `.ws-evidence/scratch/characterstudio`, and record the commit.
2. **Safety pass before anything runs.** Do this before any install:
   - In `package.json` and the lockfile: list every dependency with a lifecycle script (`preinstall`, `install`, `postinstall`, `prepare`).
   - In the repo and its dependencies' published code: list wallet or key handling, network calls to hosts other than the app's own assets, telemetry, `eval` / `new Function` / obfuscated code, and scripts that fetch and run remote code (for example `get-assets` cloning another repo).
   
   Install with `npm ci --ignore-scripts` only. Then run `npm audit --omit=dev` and `npm query ":attr(scripts, [postinstall])"` and save both.
3. **Cut out** in the sandbox whatever is harmful or not needed to run the editor: wallet and web3 packages and the code that imports them, and install hooks. Record each cut (file, package, why, and whether the editor still runs) in `.ws-evidence/cuts.md`. Never connect a wallet or enter a key.
4. **Run it.** Build with `npx vite build`. Write `.ws-evidence/scratch/drive.js`, which serves `dist/` on a port in 8790–8799 and drives it with puppeteer-core (install it with `--ignore-scripts`; the browser is the newest Chrome under `~/.cache/puppeteer/chrome/`). Run it in the foreground. Use the editor: pick a body, stack garments in several slots, change a colour, and export. Screenshot each step, at most twelve screenshots, onto one page `.ws-evidence/page/index.html`.
5. **Measure layering** against our needs: do lower layers show where an upper one is shorter; what culling removes and when; the cost of adding one garment; the frame time and memory in the browser; and how traits map to slots.

## Output

- `docs/research/avatar-characterstudio-handson.md`, which:
  - names the commit and gives the safety findings first (each with file, line and severity), then what was cut;
  - says what running it showed against what reading it had claimed;
  - lists separately what the avatar should take or change, and what figurewright should take or change.
- `.ws-evidence/issue-draft.md`: a GitHub issue for CharacterStudio's maintainers reporting what was harmful or risky (factual, with file references and a suggested fix; no accusations). Do not file it.

## Prior art
This is the prior-art step. The earlier read-only report is `docs/research/avatar-characterstudio.md`.

## Commands

`git clone --depth 1 https://github.com/M3-org/CharacterStudio .ws-evidence/scratch/characterstudio`, `git -C .ws-evidence/scratch/characterstudio log -1`, `npm ci --ignore-scripts`, `npm audit *`, `npm query *`, `npm ls *`, `npm install --ignore-scripts *`, `npx vite *`, `node *`, `ls`, `cat`, `grep`, `du -sh`, WebSearch, WebFetch, `git add`, `git commit`. Run npm and npx from inside `.ws-evidence/scratch/characterstudio` with `--prefix` where a command takes it. One command per Bash call. Never run an install without `--ignore-scripts`.

## Done when
- `docs/research/avatar-characterstudio-handson.md` is committed with the safety findings, the cuts, the run and the two recommendation lists.
- `.ws-evidence/cuts.md`, the audit and query output, and `.ws-evidence/issue-draft.md` exist.
- The editor ran: the screenshots and the page exist (or the report says exactly what stopped it, with the log).
- No install ran a lifecycle script (the install logs show `--ignore-scripts`).
