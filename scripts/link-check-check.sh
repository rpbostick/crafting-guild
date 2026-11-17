#!/usr/bin/env bash
# The link check's cases: a shipped file that links a doc which does not ship fails, the same tree with the doc
# shipped passes, an external URL and an in-page anchor are ignored, a RELEASE_PATHS entry that is not in the tree
# fails, and a staged copy of the public tree checks the same way. A directory target passes with or without the
# trailing slash and fails when the release ships nothing under it; a RELEASE_PATHS directory entry that holds no
# file fails. A bracketed target keeps its spaces, a link shown inside inline code or a fence is an example, a
# rename entry reads `source` in a tree that holds both names, and an installed `node_modules` is not part of a
# release (a checkout ships its tracked files; a copy skips it).
# selftest.sh runs this (or `selftest.sh --link-check` alone). Prints one line per case, exits 1 if any failed.
set -uo pipefail
. "$(dirname "$0")/lib.sh"

repo=$(mktemp -d)
slug="link-$(basename "$repo" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/-*$//')"
conf="$WS/projects/$slug.conf"
check="$WS/scripts/link-check.sh"
rc=0
out="" x=0

cleanup() { rm -rf "$repo" "$WS/runs/$slug" "$WS/plans/$slug"; rm -f "$conf"; }
trap cleanup EXIT
fail() { echo "link-check FAILED: $1"; printf '%s\n' "${out:-}"; rc=1; }

git -C "$repo" init -q -b main
printf 'PROJECT_PATH="%s"\nPROJECT_BRANCH="main"\nTEST_CMD=""\n' "$repo" > "$conf"
mkdir -p "$repo/docs" "$repo/private"
printf '# Guide\n\n[the manual](docs/manual.md)\n[upstream](https://example.com/guide.md)\n[jump](#guide)\n' > "$repo/README.md"
printf '# Manual\n' > "$repo/docs/manual.md"
printf '# Notes\n' > "$repo/private/notes.md"
git -C "$repo" add -A
git -C "$repo" -c user.name=t -c user.email=t@t commit -qm init

# A shipped file that links a doc outside the shipped set: one problem, naming the file, the line and the target.
printf 'RELEASE_PATHS=("README.md" "private/notes.md")\n' >> "$conf"
x=0; out=$(bash "$check" --project "$slug" 2>&1) || x=$?
if [ "$x" = 1 ] \
  && grep -qx 'link-check: README.md:3: docs/manual.md does not ship (a 404 on the public repository)' <<< "$out" \
  && [ "$(grep -c '^link-check: README.md:' <<< "$out")" = 1 ]; then
  echo "a link to an unshipped doc fails once, and https and #anchor links are ignored ok"
  grep '^link-check: ' <<< "$out" | sed 's/^/    reported: /'
else fail "a link to an unshipped doc is not reported once (exit $x)"; fi

# The same tree with the doc shipped: the directory entry covers docs/manual.md.
printf 'RELEASE_PATHS=("README.md" "docs" "private/notes.md")\n' >> "$conf"
x=0; out=$(bash "$check" --project "$slug" 2>&1) || x=$?
if [ "$x" = 0 ] && grep -q '^link-check: 0 problems:' <<< "$out"; then
  echo "the same tree with the doc shipped passes ok"
else fail "shipping the linked doc did not pass (exit $x)"; fi

# A RELEASE_PATHS entry that names no file in the tree is a problem of its own.
printf 'RELEASE_PATHS=("README.md" "docs" "gone.md")\n' >> "$conf"
x=0; out=$(bash "$check" --project "$slug" 2>&1) || x=$?
if [ "$x" = 1 ] && grep -qx 'link-check: RELEASE_PATHS names gone.md, which is not on main' <<< "$out"; then
  echo "a RELEASE_PATHS entry missing from the tree fails ok"
  grep '^link-check: ' <<< "$out" | sed 's/^/    reported: /'
else fail "a missing RELEASE_PATHS entry is not reported (exit $x)"; fi

# A staged copy of the public tree: the check reads the files it holds, so it can run on what a release would
# publish before that tree exists anywhere else.
printf 'RELEASE_PATHS=("README.md" "docs")\n' >> "$conf"
ship="$repo/stage/ship"
mkdir -p "$ship/docs"
cp "$repo/README.md" "$ship/README.md"; cp "$repo/docs/manual.md" "$ship/docs/manual.md"
x=0; out=$(bash "$check" --project "$slug" --tree "$ship" 2>&1) || x=$?
if [ "$x" = 0 ] && grep -q '^link-check: 0 problems:' <<< "$out"; then
  echo "a staged copy of the shipped files passes ok"
else fail "the staged copy did not pass (exit $x)"; fi
printf '[the guide](guide/missing.md)\n' >> "$ship/README.md"
x=0; out=$(bash "$check" --project "$slug" --tree "$ship" 2>&1) || x=$?
if [ "$x" = 1 ] && grep -qx 'link-check: README.md:6: guide/missing.md does not ship (a 404 on the public repository)' <<< "$out"; then
  echo "a staged copy with a link to a file it does not hold fails ok"
else fail "the staged copy check named no missing target (exit $x)"; fi

# GitHub resolves `[x](docs)` to the same directory as `[x](docs/)`, so a directory target is satisfied by a shipped
# file under it with or without the trailing slash. The same directory still fails when the release does not ship it,
# even though it exists in the checkout.
printf '[the manual](docs)\n[the manual again](docs/)\n' >> "$repo/README.md"
printf 'RELEASE_PATHS=("README.md" "docs" "private/notes.md")\n' >> "$conf"
x=0; out=$(bash "$check" --project "$slug" --tree "$repo" 2>&1) || x=$?
if [ "$x" = 0 ] && grep -q '^link-check: 0 problems:' <<< "$out"; then
  echo "a directory link with and without a trailing slash passes when the directory ships ok"
else fail "a directory link to a shipped directory failed (exit $x)"; fi
printf 'RELEASE_PATHS=("README.md" "private/notes.md")\n' >> "$conf"
x=0; out=$(bash "$check" --project "$slug" --tree "$repo" 2>&1) || x=$?
if [ "$x" = 1 ] \
  && grep -qx 'link-check: README.md:6: docs does not ship (a 404 on the public repository)' <<< "$out" \
  && grep -qx 'link-check: README.md:7: docs/ is a directory with no shipped file under it' <<< "$out"; then
  echo "a directory link that ships nothing fails with and without a trailing slash ok"
else fail "a directory link to an unshipped directory was not reported (exit $x)"; fi
# The two links were added to a README the later cases read too; put it back as the fixture made it.
printf '# Guide\n\n[the manual](docs/manual.md)\n[upstream](https://example.com/guide.md)\n[jump](#guide)\n' > "$repo/README.md"
printf 'RELEASE_PATHS=("README.md" "docs" "private/notes.md")\n' >> "$conf"

# A bracketed target keeps the spaces in its path, and a link shown inside inline code or a fenced block is an
# example rather than a link, so a doc that teaches the syntax passes its own check. A checkout lists its tracked
# files, so the new doc is staged the way a commit would make it tracked.
printf '# Manual of two words\n' > "$repo/docs/manual with space.md"
git -C "$repo" add "docs/manual with space.md"
printf '[the manual](<docs/manual with space.md> "the guide")\nclick `[example](docs/missing.md)`\n```\n[example](docs/missing.md)\n```\n' >> "$repo/README.md"
x=0; out=$(bash "$check" --project "$slug" --tree "$repo" 2>&1) || x=$?
if [ "$x" = 0 ] && grep -q '^link-check: 0 problems:' <<< "$out"; then
  echo "a bracketed target keeps its spaces and fenced and inline example links are skipped ok"
else fail "a bracketed target or an example link was read as a link (exit $x)"; fi

# A rename entry in a tree that holds both names reads the source, the file the release publishes under the
# destination name; the destination file's own links are not in the tree the release builds. Both dead-link
# directions show which file is read. The source is staged as a commit would make it tracked.
printf '# Private changes\n\n[gone](docs/gone.md)\n' > "$repo/CHANGELOG.md"
printf '# Public changes\n\n[guide](docs/manual.md)\n' > "$repo/CHANGELOG.public.md"
git -C "$repo" add CHANGELOG.public.md
printf 'RELEASE_PATHS=("README.md" "docs" "CHANGELOG.public.md=CHANGELOG.md")\n' >> "$conf"
x=0; out=$(bash "$check" --project "$slug" --tree "$repo" 2>&1) || x=$?
if [ "$x" = 0 ] && grep -q '^link-check: 0 problems:' <<< "$out"; then
  echo "a rename entry reads the source and ignores a dead link in the destination file ok"
else fail "the destination CHANGELOG.md was read as the shipped file (exit $x)"; fi
printf '# Public changes\n\n[gone](docs/gone.md)\n' > "$repo/CHANGELOG.public.md"
x=0; out=$(bash "$check" --project "$slug" --tree "$repo" 2>&1) || x=$?
if [ "$x" = 1 ] && grep -qx 'link-check: CHANGELOG.md:3: docs/gone.md does not ship (a 404 on the public repository)' <<< "$out"; then
  echo "a dead link in the renamed source fails in a tree that holds both names ok"
else fail "a dead link in CHANGELOG.public.md passed (exit $x)"; fi
printf '# Public changes\n\n[guide](docs/manual.md)\n' > "$repo/CHANGELOG.public.md"
x=0; out=$(bash "$check" --project "$slug" --tree "$repo" 2>&1) || x=$?
if [ "$x" = 0 ] && grep -q '^link-check: 0 problems:' <<< "$out"; then
  echo "the same tree with the dead link removed passes ok"
else fail "removing the dead link from CHANGELOG.public.md did not pass (exit $x)"; fi

# An installed package directory is not part of a release. A checkout ships its tracked files, so an untracked
# `node_modules` inside a shipped directory entry is skipped; a staged copy has no index and skips it by name. A
# vendored README links files its own package does not publish, so walking the directory fails a healthy tree.
printf 'RELEASE_PATHS=("README.md" "docs" ".opencode")\n' >> "$conf"
mkdir -p "$repo/.opencode/node_modules/vendor"
printf '# Vendor\n\n[gone](docs/missing.md)\n' > "$repo/.opencode/node_modules/vendor/README.md"
printf '# Tool notes\n' > "$repo/.opencode/README.md"
git -C "$repo" add .opencode/README.md
x=0; out=$(bash "$check" --project "$slug" --tree "$repo" 2>&1) || x=$?
if [ "$x" = 0 ] && grep -q '^link-check: 0 problems:' <<< "$out"; then
  echo "an untracked node_modules README in a shipped directory is skipped in a checkout ok"
else fail "an untracked node_modules README was scanned in a checkout (exit $x)"; fi
printf 'RELEASE_PATHS=(".opencode")\n' >> "$conf"
nmstage="$repo/stage-node-modules"
mkdir -p "$nmstage/.opencode/node_modules/vendor"
printf '# Vendor\n\n[gone](docs/missing.md)\n' > "$nmstage/.opencode/node_modules/vendor/README.md"
printf '# Tool notes\n' > "$nmstage/.opencode/README.md"
x=0; out=$(bash "$check" --project "$slug" --tree "$nmstage" 2>&1) || x=$?
if [ "$x" = 0 ] && grep -qx 'link-check: 0 problems: 1 shipped files, 0 relative links in 1 Markdown files' <<< "$out"; then
  echo "a staged copy skips a node_modules README and ships only the file beside it ok"
else fail "a staged copy scanned node_modules (exit $x)"; fi

# A release publishes the tracked set, so a named file it does not track is reported rather than checked as if it
# would go public, and a tracked file missing from the checkout is reported rather than read as one with no links.
printf 'RELEASE_PATHS=("README.md" "untracked.md")\n' >> "$conf"
printf '# Not shipped\n' > "$repo/untracked.md"
x=0; out=$(bash "$check" --project "$slug" --tree "$repo" 2>&1) || x=$?
if [ "$x" = 1 ] && grep -qx 'link-check: RELEASE_PATHS names untracked.md, which is not tracked in the tree' <<< "$out"; then
  echo "a RELEASE_PATHS file the index does not track is reported ok"
else fail "a named untracked file was checked as if it would ship (exit $x)"; fi
printf 'RELEASE_PATHS=("README.md" "docs")\n' >> "$conf"
rm "$repo/docs/manual.md"
x=0; out=$(bash "$check" --project "$slug" --tree "$repo" 2>&1) || x=$?
if [ "$x" = 1 ] && grep -qx 'link-check: docs/manual.md: tracked but missing from the checkout' <<< "$out"; then
  echo "a tracked file missing from the checkout is reported ok"
else fail "a tracked file missing from the checkout was skipped (exit $x)"; fi

# A RELEASE_PATHS directory entry that holds no file is a problem of its own in a checkout: the release would publish
# a directory name with nothing under it, and a link to it would 404.
printf 'RELEASE_PATHS=("README.md" "empty")\n' >> "$conf"
mkdir -p "$repo/empty"
x=0; out=$(bash "$check" --project "$slug" --tree "$repo" 2>&1) || x=$?
if [ "$x" = 1 ] && grep -qx 'link-check: RELEASE_PATHS names empty, which holds no file to ship' <<< "$out"; then
  echo "a RELEASE_PATHS directory entry that ships no file is reported ok"
else fail "an empty RELEASE_PATHS directory entry was not reported (exit $x)"; fi

# The workspace's own published tree, when a project conf describes this repository: the same set a release would
# publish, read from this checkout, so a dead link in the tool's own documents fails here before a release does.
# A public copy has no projects/*.conf and prints the skip line instead.
own=""
own_common=$(git -C "$WS" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || own_common=""
for c in "$WS"/projects/*.conf; do
  [ -f "$c" ] || continue
  p=$( (PROJECT_PATH=""; . "$c" >/dev/null 2>&1; printf '%s' "${PROJECT_PATH:-}") )
  [ -n "$p" ] || continue
  pc=$(git -C "$p" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || continue
  [ -n "$pc" ] && [ "$pc" = "$own_common" ] && { own=$(basename "$c" .conf); break; }
done
if [ -n "$own" ]; then
  x=0; out=$(bash "$check" --project "$own" --tree "$WS" 2>&1) || x=$?
  if [ "$x" = 0 ] && grep -q '^link-check: 0 problems:' <<< "$out"; then
    summary=$(grep '^link-check: ' <<< "$out")
    echo "this repository's own RELEASE_PATHS resolve in this checkout ($summary) ok"
  else fail "the workspace's own RELEASE_PATHS do not resolve (exit $x)"; fi
  # The same set staged as the release would publish it, under the renamed names, so the links are checked on
  # exactly the files that would go public.
  stage="$repo/stage-public"
  staged=0
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    src="${entry%%=*}" dest="${entry#*=}"
    mkdir -p "$stage/$(dirname "$dest")" && cp -R "$WS/$src" "$stage/$dest" || { fail "could not stage $src"; break; }
    # An installed package tree never ships (link-check skips it by name), so copying it only makes the staged tree
    # large and the check slower.
    find "$stage/$dest" -type d -name node_modules -prune -exec rm -rf {} + 2>/dev/null || true
    staged=$((staged + 1))
  done < <( (RELEASE_PATHS=(); . "$WS/projects/$own.conf"; printf '%s\n' "${RELEASE_PATHS[@]}") )
  if [ "$staged" -gt 0 ]; then
    x=0; out=$(bash "$check" --project "$own" --tree "$stage" 2>&1) || x=$?
    docs=$(cd "$stage" && find docs -maxdepth 1 -name '*.md' 2>/dev/null | sed 's|.*/||' | LC_ALL=C sort | paste -sd' ' || true)
    if [ "$x" = 0 ] && grep -q '^link-check: 0 problems:' <<< "$out"; then
      echo "a staged copy of this repository's RELEASE_PATHS ($staged entries) checks clean, docs: $docs ok"
    else fail "the staged copy of this repository's RELEASE_PATHS does not check clean (exit $x)"; fi
  fi
else
  echo "no project conf points at this repository; the workspace's own link check is skipped"
fi

[ "$rc" = 0 ]
