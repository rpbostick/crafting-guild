#!/usr/bin/env python3
"""Repair commit references after a history rewrite, and verify the repair.

`git filter-repo` writes `commit-map` files (old full SHA, new full SHA). Plans, runs, reports and
docs quote abbreviated SHAs, so a rewrite leaves thousands of dangling references. This script
maps each old SHA (and every abbreviation of it) to the new one, keeping the reference length.

Usage:
  sha-repair.py --map DIR_OR_FILE [--map ...] [--root DIR] [--repo DIR]
                [--apply] [--log FILE] [--verify] [--quiet]

  --map      a filter-repo `commit-map` file or a directory of them (e.g. runs/email-rewrite/*)
  --root     the tree to scan and rewrite (default: the workspace)
  --repo     the repository a map belongs to, for --verify (default: from the map's parent dir)
  --apply    write the replacements (default: a dry run that prints the counts)
  --verify   check that no old SHA remains and that the new full SHAs resolve in --repo
  --log      append every replacement as `old<TAB>new<TAB>file` for the audit trail
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

SHA = re.compile(r"\b[0-9a-f]{7,40}\b")
SKIP_DIRS = {".git", "node_modules", ".venv", "vendor", "dist", "build", ".expo", ".wrangler"}
SKIP_SUFFIX = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".pdf", ".zip", ".gz", ".tgz", ".tar",
               ".woff", ".woff2", ".ttf", ".otf", ".mp4", ".webm", ".wasm", ".bin", ".obj", ".stl",
               ".glb", ".gltf", ".ico", ".svgz", ".patch"}


def read_map(path: Path) -> dict[str, str]:
    pairs: dict[str, str] = {}
    for line in path.read_text(errors="replace").splitlines():
        parts = line.split()
        if len(parts) != 2:
            continue
        old, new = parts
        if re.fullmatch(r"[0-9a-f]{40}", old) and re.fullmatch(r"[0-9a-f]{40}", new):
            pairs[old] = new
    return pairs


def collect_map_paths(items: list[str]) -> list[Path]:
    out: list[Path] = []
    for item in items:
        p = Path(item)
        if p.is_dir():
            out.extend(sorted(p.rglob("commit-map")))
        elif p.is_file():
            out.append(p)
        else:
            raise SystemExit(f"sha-repair: no map at {item}")
    if not out:
        raise SystemExit("sha-repair: no commit-map files found")
    return out


def prefix_index(maps: dict[str, str]) -> tuple[dict[str, str], set[str]]:
    """Every prefix of every old SHA (7..40) -> new SHA; ambiguous prefixes are dropped."""
    index: dict[str, str] = {}
    ambiguous: set[str] = set()
    for old, new in maps.items():
        for length in range(7, 41):
            key = old[:length]
            seen = index.get(key)
            if seen is not None and seen != new:
                ambiguous.add(key)
            else:
                index[key] = new
    for key in ambiguous:
        index.pop(key, None)
    return index, ambiguous


def iter_text_files(root: Path, exclude: tuple[str, ...] = ()):
    from fnmatch import fnmatch
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            p = Path(dirpath) / name
            if p.suffix.lower() in SKIP_SUFFIX or name in {"commit-map"} or name.endswith(".map"):
                continue
            if any(fnmatch(name, pat) or fnmatch(str(p), pat) for pat in exclude):
                continue
            try:
                if p.stat().st_size > 8 * 1024 * 1024:
                    continue
                with p.open("rb") as fh:
                    if b"\0" in fh.read(4096):
                        continue
            except OSError:
                continue
            yield p


def file_slug(path: Path, root: Path) -> str | None:
    """`plans/<slug>/...` and `runs/<slug>/...` name the project a reference belongs to."""
    try:
        parts = path.resolve().relative_to(root.resolve()).parts
    except ValueError:
        return None
    return parts[1] if len(parts) >= 3 and parts[0] in {"plans", "runs"} else None


def rewrite_file(path: Path, index: dict[str, str], apply: bool, log, named_index: dict[str, dict[str, str]] | None = None, slug: str | None = None) -> tuple[int, list[tuple[str, str]]]:
    try:
        text = path.read_text(errors="surrogateescape")
    except OSError:
        return 0, []
    changes: list[tuple[str, str]] = []

    def repl(match: re.Match[str]) -> str:
        token = match.group(0)
        new = index.get(token)
        if new is None and slug is not None and named_index and slug in named_index:
            new = named_index[slug].get(token)
        if new is None or new.startswith(token):
            return token
        replacement = new[: len(token)]
        changes.append((token, replacement))
        return replacement

    new_text = SHA.sub(repl, text)
    if changes and apply:
        path.write_text(new_text, errors="surrogateescape")
        if log:
            for old, new in changes:
                log.write(f"{old}\t{new}\t{path}\n")
    return len(changes), changes


def resolve(repo: Path, sha: str) -> bool:
    return subprocess.run(["git", "-C", str(repo), "cat-file", "-e", f"{sha}^{{commit}}"],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--map", action="append", required=True)
    ap.add_argument("--root", default=None)
    ap.add_argument("--repo", default=None)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--log", default=None)
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("--exclude", action="append", default=[], help="glob of files to leave alone (default: the repair logs)")
    args = ap.parse_args()
    ws = Path(os.environ.get("WS") or Path(__file__).resolve().parent.parent)
    root = Path(args.root or ws).resolve()
    repo = Path(args.repo).resolve() if args.repo else None
    map_paths = collect_map_paths(args.map)
    maps: dict[str, str] = {}
    named: dict[str, dict[str, str]] = {}
    for p in map_paths:
        one = read_map(p)
        maps.update(one)
        named[p.parent.name] = one
    if not maps:
        raise SystemExit("sha-repair: the maps have no old/new SHA pairs")
    index, ambiguous = prefix_index(maps)
    named_index = {name: prefix_index(one)[0] for name, one in named.items()}
    if args.verify:
        bad_old: list[tuple[Path, str]] = []
        for p in iter_text_files(root, tuple(args.exclude) or ("repair.log", "*.repair.log")):
            try:
                text = p.read_text(errors="replace")
            except OSError:
                continue
            for token in SHA.findall(text):
                new = index.get(token)
                if new is None:
                    continue
                # A new SHA that begins with the old abbreviation leaves a valid reference: it resolves in
                # the rewritten history. Only a token that is neither a prefix of the new SHA nor a commit
                # in the repository is broken.
                if new.startswith(token):
                    continue
                if repo is not None and resolve(repo, token):
                    continue
                bad_old.append((p, token))
        unresolved: list[str] = []
        if repo is not None:
            for new in set(maps.values()):
                if not resolve(repo, new):
                    unresolved.append(new)
        if bad_old or unresolved:
            for p, token in bad_old[:20]:
                print(f"FAIL  old SHA {token} remains in {p}")
            for new in unresolved[:10]:
                print(f"FAIL  new SHA {new} does not resolve in {repo}")
            return 1
        if not args.quiet:
            print(f"ok    no old SHA remains under {root}; the {len(set(maps.values()))} new SHAs resolve in {repo}")
        return 0

    log = open(args.log, "a", encoding="utf-8") if args.log else None
    total = 0
    files = 0
    examples: list[tuple[Path, str, str]] = []
    try:
        for p in iter_text_files(root, tuple(args.exclude) or ("repair.log", "*.repair.log")):
            n, changes = rewrite_file(p, index, args.apply, log, named_index, file_slug(p, root))
            if n:
                total += n
                files += 1
                if len(examples) < 8:
                    examples.append((p, changes[0][0], changes[0][1]))
    finally:
        if log:
            log.close()
    verb = "rewrote" if args.apply else "would rewrite"
    print(f"{verb} {total} reference(s) in {files} file(s) under {root}"
          + (f" ({len(ambiguous)} ambiguous prefixes skipped)" if ambiguous else ""))
    for p, old, new in examples:
        print(f"  {p}: {old} -> {new}")
    if not args.apply:
        print("dry run: pass --apply to write; run --verify afterwards")
    return 0


if __name__ == "__main__":
    sys.exit(main())
