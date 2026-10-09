#!/usr/bin/env bash
# Publish the project's main branch as a release of its public repository, keeping the private history private.
# Usage: release.sh [--project slug] [--dry-run] [--notes TEXT] [--no-asset]
#
# The public repository holds one commit per release on the local branch `public-release`, pushed to the
# remote `public` as its main branch; the private repository (remote `origin`) keeps the full history.
# Each release commit has exactly main's tree (or the RELEASE_PATHS part of it), so nothing that is not on main
# can reach the public side.
#   1. main checkout clean (generated files the gate rewrites are listed by git status; restore or commit them)
#   2. version from package.json (tag vX.Y.Z); refuse a tag that already exists on `public`
#   3. audit the lines main adds since the last public release: home paths, the user name, e-mail addresses,
#      private keys and tokens, and attribution (WS_ATTRIBUTION_RE outside licence and credit files); any hit stops
#   4. push main to origin; commit main's tree on public-release (parent: the previous release, or none for the
#      first); tag; push the branch as public/main and the tag
#   5. if the project has scripts/release.sh: clone the public tag into a temp folder, `npm ci`, run it, and
#      attach release/*.zip to a GitHub release for the tag (gh), with --notes or the CHANGELOG entry
# Deliberate: plumbing (commit-tree, update-ref) instead of checking out public-release, so a dirty or odd
# working tree can never end up in a release commit, and nothing runs between building the commit and tagging it.
. "$(dirname "$0")/lib.sh"

proj="" dry=false notes="" asset=true
while [ $# -gt 0 ]; do case "$1" in
  --project) proj="$2"; shift 2 ;;
  --dry-run) dry=true; shift ;;
  --notes) notes="$2"; shift 2 ;;
  --no-asset) asset=false; shift ;;
  -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
  *) die "unknown argument $1 (see: ws release --help)" ;;
esac; done
load_project "$proj"
git_() { git -C "$PROJECT_PATH" "$@"; }

if [ -f "$PROJECT_PATH/package.json" ]; then
  version=$(node -p "require('$PROJECT_PATH/package.json').version" 2>/dev/null) || die "cannot read the version from package.json"
elif [ -f "$PROJECT_PATH/VERSION" ]; then version=$(tr -d ' \n' < "$PROJECT_PATH/VERSION")
else die "$SLUG has no package.json or VERSION to read a version from"; fi
tag="v$version"
git_ remote get-url public >/dev/null 2>&1 || die "$SLUG has no 'public' remote (git -C $PROJECT_PATH remote add public <url of the public repository>)"
public_url=$(git_ remote get-url public)
public_repo=$(printf '%s' "$public_url" | sed -E 's#^(https://github.com/|git@github.com:)##; s#\.git$##')

[ "$(git_ rev-parse --abbrev-ref HEAD)" = "$PROJECT_BRANCH" ] || die "main checkout is not on $PROJECT_BRANCH"
dirty=$(git_ status --porcelain --untracked-files=no)
[ -z "$dirty" ] || die "main checkout has modified tracked files; restore generated ones (git -C $PROJECT_PATH checkout -- <file>) or commit them first:
$dirty"

# The public tree: main's whole tree, or with RELEASE_PATHS in the project's conf only the paths it lists,
# each `path` as it is or `source=dest` to publish a file under another name (a public CHANGELOG, lessons).
# Deliberate: built in a temporary index from main's tree objects, never from the working tree.
if [ ${#RELEASE_PATHS[@]} -gt 0 ]; then
  idx=$(mktemp); rm -f "$idx"
  for entry in "${RELEASE_PATHS[@]}"; do
    src="${entry%%=*}" dest="${entry#*=}"
    listed=$(git_ ls-tree -r "$PROJECT_BRANCH" -- "$src")
    [ -n "$listed" ] || die "RELEASE_PATHS names $src, which is not on $PROJECT_BRANCH"
    if [ "$src" != "$entry" ]; then
      [ "$(wc -l <<< "$listed")" -eq 1 ] || die "RELEASE_PATHS: $entry renames a directory; rename files one by one"
      listed="${listed%%$'\t'*}"$'\t'"$dest"
    fi
    printf '%s\n' "$listed" | GIT_INDEX_FILE="$idx" git -C "$PROJECT_PATH" update-index --add --index-info
  done
  rel_tree=$(GIT_INDEX_FILE="$idx" git -C "$PROJECT_PATH" write-tree); rm -f "$idx"
  echo "public tree: ${#RELEASE_PATHS[@]} RELEASE_PATHS entries, $(git_ ls-tree -r --name-only "$rel_tree" | wc -l) files"
else
  rel_tree=$(git_ rev-parse "$PROJECT_BRANCH^{tree}")
fi

git_ fetch -q public --tags 2>/dev/null || true
if git_ ls-remote --exit-code --tags public "refs/tags/$tag" >/dev/null 2>&1; then die "$tag already exists on $public_repo; bump the version in package.json first"; fi

prev=""
git_ rev-parse -q --verify refs/heads/public-release >/dev/null && prev=$(git_ rev-parse refs/heads/public-release)
if [ -n "$prev" ]; then
  [ "$(git_ rev-parse "$prev^{tree}")" != "$rel_tree" ] || die "main has nothing new since the last public release"
  base="$prev"
else
  base=$(git_ hash-object -t tree /dev/null)   # first release: audit everything on main
fi

# 3. audit the added lines
added=$(git_ diff "$base" "$rel_tree" | grep -E '^\+[^+]' || true)
hits=$(printf '%s\n' "$added" | grep -nF -e "$HOME" -e "/$USER/" -e "-of-$USER" | head -5)
hits+=$(printf '%s\n' "$added" | grep -nE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' | grep -viE 'noreply@|@example\.|@users\.noreply' | head -5)
hits+=$(printf '%s\n' "$added" | grep -nE 'BEGIN (RSA|OPENSSH|EC|PGP|PRIVATE)|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}' | head -5)
if [ -n "${WS_ATTRIBUTION_RE:-}" ]; then
  mapfile -t exempt < <(attribution_exempt)
  attrib=$(git_ diff "$base" "$rel_tree" -- . "${exempt[@]}" | grep -E '^\+[^+]' | grep -iE "$WS_ATTRIBUTION_RE" | head -5 || true)
  hits+="$attrib"
fi
lines=$(printf '%s\n' "$added" | grep -c . || true)
if [ -n "$hits" ]; then die "release audit found (first lines; fix on main, merge, and run again):
$hits"; fi
since="nothing (first release)"; [ -n "$prev" ] && since="the last public release (${prev:0:7})"
echo "audit: $lines added lines since $since; no home paths, user name, e-mail, keys or attribution"

if $dry; then echo "dry run: would publish $SLUG $tag to $public_repo"; exit 0; fi

# 4. commit, tag, push
git_ push -q origin "$PROJECT_BRANCH"
msg="$(basename "$PROJECT_PATH") $version"
if [ -n "$prev" ]; then commit=$(git_ commit-tree "$rel_tree" -p "$prev" -m "$msg")
else commit=$(git_ commit-tree "$rel_tree" -m "$msg"); fi
[ "$(git_ rev-parse "$commit^{tree}")" = "$rel_tree" ] || die "release commit tree differs from the public tree (should be impossible)"
git_ update-ref refs/heads/public-release "$commit" ${prev:+"$prev"}
git_ tag -a "public-$tag" "$commit" -m "$msg"
git_ push -q public "refs/heads/public-release:refs/heads/main" "refs/tags/public-$tag:refs/tags/$tag"
echo "published $tag to $public_repo ($(git_ rev-parse --short "$commit"))"

# 5. release asset
if $asset && [ -f "$PROJECT_PATH/scripts/release.sh" ] && command -v gh >/dev/null; then
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  git clone -q --branch "$tag" "https://github.com/$public_repo.git" "$tmp/repo"
  ( cd "$tmp/repo" && npm ci --silent --no-audit --no-fund >/dev/null && bash scripts/release.sh ) > "$RUNS/release-$tag.log" 2>&1 \
    || die "the clean-clone build failed (log: $RUNS/release-$tag.log); the tag is published, rerun the asset with: gh release create $tag <zip> -R $public_repo"
  zips=("$tmp"/repo/release/*.zip)
  [ -e "${zips[0]}" ] || die "scripts/release.sh wrote no release/*.zip (log: $RUNS/release-$tag.log)"
  if [ -z "$notes" ] && [ -f "$PROJECT_PATH/CHANGELOG.md" ]; then
    notes=$(awk -v v="$version" '$0 ~ "^## " && index($0, v) {on=1; next} on && /^## / {exit} on' "$PROJECT_PATH/CHANGELOG.md")
  fi
  gh release create "$tag" "${zips[@]}" -R "$public_repo" --title "$msg" --notes "${notes:-$msg}" >/dev/null
  echo "release $tag: $(basename "${zips[@]}") attached (https://github.com/$public_repo/releases/tag/$tag)"
fi
