#!/usr/bin/env python3
"""Report claim sentences added in a branch diff, for the reviewer prompt.

Reads the added prose and comment lines in a branch diff and prints, at most 20,
the sentences that make a claim about behaviour (only, every, always, never,
all, must, cannot, regardless, except) as ``<file>:<line>: <sentence>``, each
line cut at 200 characters. The reviewer checks each against the code that does
it; this is an input, not a verdict.

Test files and ``.ws-evidence/`` are skipped: a claim there is about a test or a
log, not the product. The branch diff is scanned rather than the tip file, so a
sentence already in the base is not reported again on every branch.
"""
import argparse
import ast
import fnmatch
import io
import re
import subprocess
import sys
import tokenize

DEFAULT_TEST_GLOBS = (
    "*.test.*", "*.spec.*", "test/*", "tests/*", "*/test/*", "*/tests/*",
    "__tests__/*", "*/__tests__/*", "test_*.py", "*_test.py", "*_test.go",
)
PROSE_SUFFIXES = (".md", ".markdown", ".rst", ".txt")
PY_SUFFIXES = (".py",)
C_COMMENT_SUFFIXES = (
    ".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs", ".c", ".h", ".cc", ".cpp",
    ".hpp", ".go", ".java", ".kt", ".rs", ".css", ".scss", ".sass", ".less",
    ".html", ".htm", ".vue", ".svelte", ".php", ".cs", ".swift", ".m", ".mm",
)
CLAIM_WORD = re.compile(
    r"\b(?:only|every|always|never|all|must|cannot|regardless|except)\b",
    re.I,
)
SENTENCE_END = re.compile(r"(?<=[.!?])\s+")
TRAILING_SLASH_COMMENT = re.compile(r"(?<![:/])//(.*)$")
CAP = 20
MAX_LINE = 200


def git(repo, *args):
    done = subprocess.run(
        ["git", "-C", repo, *args], capture_output=True, text=True
    )
    if done.returncode != 0:
        raise SystemExit(
            "claims: git %s failed: %s" % (" ".join(args), done.stderr.strip())
        )
    return done.stdout


def changed_files(repo, base, tip):
    rows = []
    for line in git(repo, "diff", "--name-status", "--no-renames", base, tip).splitlines():
        fields = line.split("\t")
        if len(fields) >= 2:
            rows.append((fields[0][:1], fields[-1]))
    return rows


def is_test(path, globs):
    return any(fnmatch.fnmatch(path, pattern) for pattern in globs)


def added_lines(repo, base, tip, path):
    text = git(repo, "diff", "-U0", base, tip, "--", path)
    rows = []
    newline = 0
    for line in text.splitlines():
        match = re.match(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", line)
        if match:
            newline = int(match.group(1))
            continue
        if line.startswith("+") and not line.startswith("+++"):
            rows.append((newline, line[1:]))
            newline += 1
        elif line.startswith("-") or line.startswith("\\"):
            continue
        elif line.startswith(" "):
            newline += 1
    return rows


def file_at(repo, rev, path):
    done = subprocess.run(
        ["git", "-C", repo, "show", "%s:%s" % (rev, path)],
        capture_output=True, text=True,
    )
    return done.stdout if done.returncode == 0 else ""


def python_docstring_lines(text):
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return set()
    lines = set()
    for node in ast.walk(tree):
        if not isinstance(
            node, (ast.Module, ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)
        ):
            continue
        body = getattr(node, "body", None)
        if not body:
            continue
        first = body[0]
        if not (
            isinstance(first, ast.Expr)
            and isinstance(first.value, ast.Constant)
            and isinstance(first.value.value, str)
        ):
            continue
        end = getattr(first, "end_lineno", first.lineno)
        lines.update(range(first.lineno, end + 1))
    return lines


def python_comment_lines(text):
    lines = set()
    try:
        tokens = tokenize.generate_tokens(io.StringIO(text).readline)
        for token in tokens:
            if token.type == tokenize.COMMENT:
                lines.add(token.start[0])
    except (tokenize.TokenError, IndentationError, SyntaxError):
        pass
    return lines


def c_comment_lines(text):
    lines = set()
    in_block = False
    in_string = None
    escaped = False
    for number, line in enumerate(text.splitlines(), 1):
        position = 0
        has_comment = in_block
        while position < len(line):
            char = line[position]
            if in_block:
                has_comment = True
                if line.startswith("*/", position):
                    in_block = False
                    position += 2
                    continue
                position += 1
                continue
            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == in_string:
                    in_string = None
                position += 1
                continue
            if char in "\"'`":
                in_string = char
                position += 1
                continue
            if line.startswith("//", position):
                has_comment = True
                break
            if line.startswith("/*", position):
                in_block = True
                has_comment = True
                position += 2
                continue
            position += 1
        if has_comment:
            lines.add(number)
    return lines


def comment_fragment(path, line, number, docstrings, c_comments):
    if path.endswith(PROSE_SUFFIXES):
        return line.strip()
    if path.endswith(PY_SUFFIXES):
        if number in docstrings:
            return line.strip().strip('"').strip("'").strip()
        if number not in c_comments:
            return ""
        return whole_line_hash(line)
    if path.endswith(C_COMMENT_SUFFIXES):
        if number not in c_comments:
            return ""
        stripped = line.strip()
        if stripped.startswith("//"):
            return stripped[2:].strip()
        if stripped.startswith("/*"):
            stripped = stripped[2:]
        elif stripped.startswith("*"):
            stripped = stripped[1:]
        if stripped.endswith("*/"):
            stripped = stripped[:-2]
        trailing = TRAILING_SLASH_COMMENT.search(line)
        if trailing and not line.strip().startswith("//"):
            return trailing.group(1).strip()
        return stripped.strip()
    return whole_line_hash(line)


def whole_line_hash(line):
    """The text after `#` only when `#` starts the line, so a `#` inside a quoted string is not comment prose."""
    stripped = line.lstrip()
    if not stripped.startswith("#"):
        return ""
    return stripped[1:].strip()


def sentences(text):
    collapsed = " ".join(text.split())
    return [part.strip() for part in SENTENCE_END.split(collapsed) if part.strip()]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--base", required=True)
    parser.add_argument("--tip", required=True)
    parser.add_argument("--test-glob", action="append", default=[])
    args = parser.parse_args()
    globs = tuple(args.test_glob) or DEFAULT_TEST_GLOBS

    found = []
    for status, path in changed_files(args.repo, args.base, args.tip):
        if status not in "AM":
            continue
        if path == ".ws-evidence" or path.startswith(".ws-evidence/") \
                or "/.ws-evidence/" in path:
            continue
        if is_test(path, globs):
            continue
        text = file_at(args.repo, args.tip, path)
        docstrings = python_docstring_lines(text) if path.endswith(PY_SUFFIXES) else set()
        if path.endswith(PY_SUFFIXES):
            c_comments = python_comment_lines(text)
        elif path.endswith(C_COMMENT_SUFFIXES):
            c_comments = c_comment_lines(text)
        else:
            c_comments = set()
        for number, line in added_lines(args.repo, args.base, args.tip, path):
            fragment = comment_fragment(path, line, number, docstrings, c_comments)
            if not fragment:
                continue
            for sentence in sentences(fragment):
                if not CLAIM_WORD.search(sentence):
                    continue
                rendered = "%s:%d: %s" % (path, number, sentence)
                found.append(rendered[:MAX_LINE])
                if len(found) >= CAP:
                    break
            if len(found) >= CAP:
                break
        if len(found) >= CAP:
            break

    if not found:
        print("none")
        return 0
    for rendered in found:
        print(rendered)
    return 0


if __name__ == "__main__":
    sys.exit(main())
