#!/usr/bin/env bash
# OpenCode's shell for builder commands: run each command in a bubblewrap sandbox with the home directory
# masked and no network. OpenCode's agent process stays on the host, so it keeps the model connection and its
# credentials; only the commands it runs cross this boundary. There is no unsandboxed fallback: a missing,
# setuid or too-old bwrap exits non-zero with the reason.
# Usage: ws-sandbox-shell.sh -c <command>    what OpenCode's `shell` setting invokes
#        ws-sandbox-shell.sh --check         run the bwrap prerequisites, the host tool scan and the git identity
#                                            check, print the version, exit 0 or die; from inside a git worktree,
#                                            also refuse a root covering it
set -uo pipefail

# Deliberate: WORKSPACE comes from this script's own location, not from WS_RUN_GRANTS as the research note
# proposed. The wrapper has to find the workspace even when a caller points the grant file at a scratch path,
# and a script beside bin/ is a fixed point the grant file's depth is not.
WORKSPACE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# Deliberate: 0.12 is the security floor: older releases lack the fix for CVE-2026-87766, a symlink escape during
# sandbox setup. WS_SANDBOX_MIN_VERSION lowers it only so the probes can exercise this wrapper on an older bwrap.
MIN_VERSION="${WS_SANDBOX_MIN_VERSION:-0.12}"

die() { echo "ws-sandbox-shell: $*" >&2; exit 1; }

check_only=false
if [ "${1:-}" = --check ]; then check_only=true; shift; fi

# --- bubblewrap: present, not setuid, new enough ---
bwrap="${WS_SANDBOX_BWRAP:-}"
if [ -z "$bwrap" ]; then
  bwrap=$(command -v bwrap 2>/dev/null) || die "bwrap is not installed; refusing to run unsandboxed"
fi
[ -x "$bwrap" ] || die "bwrap at '$bwrap' is not executable; refusing to run unsandboxed"
# A setuid bwrap runs its setup as root, which is a root attack surface this wrapper does not need: the kernel's
# unprivileged user namespaces are enough on this machine. Any setuid bit is refused, never stripped by us.
if [ -u "$bwrap" ]; then
  die "bwrap at '$bwrap' is setuid; refusing to use a setuid bwrap (use the unprivileged package build)"
fi
bwrap_version=$("$bwrap" --version 2>/dev/null | sed -n 's/^[^0-9]*\([0-9][0-9]*\.[0-9][0-9.]*\).*$/\1/p' | head -1)
[ -n "$bwrap_version" ] || die "cannot read a version from '$bwrap --version'; refusing to run unsandboxed"
newer_or_equal() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }
newer_or_equal "$bwrap_version" "$MIN_VERSION" \
  || die "bwrap $bwrap_version is older than $MIN_VERSION; refusing to run unsandboxed"

# --- host tools installed under $HOME ---
# A node, npm or npx the host resolves from under $HOME is hidden once /home is masked. Bind each tool's real
# install directory read-only at the same path and put a folder that holds it by name on the sandbox PATH.
# Deliberate: the bind is the resolved install directory, never ~/.local or ~/.local/bin as a whole, so the
# credential folders that share those parents stay masked. A bind that is or contains a credential folder is
# refused rather than silently skipped, so a tool does not vanish without a reason, and so is a tool no bound
# folder holds under its own name.
HOST_HOME=${HOME:-}
tool_binds=()
tool_names=()
tool_hosts=()
tool_reals=()
secret_dirs=("$HOST_HOME/.local/share/opencode" "$HOST_HOME/.config" "$HOST_HOME/.ssh")

exposes_secret() {
  local dir=$1 secret
  case "$dir" in
    "$HOST_HOME/.local"|"$HOST_HOME/.local/bin") return 0 ;;
  esac
  for secret in "${secret_dirs[@]}"; do
    case "$secret" in "$dir"/*) return 0 ;; esac
    case "$dir" in "$secret"|"$secret"/*) return 0 ;; esac
  done
  return 1
}

add_tool_bind() {
  local root=$1 existing kept=()
  for existing in ${tool_binds[@]+"${tool_binds[@]}"}; do
    [ "$existing" = "$root" ] && return 0
    case "$root" in "$existing"/*) return 0 ;; esac
    # A parent replaces the child it contains, so a tool in the parent folder stays reachable.
    case "$existing" in "$root"/*) ;; *) kept+=("$existing") ;; esac
  done
  tool_binds=(${kept[@]+"${kept[@]}"} "$root")
}

is_tool_bound() {
  local dir=$1 root
  for root in ${tool_binds[@]+"${tool_binds[@]}"}; do
    case "$dir" in "$root"|"$root"/*) return 0 ;; esac
  done
  return 1
}

if [ -n "$HOST_HOME" ]; then
  for tool in node npm npx; do
    host_tool=$(type -P "$tool" 2>/dev/null) || continue
    [ -n "$host_tool" ] || continue
    real=$(readlink -f "$host_tool" 2>/dev/null) \
      || die "cannot resolve the install directory of $tool at $host_tool"
    case "$real" in "$HOST_HOME"/*) ;; *) continue ;; esac
    root=$(dirname "$real")
    [ "$(basename "$root")" = bin ] && root=$(dirname "$root")
    if exposes_secret "$root"; then
      die "refusing to bind $root for $tool: it would expose a credentials folder"
    fi
    add_tool_bind "$root"
    tool_names+=("$tool"); tool_hosts+=("$host_tool"); tool_reals+=("$real")
  done
fi

tool_ro=()
for root in ${tool_binds[@]+"${tool_binds[@]}"}; do
  tool_ro+=(--ro-bind "$root" "$root")
done

# The host's own PATH folder first, when it is bound, then the real file's folder, then each bound bin folder. The
# roots are final here: a later tool may have widened the bind that holds an earlier one.
tool_path=""
for index in ${tool_names[@]+"${!tool_names[@]}"}; do
  tool=${tool_names[$index]}
  candidates=("$(dirname "${tool_hosts[$index]}")" "$(dirname "${tool_reals[$index]}")")
  for root in "${tool_binds[@]}"; do candidates+=("$root/bin"); done
  found=""
  for dir in "${candidates[@]}"; do
    if is_tool_bound "$dir" && [ -x "$dir/$tool" ]; then found=$dir; break; fi
  done
  [ -n "$found" ] || die "$tool at ${tool_hosts[$index]} is not reachable by name once ${tool_reals[$index]} is bound; refusing to drop it"
  case ":$tool_path:" in
    *":$found:"*) ;;
    *) tool_path="${tool_path:+$tool_path:}$found" ;;
  esac
done
sandbox_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$WORKSPACE/bin"
[ -z "$tool_path" ] || sandbox_path="$tool_path:$sandbox_path"

# Binds after the writable worktree bind win, so a path that is the worktree or holds it makes the worktree read-only.
ancestor_of_wt() { case "$WT" in "$1"|"$1"/*) return 0 ;; *) return 1 ;; esac; }
# Deliberate: refused, not skipped or bound before the worktree. A skipped root loses the tool, and an earlier bind
# would show the sandbox everything else under that root.
refuse_root_over_wt() {
  local root
  for root in ${tool_binds[@]+"${tool_binds[@]}"}; do
    ancestor_of_wt "$root" && die "refusing to bind $root: it holds the worktree $WT and would make it read-only"
  done
  return 0
}

# ~/.gitconfig is masked inside the sandbox, so the identity has to arrive in the environment. An empty one
# would only fail at the first commit, after the command did its other work.
require_git_identity() {
  git_name=$(git config user.name 2>/dev/null || true)
  git_email=$(git config user.email 2>/dev/null || true)
  if [ -z "$git_name" ] || [ -z "$git_email" ]; then
    die "git user.name and user.email are not set; commits inside the sandbox would fail"
  fi
}

# --check runs the bwrap, tool, identity and worktree-root refusals. A pass speaks for the caller's working directory
# only: a builder's worktree can differ in its local git identity and in where it sits under a tool root, and outside
# any git worktree there is no root to test. The refusals that need grant files or a real worktree run only below.
if $check_only; then
  require_git_identity
  WT=$(git rev-parse --show-toplevel 2>/dev/null) || WT=""
  [ -z "$WT" ] || refuse_root_over_wt
  echo "bwrap $bwrap_version at $bwrap (not setuid)"
  exit 0
fi

# --- the caller's paths and identity ---
[ -n "${WS_RUN_GRANTS:-}" ] || die "WS_RUN_GRANTS is empty; refusing to run without the evidence runner's grant file"
[ -f "$WS_RUN_GRANTS" ] || die "WS_RUN_GRANTS ($WS_RUN_GRANTS) does not exist; refusing to run"
# ws-run skips its deny check when WS_RUN_DENY is empty, so a set-but-missing deny file would silently run a
# command OpenCode's own rules refuse. An empty value means the builder has no deny rules and is passed through
# as empty; a set one must exist and is bound into the sandbox beside the grant file.
if [ -n "${WS_RUN_DENY:-}" ] && [ ! -f "$WS_RUN_DENY" ]; then
  die "WS_RUN_DENY ($WS_RUN_DENY) does not exist; refusing to run"
fi
CWD=$(pwd -P)
WT=$(git rev-parse --show-toplevel 2>/dev/null) || die "the working directory is not inside a git worktree; refusing to run"
case "$CWD" in
  "$WT"|"$WT"/*) ;;
  *) die "the working directory $CWD is outside the worktree $WT; refusing to run" ;;
esac
refuse_root_over_wt
require_git_identity

COMMON=$(realpath "$(git rev-parse --git-common-dir)") || die "cannot resolve the git common directory"
GITDIR=$(git rev-parse --absolute-git-dir) || die "cannot resolve the git directory"
PROJECT=$(dirname "$COMMON")

# dispatch.sh links node_modules and .venv into a worktree at the top level and one folder down, plus every
# .worktree-links entry. Those links usually resolve into the main checkout, outside this worktree and so outside
# its bind, where the masked home hides them. Bind the resolved target of each link read-only. A target outside
# the project's own checkout is left alone, so a bogus link cannot drag an unrelated path into the sandbox. So is
# an ancestor of the worktree: its later --ro-bind would cover the writable worktree bind.
outside_wt() { case "$1" in "$WT"|"$WT"/*) return 1 ;; *) return 0 ;; esac; }
inside_project() { case "$1" in "$PROJECT"|"$PROJECT"/*) return 0 ;; *) return 1 ;; esac; }
links=()
link_output=$(find "$WT" -mindepth 1 -maxdepth 2 -type l) || die "cannot list the links in the worktree $WT"
while IFS= read -r link; do [ -n "$link" ] && links+=("$link"); done <<< "$link_output"
if [ -f "$PROJECT/.worktree-links" ]; then
  while IFS= read -r rel; do
    case "$rel" in ''|'#'*|/*|*..*) continue ;; esac
    [ -L "$WT/$rel" ] && links+=("$WT/$rel")
  done < "$PROJECT/.worktree-links"
fi
extra_ro=()
for link in ${links[@]+"${links[@]}"}; do
  # A dangling link has nothing to bind, and readlink -f alone would pass one whose last part is missing.
  [ -e "$link" ] || continue
  resolved=$(readlink -f "$link" 2>/dev/null) || die "cannot resolve the link $link"
  [ -n "$resolved" ] || continue
  outside_wt "$resolved" || continue
  ancestor_of_wt "$resolved" && continue
  inside_project "$resolved" || continue
  extra_ro+=(--ro-bind "$resolved" "$resolved")
done

args=(
  --die-with-parent --new-session
  --unshare-user --disable-userns --cap-drop ALL
  --unshare-pid --unshare-ipc --unshare-uts --unshare-cgroup --unshare-net
  --hostname ws-builder --clearenv
  --setenv PATH "$sandbox_path"
  --setenv HOME /tmp/ws-home
  --setenv TMPDIR /tmp/ws-home/tmp
  --setenv XDG_CACHE_HOME /tmp/ws-home/.cache
  --setenv XDG_CONFIG_HOME /tmp/ws-home/.config
  --setenv npm_config_cache /tmp/ws-home/.npm
  --setenv LANG C.UTF-8
  --setenv TERM dumb
  --setenv TZ "${TZ:-UTC}"
  --setenv GIT_CONFIG_NOSYSTEM 1
  --setenv GIT_CONFIG_GLOBAL /dev/null
  --setenv GIT_TERMINAL_PROMPT 0
  --setenv GIT_PAGER cat
  --setenv GIT_AUTHOR_NAME "$git_name"
  --setenv GIT_AUTHOR_EMAIL "$git_email"
  --setenv GIT_COMMITTER_NAME "$git_name"
  --setenv GIT_COMMITTER_EMAIL "$git_email"
  --setenv GIT_CONFIG_COUNT 2
  --setenv GIT_CONFIG_KEY_0 safe.directory
  --setenv GIT_CONFIG_VALUE_0 "$WT"
  --setenv GIT_CONFIG_KEY_1 safe.directory
  --setenv GIT_CONFIG_VALUE_1 "$PROJECT"
  --setenv WS_RUN_GRANTS "$WS_RUN_GRANTS"
  --setenv WS_RUN_DENY "${WS_RUN_DENY:-}"
  # Read-only host root, then empty filesystems over the user-data directories: a command sees the tools under
  # /usr and /opt but nothing under /home, /root or /run unless a line below binds it back.
  --ro-bind / /
  --tmpfs /home --tmpfs /root --tmpfs /run --tmpfs /var --tmpfs /mnt --tmpfs /media --tmpfs /srv
  --proc /proc --dev /dev
  --size 536870912 --tmpfs /dev/shm
  --size 2147483648 --tmpfs /tmp
  --dir /tmp/ws-home --dir /tmp/ws-home/tmp --dir /tmp/ws-home/.cache
  --dir /tmp/ws-home/.config --dir /tmp/ws-home/.npm
  --bind "$WT" "$WT"
)
# These come after the /home tmpfs so their paths exist again inside the sandbox.
[ "${#tool_ro[@]}" -eq 0 ] || args+=("${tool_ro[@]}")
[ "${#extra_ro[@]}" -eq 0 ] || args+=("${extra_ro[@]}")
args+=(
  # The worktree's .git file points at $GITDIR; $COMMON stays read-only so config and hooks cannot change,
  # while the paths git writes stay writable.
  --ro-bind "$COMMON" "$COMMON"
  --bind "$GITDIR" "$GITDIR"
  --bind "$COMMON/objects" "$COMMON/objects"
  --bind "$COMMON/refs" "$COMMON/refs"
  --bind "$COMMON/logs" "$COMMON/logs"
  --ro-bind "$WORKSPACE/bin" "$WORKSPACE/bin"
  --ro-bind "$WS_RUN_GRANTS" "$WS_RUN_GRANTS"
)
[ -z "${WS_RUN_DENY:-}" ] || args+=(
  --ro-bind "$WS_RUN_DENY" "$WS_RUN_DENY"
)
args+=(
  --chdir "$CWD"
  -- /bin/bash "$@"
)
exec "$bwrap" "${args[@]}"
