# Bike Weather research: CozyBuilder hands-on (user-local .NET, build, safety report)

Track: light

`docs/research/avatar-cozybuilder.md` read CozyBuilder (github.com/SadLittleKing/CozyBuilder, a .NET 10 / MonoGame village game with a modular character editor) but did not build it. **It has no licence:** study it, and copy nothing into this repository. This round checks it for harmful scripts, builds it with a .NET SDK installed only in the scratch folder, runs what can run headless, and prepares a command so a person can open its character editor on their own desktop. Research only: nothing from CozyBuilder enters `src/`.

## Steps

1. **Clone fresh**, shallow, into `.ws-evidence/scratch/cozybuilder`, and record the commit.
2. **Safety pass before anything builds.** Read every build-time hook: MSBuild targets (`<Exec>`, `BeforeBuild`/`AfterBuild`), `Directory.Build.*`, `NuGet.Config` feeds (any non-nuget.org source), the `tools/` scripts, and the asset generators. List package references and their versions. Flag anything that downloads and runs code, writes outside the repo, phones home, or is obfuscated, with file and line.
3. **User-local .NET:** download Microsoft's `dotnet-install.sh` from https://dot.net/v1/dotnet-install.sh into `.ws-evidence/scratch/`, read it, and install the .NET 10 SDK into `.ws-evidence/scratch/dotnet`. Use that `dotnet` by path; do not touch system paths or shell profiles. Set `DOTNET_CLI_TELEMETRY_OPTOUT=1` on each command.
4. **Cut out** in the sandbox any harmful hook or feed from step 2, and record each cut (file, why) in `.ws-evidence/cuts.md`. Build with `dotnet build`. Run any tests and its asset validator (`assets/villager/validate_glb.py` only if it needs nothing outside the stdlib; otherwise say so).
5. **For the person:** write `.ws-evidence/run-editor.sh`, one command that runs the character editor with the scratch SDK and nothing else. The report says what to try in it: cycle every slot, combine gear, and watch how covering works.
6. **Measure from the build:** the parts list and slot table as the running code loads them (a small headless probe in the scratch folder, not in our repo), and how a new garment is added end to end.

## Output

- `docs/research/avatar-cozybuilder-handson.md`, which:
  - names the commit and gives the safety findings first, then what was cut;
  - covers what building it showed against what reading it had claimed, and the run command and what to look at;
  - lists separately what the avatar should take or change, and what figurewright should take or change, as ideas in our own words.
- `.ws-evidence/issue-draft.md`, only if step 2 found something harmful or risky: a GitHub issue for the author with file references and a suggested fix. Do not file it.

## Prior art
This is the prior-art step. The earlier read-only report is `docs/research/avatar-cozybuilder.md`.

## Commands

`git clone --depth 1 https://github.com/SadLittleKing/CozyBuilder .ws-evidence/scratch/cozybuilder`, `git -C .ws-evidence/scratch/cozybuilder log -1`, `curl -L -o .ws-evidence/scratch/dotnet-install.sh https://dot.net/v1/dotnet-install.sh`, `python3 -I *`, `ls`, `cat`, `grep`, `du -sh`, `chmod *`, WebSearch, WebFetch, `git add`, `git commit`. One command per Bash call. Also granted at dispatch, exactly: bash .ws-evidence/scratch/dotnet-install.sh with its arguments, and .ws-evidence/scratch/dotnet/dotnet with its arguments.

## Done when
- `docs/research/avatar-cozybuilder-handson.md` is committed with the safety findings, the build result, the run command and the two recommendation lists.
- `.ws-evidence/cuts.md` exists (it may say nothing was cut).
- It built with the scratch SDK (log in evidence), or the report says exactly what stopped it.
- `.ws-evidence/run-editor.sh` exists and uses only the scratch SDK.
- Nothing from CozyBuilder is in a committed file except identifiers and paths named in the report.
