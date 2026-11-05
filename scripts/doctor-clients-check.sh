#!/usr/bin/env bash
# ws doctor requires Claude Code or OpenCode only for the roles configured to use them. Three cases with stub
# clients on PATH: an all-OpenCode setup without claude passes with a warn, a Claude role without claude fails,
# and an OpenCode role without OpenCode fails. Exit 1 on any failed case.
set -uo pipefail
WS="$(cd "$(dirname "$0")/.." && pwd)"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
bad() { echo "$1 FAILED${2:+: $2}"; fail=1; }

# A scratch workspace and project: doctor reads its own folder, so a copy keeps the real projects/ untouched.
cw="$T/ws"; proj="$T/proj"
mkdir -p "$cw/projects" "$cw/plans" "$cw/runs" "$cw/bin"
cp -a "$WS/scripts" "$cw/scripts"
cp -a "$WS/bin/." "$cw/bin/"
cp -a "$WS/lessons" "$cw/lessons"
[ -e "$WS/.claude" ] && cp -a "$WS/.claude" "$cw/.claude"
cp "$WS/config.sh" "$cw/config.sh"
cp "$WS/VERSION" "$cw/VERSION"
cp "$WS/checklist.md" "$cw/checklist.md"
git -C "$cw" init -q -b main
git -C "$cw" add -A
git -C "$cw" -c user.name=t -c user.email=t@t commit -qm "scratch workspace"
mkdir -p "$proj"
git -C "$proj" init -q -b main
printf 'a\n' > "$proj/a.txt"
git -C "$proj" add a.txt
git -C "$proj" -c user.name=t -c user.email=t@t commit -qm init
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD="true"\nEXTRA_TOOLS=()\n' "$proj" > "$cw/projects/demo.conf"

# A PATH without the named client: one directory of links to every executable on PATH except it. Linking each
# tool keeps git, jq and python3 available even when the client shares their directory.
path_without() { # <client> <dir>
  local client="$1" dest="$2" d f b
  local -a parts
  mkdir -p "$dest"
  IFS=: read -r -a parts <<< "$PATH"
  for d in "${parts[@]}"; do
    [ -d "$d" ] || continue
    for f in "$d"/*; do
      [ -f "$f" ] && [ -x "$f" ] || continue
      b=${f##*/}
      [ "$b" = "$client" ] && continue
      [ -e "$dest/$b" ] || ln -s "$f" "$dest/$b"
    done
  done
}
stub_dir() { # <dir> <with-opencode: yes|no>
  mkdir -p "$1"
  if [ "$2" = yes ]; then
    cat > "$1/opencode" <<'DO'
#!/bin/bash
case " $* " in
  *" --version "*) echo 1.19.1; exit 0 ;;
  *" auth list "*) echo '● OpenCode Go api'; exit 0 ;;
esac
exit 1
DO
    chmod +x "$1/opencode"
  fi
  cat > "$1/npm" <<'DN'
#!/bin/bash
echo 1.19.1
DN
  cat > "$1/gh" <<'DG'
#!/bin/bash
exit 1
DG
  chmod +x "$1/npm" "$1/gh"
}
stub_dir "$T/nocbin" yes
stub_dir "$T/noobin" no
path_without claude "$T/no-claude-bin"
path_without opencode "$T/no-opencode-bin"
no_claude_path="$T/nocbin:$T/no-claude-bin"
no_opencode_path="$T/noobin:$T/no-opencode-bin"

case_doctor() { # <name> <want-exit> <grep-pattern> <path> <WS_AGENT> <WS_REVIEW_AGENT>
  local name="$1" want="$2" pat="$3" run_path="$4" ag="$5" rv="$6" out x
  out=$(PATH="$run_path" WS_AGENT="$ag" WS_REVIEW_AGENT="$rv" WS_REVIEW_SHADOW='' \
    "$cw/scripts/doctor.sh" --project demo 2>&1) && x=0 || x=1
  if [ "$x" != "$want" ]; then bad "$name" "exit $x, wanted $want
$out"; return; fi
  if ! grep -Fq -- "$pat" <<< "$out"; then bad "$name" "no line matching: $pat
$out"; return; fi
  echo "$name ok"
}
case_doctor all-opencode-no-claude 0 \
  'warn  claude not found: an orchestrator in Claude Code, or --agent claude, needs it' \
  "$no_claude_path" opencode opencode
case_doctor claude-role-no-claude 1 \
  'FAIL  claude not found (needed by WS_AGENT)' \
  "$no_claude_path" claude opencode
case_doctor all-opencode-no-opencode 1 \
  'FAIL  opencode not found (needed by WS_AGENT and WS_REVIEW_AGENT)' \
  "$no_opencode_path" opencode opencode
exit "$fail"
