#!/usr/bin/env bash
# Copy a project's published files into the site project's repository, check every copy matches, run the
# site's tests, commit, push and wait until the live site serves them.
# Usage: site.sh [--project slug] [--dry-run]
#
# The project's conf names the site and what goes where:
#   SITE_PROJECT="my-site"                        # a registered project; its conf sets SITE_URL and SITE_ROOT
#   SITE_SYNC=("<source> <dest> [--exclude NAME ...]" ...)
# <source> is a path in the project (a directory copies its contents, a file copies itself), or
# `release:` for the project's GitHub release of its package.json version on the remote `public` (the
# zip's single top folder). <dest> is a path in the site repository. A directory dest is mirrored:
# files gone from the source are removed.
# Deliberate: rsync --checksum. Release zips have fixed timestamps (byte-identical builds), so a rebuilt
# file of the same size looks unchanged to rsync's default size-and-time check, which leaves an old
# entry script on the site pointing at chunks that have been removed.
. "$(dirname "$0")/lib.sh"
slug="" dry=false
while [ $# -gt 0 ]; do case "$1" in --project) slug="$2"; shift 2 ;; --dry-run) dry=true; shift ;; *) die "usage: site.sh [--project slug] [--dry-run]" ;; esac; done
load_project "$slug"
src_slug="$SLUG" src_path="$PROJECT_PATH"
[ -n "${SITE_PROJECT:-}" ] && [ ${#SITE_SYNC[@]} -gt 0 ] || die "projects/$src_slug.conf sets no SITE_PROJECT and SITE_SYNC"
sync=("${SITE_SYNC[@]}")
load_project "$SITE_PROJECT"
site="$PROJECT_PATH"; site_branch="$PROJECT_BRANCH"; site_tests="$TEST_CMD"
[ -n "${SITE_URL:-}" ] || die "projects/$SITE_PROJECT.conf sets no SITE_URL"
root="${SITE_ROOT:-public}"
[ -z "$(git -C "$site" status --porcelain)" ] || die "$site has uncommitted changes; commit or restore them first"
timeout 20 git -C "$site" fetch -q origin && [ "$(git -C "$site" rev-list --count "$site_branch..origin/$site_branch")" -eq 0 ] || die "$site is behind origin/$site_branch (or the fetch failed); pull first"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
version=$(node -p "require('$src_path/package.json').version" 2>/dev/null || true)
dests=()
for entry in "${sync[@]}"; do
  read -r -a parts <<< "$entry"; src="${parts[0]}" dest="${parts[1]}"; extra=("${parts[@]:2}")
  if [ "$src" = "release:" ]; then
    repo=$(git -C "$src_path" remote get-url public 2>/dev/null | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##') || true
    [ -n "$repo" ] && [ -n "$version" ] || die "release: needs a remote 'public' and a package.json version in $src_path"
    gh release download "v$version" -R "$repo" -p '*.zip' -D "$tmp/zip" >/dev/null || die "no release v$version on $repo (run ws release first)"
    mkdir -p "$tmp/unzipped"; unzip -q "$tmp"/zip/*.zip -d "$tmp/unzipped"
    tops=("$tmp"/unzipped/*); [ ${#tops[@]} -eq 1 ] && [ -d "${tops[0]}" ] || die "the release zip has no single top folder"
    from="${tops[0]}/"; label="$repo v$version"
  else
    from="$src_path/$src"; [ -e "$from" ] || die "no $src in $src_path"
    [ -d "$from" ] && from="${from%/}/"; label="$src_slug/$src"
  fi
  to="$site/$dest"; dests+=("$dest")
  if [ -d "$from" ]; then
    mkdir -p "$to"; rsync -a --checksum --delete "${extra[@]}" "$from" "${to%/}/"
    ex=(); for ((i=0; i<${#extra[@]}; i++)); do [ "${extra[i]}" = --exclude ] && ex+=(--exclude "${extra[i+1]}"); done
    diff -rq "${ex[@]}" "${from%/}" "${to%/}" >/dev/null || die "$dest does not match $label after the copy"
  else
    mkdir -p "$(dirname "$to")"; cp "$from" "$to"; cmp -s "$from" "$to" || die "$dest does not match $label after the copy"
  fi
  echo "copied $label -> $dest (matches)"
done

changed=$(git -C "$site" status --porcelain -- "${dests[@]}")
[ -n "$changed" ] || { echo "the site already has these files; nothing to commit"; exit 0; }
echo "$(wc -l <<< "$changed") file(s) changed in $site"
if $dry; then git -C "$site" checkout -q -- "${dests[@]}" 2>/dev/null; git -C "$site" clean -fdq -- "${dests[@]}"; echo "dry run: copies checked and undone"; exit 0; fi
if [ -n "$site_tests" ]; then
  log="$RUNS/site-$src_slug.tests.log"
  ( cd "$site" && bash -c "$site_tests" ) > "$log" 2>&1 || { tail -n 20 "$log"; die "the site's tests failed; the copies are left uncommitted in $site. Log: ${log#"$WS/"}"; }
  echo "site tests passed (log: ${log#"$WS/"})"
fi
git -C "$site" add -A -- "${dests[@]}"
git -C "$site" commit -q -m "$src_slug${version:+ $version}: site copy of ${dests[*]}" || die "commit failed"
git -C "$site" push -q origin "$site_branch" || die "push failed; the commit is local"
sha=$(git -C "$site" rev-parse --short HEAD); echo "pushed $sha"

# One changed file per destination, fetched from the live site until it matches the commit.
probes=()
for dest in "${dests[@]}"; do
  f=$(git -C "$site" diff --name-only --diff-filter=AM HEAD^ HEAD -- "$dest" | head -1); [ -n "$f" ] && probes+=("$f")
done
for ((i=0; i<40; i++)); do
  ok=true
  for f in "${probes[@]}"; do curl -sf "$SITE_URL/${f#"$root"/}" | cmp -s - "$site/$f" || { ok=false; break; }; done
  $ok && { echo "live after ~$((i * 15))s ($SITE_URL)"; exit 0; }
  sleep 15
done
die "pushed $sha, but the live site did not serve it within 10 minutes"
