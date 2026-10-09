#!/usr/bin/env bash
# Put the project's published files back to a public release, as one new commit on main. Nothing else
# changes: with RELEASE_PATHS, files outside them (plans, project confs, private lessons) stay as they are.
# History is kept, so the rollback itself can be reverted.
# Usage: rollback.sh [--project slug] [--dry-run] <version|vX.Y.Z>     (lists releases without a version)
. "$(dirname "$0")/lib.sh"
# Deliberate: the whole body is one function, read before it runs. Rolling the workspace itself back rewrites
# or deletes this very file, and bash reads a running script from disk as it goes.
main() {
slug="" dry=false ver=""
while [ $# -gt 0 ]; do case "$1" in --project) slug="$2"; shift 2 ;; --dry-run) dry=true; shift ;; -*) die "unknown flag $1" ;; *) ver="$1"; shift ;; esac; done
load_project "$slug"
git_() { git -C "$PROJECT_PATH" "$@"; }
if [ -z "$ver" ]; then
  echo "releases of $SLUG (newest first):"; git_ tag -l 'public-v*' --sort=-v:refname | sed 's/^public-/  /'
  echo "usage: ws rollback [--dry-run] <version>"; exit 0
fi
tag="v${ver#v}"; ref="public-$tag"
git_ rev-parse -q --verify "refs/tags/$ref" >/dev/null || die "no release $tag here (ws rollback lists them)"
[ "$(git_ rev-parse --abbrev-ref HEAD)" = "$PROJECT_BRANCH" ] || die "$PROJECT_PATH is not on $PROJECT_BRANCH"
[ -z "$(git_ status --porcelain --untracked-files=no)" ] || die "$PROJECT_PATH has modified tracked files; commit or restore them first"

# Public path -> private path: RELEASE_PATHS renames (source=dest) map back; every other path is the same.
declare -A back=()
for e in "${RELEASE_PATHS[@]}"; do [ "$e" != "${e#*=}" ] && back["${e#*=}"]="${e%%=*}"; done
# Files to restore, from the release's tree.
mapfile -t pub < <(git_ ls-tree -r --name-only "$ref")
restore=(); for f in "${pub[@]}"; do restore+=("${back[$f]:-$f}"); done
# Files to delete: tracked now, inside what is published, and not in the release.
if [ ${#RELEASE_PATHS[@]} -gt 0 ]; then
  scope=(); for e in "${RELEASE_PATHS[@]}"; do scope+=("${e%%=*}"); done
  mapfile -t current < <(git_ ls-files -- "${scope[@]}")
else
  mapfile -t current < <(git_ ls-files)
fi
declare -A keep=(); for f in "${restore[@]}"; do keep["$f"]=1; done
remove=(); for f in "${current[@]}"; do [ -n "${keep[$f]:-}" ] || remove+=("$f"); done

changed=$(for i in "${!pub[@]}"; do
  a=$(git_ rev-parse -q --verify "$ref:${pub[$i]}" 2>/dev/null); b=$(git_ rev-parse -q --verify "HEAD:${restore[$i]}" 2>/dev/null)
  [ "$a" = "$b" ] || echo "  restore ${restore[$i]}"
done)
gone=$(for f in "${remove[@]}"; do echo "  delete  $f"; done)
if [ -z "$changed$gone" ]; then echo "$SLUG's published files already match $tag; nothing to do"; exit 0; fi
echo "rolling $SLUG's published files back to $tag:"; [ -n "$changed" ] && echo "$changed"; [ -n "$gone" ] && echo "$gone"
$dry && { echo "dry run: nothing changed"; exit 0; }

for i in "${!pub[@]}"; do
  dest="$PROJECT_PATH/${restore[$i]}"; mkdir -p "$(dirname "$dest")"
  git_ show "$ref:${pub[$i]}" > "$dest"
  mode=$(git_ ls-tree "$ref" -- "${pub[$i]}" | cut -d' ' -f1); [ "$mode" = 100755 ] && chmod +x "$dest" || chmod -x "$dest"
done
[ ${#remove[@]} -gt 0 ] && git_ rm -q -- "${remove[@]}"
git_ add -- "${restore[@]}"
git_ commit -q -m "Roll the published files back to $tag

Restores every file of the public release $tag and removes published files added since. Files outside
RELEASE_PATHS are unchanged. Revert this commit to undo the rollback." || die "commit failed"
echo "committed $(git_ rev-parse --short HEAD): rolled back to $tag (not pushed). The next release needs a version above the newest public one."
}
main "$@"
