#!/usr/bin/env bash
# ws doctor requires Claude Code or OpenCode only for the roles configured to use them. With WS_REVIEW_AGENT
# empty the reviewer runs on the only installed client, or picks by the changed files when both are, so each
# single-client install passes and only the installed client is required. Cases with stub clients on PATH: an
# all-OpenCode setup without claude passes with a warn, a Claude role without claude fails, an OpenCode role
# without OpenCode fails, a claude-only or OpenCode-only auto reviewer passes, and the auto reviewer fails with
# neither client and passes with both. Exit 1 on any failed case.
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
# Neither client: drop claude first, then opencode from that PATH.
PATH="$T/no-claude-bin" path_without opencode "$T/no-both-bin"
neither_path="$T/no-both-bin"
# Both clients present, for the case where the auto reviewer must not fail: stubs shadow the host's own clients.
mkdir -p "$T/yesbin"
cat > "$T/yesbin/claude" <<'DC'
#!/bin/bash
case " $* " in
  *" --version "*) echo "2.1.999 (Claude Code)"; exit 0 ;;
  *" auth status "*) echo '{"loggedIn":true}'; exit 0 ;;
esac
exit 1
DC
chmod +x "$T/yesbin/claude"
both_clients_path="$T/yesbin:$T/nocbin:$PATH"
# Claude only: the signed-in claude stub, with every host opencode link dropped.
claude_only_path="$T/yesbin:$T/no-opencode-bin"

case_doctor() { # <name> <want-exit> <grep-pattern> <path> <WS_AGENT> <WS_REVIEW_AGENT> [<not-pattern>]
  local name="$1" want="$2" pat="$3" run_path="$4" ag="$5" rv="$6" npat="${7:-}" out x
  out=$(PATH="$run_path" WS_AGENT="$ag" WS_REVIEW_AGENT="$rv" WS_REVIEW_SHADOW='' \
    "$cw/scripts/doctor.sh" --project demo 2>&1) && x=0 || x=1
  if [ "$x" != "$want" ]; then bad "$name" "exit $x, wanted $want
$out"; return; fi
  if ! grep -Fq -- "$pat" <<< "$out"; then bad "$name" "no line matching: $pat
$out"; return; fi
  if [ -n "$npat" ] && grep -Fq -- "$npat" <<< "$out"; then bad "$name" "unexpected line matching: $npat
$out"; return; fi
  echo "$name ok"
}
case_doctor all-opencode-no-claude 0 \
  'warn  claude not found: an orchestrator in Claude Code, or --agent claude, needs it' \
  "$no_claude_path" opencode opencode
case_doctor claude-role-no-claude 1 \
  'FAIL  claude not found (needed by WS_AGENT)' \
  "$no_claude_path" claude opencode
case_doctor claude-review-role-no-claude 1 \
  'FAIL  claude not found (needed by WS_REVIEW_AGENT)' \
  "$no_claude_path" opencode claude
case_doctor all-opencode-no-opencode 1 \
  'FAIL  opencode not found (needed by WS_AGENT and WS_REVIEW_AGENT)' \
  "$no_opencode_path" opencode opencode
# WS_REVIEW_AGENT empty: the reviewer follows the installed client, so each single-client install passes and the
# missing other client is only a warn; with neither installed the review role still fails.
case_doctor auto-review-claude-only 0 \
  'ok    claude 2.1.999' \
  "$claude_only_path" claude '' 'FAIL  opencode'
# An OpenCode-only install: builders on OpenCode, WS_REVIEW_AGENT empty, no claude on PATH. The auto note shows the
# review role routed to OpenCode, not the Claude fallback.
case_doctor auto-review-opencode-only 0 \
  '(auto: reviews use opencode, the only client installed)' \
  "$no_claude_path" opencode '' 'FAIL  claude'
case_doctor auto-review-both-clients 0 \
  'ok    opencode 1.19.1' \
  "$both_clients_path" claude ''
case_doctor auto-review-no-client 1 \
  'FAIL  claude not found (needed by WS_AGENT and WS_REVIEW_AGENT (auto: no review client is installed; reviews fall back to claude))' \
  "$neither_path" claude ''
exit "$fail"
