#!/usr/bin/env python3
"""Pairs each private lesson (lessons/<role>.local.md) with the shared lesson it restates.

Usage: lessons-check.py [lessons_dir] [--names a,b,...]
       lessons-check.py --removed <old_local.md> <new_local.md> <shared.md>

Both files load into every session, so a private bullet that restates a shared one is read twice. The first
form prints each private bullet's best shared pair with its similarity and reports the bullets with no shared
counterpart. It exits 1 when a bullet restates a shared one (similarity >= DUP) and adds nothing of its own:
no date or number the shared bullet lacks, no capitalised name in mid-sentence, no project name. Project
names are the slugs in <lessons_dir>/../projects/*.conf plus --names.

The --removed form checks a prune: each sentence of the old private file is shown with how many of its words
the best shared bullet and the best new private bullet hold between them; "CHECK" marks one under COVERED.
"""
import difflib, glob, os, re, sys

DUP = 0.6        # similarity at which a private bullet restates its shared pair
UNPAIRED = 0.3   # below this, and without matching opening words, a bullet has no shared counterpart
OPENING = 3      # leading words in common that pair two bullets on their own
COVERED = 0.8    # share of an old sentence's words a prune must keep somewhere


def bullets(path):
    out = []
    for n, line in enumerate(open(path), 1):
        if line.startswith("- "):
            out.append((n, line[2:].strip()))
        elif out and line.startswith("  ") and line.strip():
            out[-1] = (out[-1][0], out[-1][1] + " " + line.strip())
    return out


def words(text):
    return re.findall(r"[a-z0-9][a-z0-9'._/-]*[a-z0-9]|[a-z0-9]", text.lower())


def similarity(a, b):
    return difflib.SequenceMatcher(None, words(a), words(b), autojunk=False).ratio()


def opening(a, b):
    n = 0
    for x, y in zip(words(a), words(b)):
        if x != y:
            break
        n += 1
    return n


def pair(text, shared):
    """Opening words win over overlap: a cut-down private bullet keeps its shared pair's opening and little else."""
    scored = [(opening(text, s), similarity(text, s), n, s) for n, s in shared]
    by_opening = max(scored, key=lambda c: (c[0], c[1]))
    best = by_opening if by_opening[0] >= OPENING else max(scored, key=lambda c: c[1])
    return best


def specifics(text, shared_text, names):
    """What the private bullet adds: digits, mid-sentence capitalised words and project names the shared one lacks."""
    have = set(words(shared_text)) | set(re.findall(r"\S+", shared_text))
    found = [t for t in set(re.findall(r"[\w.:$×-]*\d[\w.:$×-]*", text)) if t.strip(".:-") not in have]
    for m in re.finditer(r"(?<![.!?:]\s)(?<!^)\b[A-Z][a-zA-Z]+", text):
        if m.group(0) not in shared_text:
            found.append(m.group(0))
    found += [w for w in set(words(text)) if w in names and w not in have]
    return sorted(set(found))


def project_names(lessons_dir, extra):
    confs = glob.glob(os.path.join(lessons_dir, "..", "projects", "*.conf"))
    return {os.path.basename(c)[:-5] for c in confs} | {n for n in extra if n}


def check(lessons_dir, names):
    failed = 0
    for local in sorted(glob.glob(os.path.join(lessons_dir, "*.local.md"))):
        shared_path = local[:-len(".local.md")] + ".md"
        if not os.path.exists(shared_path):
            print(f"{os.path.basename(local)}: no shared file {os.path.basename(shared_path)}")
            failed = 1
            continue
        shared = bullets(shared_path)
        print(f"== {os.path.basename(local)} against {os.path.basename(shared_path)}")
        for n, text in bullets(local):
            op, score, sn, stext = pair(text, shared) if shared else (0, 0.0, 0, "")
            head = " ".join(text.split()[:8])
            if op < OPENING and score < UNPAIRED:
                print(f"  L{n} own        {score:.2f}  {head}")
                continue
            adds = specifics(text, stext, names)
            verdict = "restates" if score >= DUP else "pairs"
            if score >= DUP and not adds:
                verdict = "DUPLICATE"
                failed = 1
            print(f"  L{n} ~ L{sn} {verdict:<9} {score:.2f} open={op}  {head}")
            print(f"        adds: {', '.join(adds) if adds else '(nothing)'}")
    if failed:
        print("lessons-check: a private lesson restates a shared one with nothing of its own (DUPLICATE above);"
              " cut it to its incident, date or project, or remove it")
    return failed


def sentences(path):
    out = []
    for n, text in bullets(path):
        out += [(n, s) for s in re.split(r"(?<=[.;])\s+(?=[A-Z(`\"])", text) if s.strip()]
    return out


def removed(old_path, new_path, shared_path):
    shared, new = bullets(shared_path), bullets(new_path)
    low = 0
    for n, sentence in sentences(old_path):
        want = set(words(sentence))
        if not want:
            continue
        def best(pool):
            return max(pool, key=lambda b: len(want & set(words(b[1]))), default=(0, ""))
        sn, stext = best(shared)
        nn, ntext = best(new)
        in_shared = len(want & set(words(stext))) / len(want)
        in_new = len(want & set(words(ntext))) / len(want)
        both = len(want & (set(words(stext)) | set(words(ntext)))) / len(want)
        mark = "ok   " if both >= COVERED else "CHECK"
        low += both < COVERED
        print(f"{mark} old L{n}: shared L{sn} {in_shared:.2f}, new L{nn} {in_new:.2f}, both {both:.2f}  {sentence}")
        if both < COVERED:
            print(f"        missing: {' '.join(sorted(want - set(words(stext)) - set(words(ntext))))}")
    print(f"{low} sentence(s) under {COVERED} coverage")
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["--removed"]:
        sys.exit(removed(*args[1:4]))
    extra = []
    if "--names" in args:
        i = args.index("--names")
        extra = args[i + 1].split(",")
        del args[i:i + 2]
    lessons_dir = args[0] if args else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lessons")
    sys.exit(check(lessons_dir, project_names(lessons_dir, extra)))
