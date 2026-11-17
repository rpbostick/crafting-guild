#!/usr/bin/env bash
# Check the links of the file set a release publishes. Two rules, one line per problem:
#   - a relative Markdown link or image in a shipped file must name a file that ships too (an anchor after `#`
#     is dropped first, `http(s)://`, `mailto:` and other URL schemes are skipped, and a directory target is
#     satisfied by any shipped file under it);
#   - every path RELEASE_PATHS names must exist in the set.
# A link to a file outside the release is a 404 on the public repository, and nothing on the private side fails
# when it is written: the shipped tree is checked as a whole, by the same list `ws release` publishes.
# The set is the release's tracked files, never the whole working directory: `ws release` builds the public tree
# from the branch's objects, so an installed `node_modules` (or any other untracked file) is not published and must
# not be scanned -- a vendored package's README links files its own package does not ship. A checkout is read
# through its index (`git ls-files`, restricted to the RELEASE_PATHS entries, a `source=dest` rename honoured); a
# staged copy has no index and is read from disk, where a `node_modules` directory is skipped by name.
# Usage: link-check.sh [--project <slug>] [--tree <dir>]
#   --tree <dir>  check a staged copy of the public tree, or a checkout of it. The top of a git work tree is read
#                 as its tracked files, a `source=dest` entry from `source` when the tree holds it (as a checkout of
#                 the private tree does); a staged copy is read as the files it holds, under the published `dest`
#                 name. Without --tree the shipped set is the one the release builds from the project's branch, so
#                 the check reads the published tree (git objects), not the main checkout's working files.
# Inline links and images (`[text](target)`, `![alt](target)`) are checked outside fenced code blocks and inline
# code spans, where they are examples of the syntax rather than links. Reference definitions and HTML attributes are
# not checked. A target containing a nested `)` is read only up to that `)`, so its link is checked as the truncated
# path; no shipped file uses one.
set -uo pipefail
. "$(dirname "$0")/lib.sh"

slug="" tree=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project) slug="$2"; shift 2 ;;
    --tree) tree="$2"; shift 2 ;;
    -*) die "unknown flag $1" ;;
    *) die "unexpected argument $1 (see: ws help)" ;;
  esac
done
load_project "$slug"
git_() { git -C "$PROJECT_PATH" "$@"; }
[ -z "$tree" ] || [ -d "$tree" ] || die "no tree directory $tree"

declare -A shipped=() where=()
problems=0 links=0 mdfiles=0
problem() { printf 'link-check: %s\n' "$*"; problems=$((problems + 1)); }

# An installed package tree never ships, even when a directory entry holds it: in a checkout it is not tracked,
# and in a staged copy it is where a vendored README links files its own package does not publish.
ships() { case "/$1/" in */node_modules/*) return 1 ;; esac; return 0; }

# The shipped files, keyed by the path the public tree holds them under. A `source=dest` entry ships under `dest`;
# with no RELEASE_PATHS the release publishes the branch's whole tree.
collect_from_git() {
  local entry src dest listed f
  if [ ${#RELEASE_PATHS[@]} -eq 0 ]; then
    while IFS= read -r f; do
      [ -n "$f" ] && ships "$f" && { shipped["$f"]=1; where["$f"]="git:$f"; }
    done < <(git_ ls-tree -r --name-only "$PROJECT_BRANCH")
    return
  fi
  for entry in "${RELEASE_PATHS[@]}"; do
    src="${entry%%=*}" dest="${entry#*=}"
    listed=$(git_ ls-tree -r --name-only "$PROJECT_BRANCH" -- "$src")
    if [ -z "$listed" ]; then problem "RELEASE_PATHS names $src, which is not on $PROJECT_BRANCH"; continue; fi
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      ships "$f" || continue
      # Only a file is renamed (`ws release` refuses a directory rename), so the dest path is the shipped path.
      if [ "$src" != "$entry" ]; then shipped["$dest"]=1; where["$dest"]="git:$f"
      else shipped["$f"]=1; where["$f"]="git:$f"; fi
    done <<< "$listed"
  done
}

# Whether <dir> is the top of a git work tree. Only then does it have an index to read the released set from; a
# staged copy (and a directory inside another repository) is read from disk instead.
tree_tracked=false
if [ -n "$tree" ]; then
  top=$(git -C "$tree" rev-parse --show-toplevel 2>/dev/null) || top=""
  [ -n "$top" ] && [ "$top" = "$(cd "$tree" && pwd -P)" ] && tree_tracked=true
fi

# The candidate file names under <path> of the tree, relative to it: a checkout is listed from its index (the
# tracked set a release commits), a staged copy from disk. The caller drops `node_modules` and a tracked file the
# checkout no longer holds.
tree_files() { # <path relative to the tree: a file or a directory>
  local rel="$1"
  if [ -d "$tree/$rel" ]; then
    ( cd "$tree/$rel" && if [ "$tree_tracked" = true ]; then git ls-files
      else find . -type f -not -path './.git/*' | sed 's|^\./||'; fi )
  elif [ "$tree_tracked" = true ]; then
    ( cd "$tree/$(dirname "$rel")" && git ls-files -- "$(basename "$rel")" )
  elif [ -e "$tree/$rel" ]; then
    printf '%s\n' "$(basename "$rel")"
  fi
}

collect_from_tree() {
  local entry src dest from f found
  if [ ${#RELEASE_PATHS[@]} -eq 0 ]; then
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      ships "$f" || continue
      if [ "$tree_tracked" = true ] && [ ! -f "$tree/$f" ]; then problem "$f: tracked but missing from the checkout"; continue; fi
      shipped["$f"]=1; where["$f"]="disk:$f"
    done < <(tree_files .)
    return
  fi
  for entry in "${RELEASE_PATHS[@]}"; do
    src="${entry%%=*}" dest="${entry#*=}" from=""
    # A checkout of the private tree holds both names: the published file is built from `source`, so that is the
    # file whose links go public. A staged copy holds only the published `dest` name.
    if [ "$src" != "$dest" ] && [ -e "$tree/$src" ]; then from="$src"
    elif [ -e "$tree/$dest" ]; then from="$dest"
    fi
    if [ -z "$from" ]; then problem "RELEASE_PATHS names $dest, which is not in $tree"; continue; fi
    if [ -d "$tree/$from" ]; then
      found=0
      while IFS= read -r f; do
        [ -n "$f" ] || continue
        ships "$f" || continue
        found=1
        if [ "$tree_tracked" = true ] && [ ! -f "$tree/$from/$f" ]; then problem "$from/$f: tracked but missing from the checkout"; continue; fi
        shipped["$dest/$f"]=1; where["$dest/$f"]="disk:$from/$f"
      done < <(tree_files "$from")
      # An entry that ships no file is a problem of its own: the release would publish a directory name with nothing
      # under it, and a link to it would 404. A staged copy with only `node_modules` under the entry counts as empty
      # too, because that directory never ships.
      [ "$found" = 1 ] || problem "RELEASE_PATHS names $dest, which holds no file to ship"
    else
      # A named file is published only when the release's set holds it: a checkout ships its tracked files, so a
      # file its index does not list is named here rather than checked as if it would go public.
      if [ "$tree_tracked" = true ] && [ -z "$(cd "$tree" && git ls-files -- "$from")" ]; then
        problem "RELEASE_PATHS names $dest, which is not tracked in the tree"; continue
      fi
      ships "$from" || continue
      shipped["$dest"]=1; where["$dest"]="disk:$from"
    fi
  done
}

# A target with its `.`/`..` components resolved, relative to the shipped root; fails when it climbs above it.
normalize() {
  local part out=() IFS=/
  # shellcheck disable=SC2086  # splitting one path into its components is the point
  for part in $1; do
    case "$part" in
      ''|.) continue ;;
      ..) [ ${#out[@]} -gt 0 ] || return 1; unset 'out[-1]' ;;
      *) out+=("$part") ;;
    esac
  done
  IFS=/; printf '%s\n' "${out[*]}"
}

# `word` is the target as the Markdown writes it, `dir` the shipped directory of the file it appears in.
check_target() { # <file:line> <dir> <word>
  local at="$1" dir="$2" word="$3" target resolved
  target="$word"
  case "$target" in
    '<'*) target="${target#<}"; target="${target%%>*}" ;;   # <a path with spaces>: the spaces are the path's
    *) target="${target%%[[:space:]]*}" ;;                  # a title after the target
  esac
  [ -n "$target" ] || return 0
  case "$target" in \#*) return 0 ;; esac          # an in-page anchor
  # A URL scheme is not a file in the tree; only a path relative to the repository is checked.
  if [[ "$target" =~ ^[A-Za-z][A-Za-z0-9+.-]*: ]]; then return 0; fi
  target="${target%%#*}"                           # `file.md#anchor` names the file
  [ -n "$target" ] || return 0
  case "$target" in
    /*) problem "$at: $target is an absolute path, not a shipped file"; return 0 ;;
  esac
  links=$((links + 1))
  resolved=$(normalize "${dir:+$dir/}$target") || { problem "$at: $target climbs above the shipped tree"; return 0; }
  # A directory target is satisfied by any shipped file under it. A trailing slash marks one, and so does a target
  # that is a prefix of a shipped path: GitHub resolves `[x](docs)` to the directory too, so the file lookup below
  # would report a link that works as a 404. The resolved prefix is quoted, so a name holding a glob character is
  # matched literally; an empty one (the shipped root) is a prefix of every key.
  local f under=false
  for f in "${!shipped[@]}"; do
    case "$f" in "${resolved:+$resolved/}"*) under=true; break ;; esac
  done
  if [ "${target%/}" != "$target" ] || [ "$under" = true ]; then
    [ "$under" = true ] && return 0
    problem "$at: $target is a directory with no shipped file under it"
    return 0
  fi
  [ -n "${shipped[$resolved]:-}" ] || problem "$at: $target does not ship (a 404 on the public repository)"
}

# Links shown inside a fenced code block or an inline code span are examples of the syntax, not links: a doc that
# teaches Markdown must not fail its own check. A fence is dropped whole and a backticked span is blanked first.
scan_file() { # <shipped path> <content file>
  local path="$1" content="$2" dir line target
  dir=$(dirname "$path"); [ "$dir" = . ] && dir=""
  mdfiles=$((mdfiles + 1))
  while IFS=$'\t' read -r line target; do
    [ -n "$line" ] || continue
    check_target "$path:$line" "$dir" "$target"
  done < <(awk '
    BEGIN { fence = 0 }
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    {
      text = $0
      gsub(/`[^`]*`/, "", text)
      while (match(text, /\]\([^)]*\)/)) {
        printf "%d\t%s\n", FNR, substr(text, RSTART + 2, RLENGTH - 3)
        text = substr(text, RSTART + RLENGTH)
      }
    }' "$content")
}

if [ -z "$tree" ]; then collect_from_git; else collect_from_tree; fi
[ ${#shipped[@]} -gt 0 ] || die "the shipped set is empty; check RELEASE_PATHS in projects/$SLUG.conf"

tmp=$(mktemp) || die "could not write a temporary file"
trap 'rm -f "$tmp"' EXIT
mapfile -t paths < <(printf '%s\n' "${!shipped[@]}" | LC_ALL=C sort)
for path in "${paths[@]}"; do
  case "$path" in *.md|*.markdown|*.MD) ;; *) continue ;; esac
  src="${where[$path]#*:}"
  if [ "${where[$path]%%:*}" = git ]; then
    git_ show "$PROJECT_BRANCH:$src" > "$tmp" || { problem "$path could not be read from $PROJECT_BRANCH"; continue; }
    scan_file "$path" "$tmp"
  else
    scan_file "$path" "$tree/$src"
  fi
done

if [ "$problems" -gt 0 ]; then
  printf 'link-check: %s problem(s) in %s shipped files\n' "$problems" "${#shipped[@]}"
  exit 1
fi
printf 'link-check: 0 problems: %s shipped files, %s relative links in %s Markdown files\n' \
  "${#shipped[@]}" "$links" "$mdfiles"
