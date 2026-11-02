#!/usr/bin/env bash
# The binds ws-sandbox-shell.sh hands to bwrap, on throwaway project and home layouts; selftest.sh runs this. A stand-in
# bwrap records its arguments, so the check runs on a host with any bubblewrap or none. Bind order decides what is
# writable: a later bind of a path covers an earlier bind beneath it.
set -uo pipefail
WS="$(cd "$(dirname "$0")/.." && pwd)"
tmp=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$tmp"' EXIT
fail() { echo "sandbox-binds check FAILED: $1"; [ ! -f "$tmp/args" ] || cat "$tmp/args"; exit 1; }

cat > "$tmp/bwrap" <<'STUB'
#!/bin/sh
if [ "$1" = --version ]; then echo "bubblewrap 0.12.0"; exit 0; fi
printf '%s\n' "$@" > "$SB_ARGS"
STUB
chmod +x "$tmp/bwrap"
printf 'true\n' > "$tmp/grants"

proj="$tmp/proj"; wt="$proj/.worktrees/wt"; home="$tmp/home"
mkdir -p "$proj" "$home"
printf '[user]\n\tname = selftest\n\temail = selftest@example.invalid\n' > "$home/.gitconfig"
git_home() { HOME="$home" git -C "$proj" "$@"; }
git_home init -q -b main
git_home commit -q --allow-empty -m first
git_home worktree add -q "$wt" -b wt

# One wrapper run from the worktree; <tool dirs> goes in front of PATH, so `type -P` finds the tools laid out there.
run_wrapper() { # <tool dirs> <wrapper args...>
  local dirs=$1; shift
  rm -f "$tmp/args"
  out=$(cd "$wt" && HOME="$home" PATH="$dirs:/usr/bin:/bin" SB_ARGS="$tmp/args" WS_SANDBOX_BWRAP="$tmp/bwrap" \
    WS_RUN_GRANTS="$tmp/grants" WS_RUN_DENY="" bash "$WS/scripts/ws-sandbox-shell.sh" "$@" 2>&1)
}
wrap() { run_wrapper "$1" -c true; }
check() { run_wrapper "$1" --check; }
# Every path the arguments bind read-only after the worktree's own writable bind.
ro_after_wt() { awk -v wt="$wt" '
  !seen && prev2 == "--bind" && prev1 == wt && $0 == wt { seen = 1 }
  seen && prev2 == "--ro-bind" && prev1 == $0 { print }
  { prev2 = prev1; prev1 = $0 }' "$tmp/args"; }
ro_bound() { grep -A1 -x -- '--ro-bind' "$tmp/args" | grep -qx -- "$1"; }
sandbox_path() { grep -A1 -x PATH "$tmp/args" | tail -1; }
tool() { # <path>: a stand-in executable, its folders created
  mkdir -p "$(dirname "$1")"; printf '#!/bin/sh\n' > "$1"; chmod +x "$1"
}

# --- a link to an ancestor of the worktree must not cover the writable bind ---
mkdir -p "$wt/app"
ln -s "$proj" "$wt/up-project"
ln -s "$proj/.worktrees" "$wt/app/up-worktrees"
mkdir -p "$proj/deps"
ln -s "$proj/deps" "$wt/node_modules"
wrap "/nonexistent" || fail "the wrapper refused a worktree with ancestor links: $out"
[ -s "$tmp/args" ] || fail "the wrapper did not reach bwrap: $out"
while IFS= read -r bound; do
  case "$wt" in "$bound"|"$bound"/*) fail "$bound is bound read-only after the worktree and covers it" ;; esac
done < <(ro_after_wt)
# The skip is only for ancestors: an ordinary link target stays bound.
ro_bound "$proj/deps" || fail "the link target $proj/deps is not bound"
rm -f "$wt/up-project" "$wt/app/up-worktrees" "$wt/node_modules"

# --- a dangling link has nothing to bind and stops nothing ---
# Both shapes: with its target's folder gone readlink -f fails, and with only the last part gone it succeeds and
# would hand bwrap a source path that does not exist, which bwrap refuses.
ln -s "$proj/no-such-folder/deps" "$wt/gone-folder"
ln -s "$proj/no-such-file" "$wt/gone-file"
wrap "/nonexistent" || fail "a dangling link stopped the wrapper: $out"
[ -s "$tmp/args" ] || fail "the wrapper did not reach bwrap past a dangling link: $out"
ro_bound "$proj/no-such-file" && fail "the wrapper bound the missing target of a dangling link"
rm -f "$wt/gone-folder" "$wt/gone-file"

# --- a later parent root replaces the child already bound ---
# node's real file sits below npm's root, so node's root comes first and npm's is its parent.
parent="$home/tools/node"
tool "$parent/lib/deep/bin/node"
tool "$parent/bin/npm"
mkdir -p "$home/path1"
ln -s "$parent/lib/deep/bin/node" "$home/path1/node"
ln -s "$parent/bin/npm" "$home/path1/npm"
wrap "$home/path1" || fail "the parent-root layout was refused: $out"
ro_bound "$parent" || fail "the parent root $parent is not bound"
ro_bound "$parent/lib/deep" && fail "the child root stayed bound beside its parent"
case ":$(sandbox_path):" in
  *":$parent/lib/deep/bin:$parent/bin:"*) ;;
  *) fail "node's and npm's folders are not both on the sandbox PATH: $(sandbox_path)" ;;
esac

# --- a tool whose real file is outside a bin folder stays reachable ---
share="$home/.local/share/nodeplain"
tool "$share/node"
mkdir -p "$home/path2"
ln -s "$share/node" "$home/path2/node"
wrap "$home/path2" || fail "a node outside a bin folder was refused: $out"
ro_bound "$share" || fail "the install directory $share is not bound"
case ":$(sandbox_path):" in *":$share:"*) ;; *) fail "$share is not on the sandbox PATH: $(sandbox_path)" ;; esac
# The host's PATH folder is masked inside, so it must not be what reaches the tool.
case ":$(sandbox_path):" in *":$home/path2:"*) fail "a masked folder is on the sandbox PATH: $(sandbox_path)" ;; esac

# --- a tool the bound folders cannot reach under its own name is refused, not dropped ---
renamed="$home/tools/renamed"
tool "$renamed/npm-cli.js"
mkdir -p "$home/path3"
ln -s "$renamed/npm-cli.js" "$home/path3/npm"
x=0; wrap "$home/path3" || x=$?
[ "$x" = 1 ] || fail "a tool with no reachable name ran (exit $x): $out"
grep -q "npm at .* is not reachable by name" <<< "$out" || fail "the refusal does not name the tool: $out"

# --- --check reports what would stop every builder command ---
check "$home/path2" || fail "--check refused a layout that runs: $out"
grep -q "^bwrap 0.12.0 at " <<< "$out" || fail "--check did not print the version: $out"
x=0; check "$home/path3" || x=$?
[ "$x" = 1 ] && grep -q "npm at .* is not reachable by name" <<< "$out" || fail "--check passed an unreachable tool (exit $x): $out"
tool "$home/.config/tools/bin/node"
x=0; check "$home/.config/tools/bin" || x=$?
[ "$x" = 1 ] && grep -q "would expose a credentials folder" <<< "$out" || fail "--check passed a credentials bind (exit $x): $out"
# A missing identity stops every command too, whichever half of it is gone. The null global config hides the
# throwaway home's identity, and the system config is left out so the host's cannot supply one.
printf '[user]\n\tname = selftest\n' > "$tmp/name-only"
printf '[user]\n\temail = selftest@example.invalid\n' > "$tmp/email-only"
for config in /dev/null "$tmp/name-only" "$tmp/email-only"; do
  x=0; GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$config" check "/nonexistent" || x=$?
  [ "$x" = 1 ] && grep -q "git user.name and user.email are not set" <<< "$out" \
    || fail "--check passed a missing git identity with global config $config (exit $x): $out"
done
x=0; GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null wrap "/nonexistent" || x=$?
[ "$x" = 1 ] && grep -q "git user.name and user.email are not set" <<< "$out" || fail "a missing git identity ran (exit $x): $out"
[ ! -e "$tmp/args" ] || fail "a missing git identity reached bwrap: $out"

# --- a tool root at or above the worktree must not cover the writable bind ---
# The tool binds come after the worktree's, so such a root would make every write a builder tries fail.
outer="$home/outer"; inner="$outer/wt2"
mkdir -p "$outer"
git_home worktree add -q "$inner" -b wt2
wt="$inner"
tool "$outer/bin/node"
tool "$inner/bin/node"
for root in "$outer/bin" "$inner/bin"; do
  x=0; wrap "$root" || x=$?
  [ "$x" = 1 ] && grep -q "it holds the worktree $inner" <<< "$out" || fail "a tool root over the worktree ran (exit $x): $out"
  [ ! -e "$tmp/args" ] || fail "a tool root over the worktree reached bwrap: $out"
  x=0; check "$root" || x=$?
  [ "$x" = 1 ] && grep -q "it holds the worktree $inner" <<< "$out" || fail "--check passed a tool root over the worktree (exit $x): $out"
done
# Away from any worktree there is nothing to cover, and --check still runs.
wt="$tmp"
check "$outer/bin" || fail "--check outside a git worktree refused: $out"
echo "sandbox-binds check ok"
