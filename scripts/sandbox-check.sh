#!/usr/bin/env bash
# Probe the builder shell sandbox: the rollout checks from docs/research/builder-sandbox.md, run through
# scripts/ws-sandbox-shell.sh, one pass or FAIL line each. Run it by hand after changing the wrapper, bwrap or
# the kernel's user-namespace policy; the selftest runs it too, on any host where the wrapper's --check passes.
# Usage: bash scripts/sandbox-check.sh      (from the workspace; exits 1 when any line fails)
# On a bwrap below the wrapper's floor every line fails; WS_SANDBOX_MIN_VERSION=<installed> exercises the wrapper there.
# WS_SANDBOX_CHECK_EXTRA_SECRET=<path under the home> adds one path to the credential probe.
set -uo pipefail

WS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
wrapper="$WS/scripts/ws-sandbox-shell.sh"
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "pass  $*"; }
no() { fail=$((fail + 1)); echo "FAIL  $*"; }

# --- bubblewrap itself ---
if out=$("$wrapper" --check 2>&1); then ok "bwrap: ${out#bwrap }"; else no "bwrap: $out"; fi

# A fresh worktree gives git something to write that is not the workspace. The wrapper binds the worktree, the
# read-only git common dir and the writable git paths, so the tests below prove those binds work.
repo=$(git -C "$WS" rev-parse --show-toplevel 2>/dev/null) || { echo "FAIL  not inside a git repository"; exit 1; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/ws-sandbox-check.XXXXXX") || { echo "FAIL  mktemp failed"; exit 1; }
wt="$tmp/wt"
link_target=""
inner_wt=""
# The evidence runner reads its grant and deny files from outside the worktree; keep them where the wrapper
# and ws-run expect.
grants="$WS/runs/sandbox-check/sandbox-check.grants"
denies="$WS/runs/sandbox-check/sandbox-check.deny"
cleanup() {
  git -C "$repo" worktree remove --force "$wt" >/dev/null 2>&1 || true
  [ -z "$inner_wt" ] || git -C "$repo" worktree remove --force "$inner_wt" >/dev/null 2>&1 || true
  rm -rf "$tmp"
  [ -z "$link_target" ] || rm -rf "$link_target"
  [ -z "$inner_wt" ] || rm -rf "$inner_wt"
  rm -f "$grants" "$denies"
}
trap cleanup EXIT
git -C "$repo" worktree add --detach -q "$wt" HEAD || { echo "FAIL  cannot create a temporary worktree at $wt"; exit 1; }

mkdir -p "$WS/runs/sandbox-check"
printf '%s\n' 'true' 'git log*' > "$grants"
printf '%s\n' 'git * --output*' > "$denies"
export WS_RUN_GRANTS="$grants" WS_RUN_DENY="$denies"

# One command through the wrapper, as OpenCode calls it: its `shell` setting is used as `shell -c <command>`.
in_sandbox() { ( cd "$wt" && "$wrapper" -c "$1" ) 2>&1; }

# --- git writes in a temporary worktree ---
for step in "git status" "touch sandbox-check-file" "git add sandbox-check-file" \
            "git commit --allow-empty -m sandbox-check" "git log -1 --oneline"; do
  if out=$(in_sandbox "$step"); then ok "$step"; else no "$step: $out"; fi
done

# --- a linked dependency one folder down is readable ---
# dispatch.sh links node_modules and .venv into a worktree at the top level and one folder down (app/node_modules
# and the like), and every .worktree-links entry, not only the top-level pair. Their targets live in the main
# checkout but outside this worktree, in the masked home, so a one-folder-down link only works once the wrapper
# binds its resolved target. The target sits under the project checkout and outside the temporary worktree.
link_target=$(mktemp -d "$WS/.ws-sandbox-check-link.XXXXXX") || { echo "FAIL  mktemp for the link target failed"; exit 1; }
printf '%s\n' readable > "$link_target/marker"
mkdir -p "$wt/app"
ln -s "$link_target" "$wt/app/node_modules"
if out=$(in_sandbox "cat $(printf '%q' "$wt/app/node_modules/marker")"); then
  if [ "$out" = readable ]; then ok "a one-folder-down node_modules link is readable"
  else no "a one-folder-down node_modules link read '$out'"; fi
else
  no "a one-folder-down node_modules link is not readable: $out"
fi

# --- a link to an ancestor of the worktree leaves it writable ---
# The temporary worktree above sits outside the project, so the link needs one inside it: a read-only bind of the
# project would cover the writable worktree bind.
inner_wt=$(mktemp -d "$WS/.ws-sandbox-check-wt.XXXXXX") || { echo "FAIL  mktemp for the inner worktree failed"; exit 1; }
git -C "$repo" worktree add --force --detach -q "$inner_wt" HEAD || { echo "FAIL  cannot create a worktree at $inner_wt"; exit 1; }
project=$(dirname "$(realpath "$(git -C "$repo" rev-parse --git-common-dir)")")
ln -s "$project" "$inner_wt/up-project"
if out=$( (cd "$inner_wt" && "$wrapper" -c "touch ancestor-link-probe") 2>&1 ) && [ -f "$inner_wt/ancestor-link-probe" ]; then
  ok "a link to an ancestor leaves the worktree writable"
else
  no "a link to an ancestor made the worktree read-only: $out"
fi

# --- credentials are unreachable: the home directory is masked ---
host_home="$HOME"
for secret in .local/share/opencode/auth.json .config/gh/hosts.yml ${WS_SANDBOX_CHECK_EXTRA_SECRET:+"$WS_SANDBOX_CHECK_EXTRA_SECRET"}; do
  path="$host_home/$secret"
  # A host without the tool has no such file to protect: neither a pass, since nothing was read, nor a failure.
  if [ ! -e "$path" ]; then
    echo "note  ~/$secret is not on this host, so there is nothing to read"
    continue
  fi
  if out=$(in_sandbox "cat $(printf '%q' "$path")"); then
    no "reading ~/$secret succeeded inside the sandbox"
  else
    case "$out" in
      *"No such file"*|*"Permission denied"*) ok "reading ~/$secret fails inside the sandbox" ;;
      *) no "reading ~/$secret failed for another reason: $out" ;;
    esac
  fi
done

# --- no network ---
if command -v curl >/dev/null; then
  if out=$(in_sandbox "curl -sS --max-time 10 https://example.com"); then
    no "curl https://example.com succeeded inside the sandbox"
  else
    case "$out" in
      *"Could not resolve"*|*"Network is unreachable"*|*"Could not connect"*|*"Failed to connect"*|*"Connection refused"*)
        ok "curl https://example.com fails with a network error" ;;
      *) no "curl https://example.com failed for another reason: $out" ;;
    esac
  fi
else
  no "curl is not on the host PATH"
fi

# --- the evidence runner, and the tools it runs, inside the same sandbox ---
if out=$(in_sandbox "ws-run sandbox-check-evidence true"); then
  if [ -f "$wt/.ws-evidence/sandbox-check-evidence.log" ] && grep -qx 'exit 0' "$wt/.ws-evidence/sandbox-check-evidence.log" \
     && grep -q 'sandbox-check-evidence' "$wt/.ws-evidence/runs.tsv"; then
    ok "bin/ws-run writes its log and runs.tsv row"
  else
    no "bin/ws-run returned 0 but wrote no evidence: $out"
  fi
else
  no "bin/ws-run failed inside the sandbox: $out"
fi
# A grant the deny rules refuse must stay refused: ws-run only checks the deny list it is handed, so without the
# wrapper binding WS_RUN_DENY it sees an empty list and runs the command.
if out=$(in_sandbox "ws-run sandbox-check-deny git log --output=x"); then
  no "bin/ws-run ran a command matching a deny rule inside the sandbox"
else
  case "$out" in
    *"matches one of this builder's deny rules"*) ok "bin/ws-run refuses a command matching a deny rule" ;;
    *) no "bin/ws-run refused for another reason: $out" ;;
  esac
fi
# A host tool under the masked home is bound by its real install directory, so the sandbox must run that same
# tool: a missing node or one that reports another version is a failure. npx resolves through the same install.
for tool in node npx; do
  if command -v "$tool" >/dev/null; then
    host_version=$("$tool" --version); host_path=$(command -v "$tool")
    if out=$(in_sandbox "$tool --version"); then
      if [ "$out" = "$host_version" ]; then ok "$tool $out is the host's $tool"
      else no "$tool inside is $out, the host's is $host_version"; fi
    else
      no "$tool is not available inside the sandbox; the host's is $host_path $host_version"
    fi
  else
    ok "$tool is not on the host PATH, so there is no tool to compare"
  fi
done

echo
echo "sandbox-check: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
