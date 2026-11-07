#!/usr/bin/env python3
"""Report test-quality candidates in a branch diff for the reviewer prompt.

Reads the added test files in a branch diff and prints one line per candidate a
deterministic check can see: a bare lower-bound assertion, a test with no
assertion, a test that never names the changed production path, a duplicate
test, and a new test file with no failing-before run on record. The reviewer
judges each line; this is an input, not a verdict.

The check stays quiet when it cannot judge: a branch that changes no added or
changed test file prints one ok line.
"""
import argparse
import fnmatch
import os
import re
import subprocess
import sys

DEFAULT_TEST_GLOBS = (
    "*.test.*", "*.spec.*", "test/*", "tests/*", "*/test/*", "*/tests/*",
    "__tests__/*", "*/__tests__/*", "test_*.py", "*_test.py", "*_test.go",
)
CODE_SUFFIXES = (
    ".sh", ".bash", ".py", ".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs",
    ".go", ".rb", ".rs", ".java", ".kt", ".c", ".h", ".cc", ".cpp", ".css",
    ".html",
)
JS_SUFFIXES = (".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs")
TEST_CALL = re.compile(r"\b(?:test|it|specify)\s*\(\s*(['\"`])(.*?)\1", re.S)
PY_TEST = re.compile(r"^(\s*)(?:async\s+)?def\s+(test\w*)\s*\(")
GO_TEST = re.compile(r"^func\s+(Test\w+)\s*\(")

BARE_BOUND = (
    re.compile(r"toBeGreaterThan(?:OrEqual)?\(\s*(?:0|1)\s*\)"),
    re.compile(r"not\.toHaveLength\(\s*0\s*\)"),
    re.compile(r"assert\w*\([^)]*(?:len|length|size|count)[^)]*(?:>|>=)\s*(?:0|1)\b"),
    re.compile(r"assertTrue\(\s*(?:len|.*\.length)"),
    re.compile(r"\[\s*[^\]]+\s+(?:-gt|-ge)\s+(?:0|1)\s*\]"),
    re.compile(r"(?:^|[^=!<>])>=\s*1\b"),
    re.compile(r"(?:^|[^=!<>])>\s*0\b"),
)
TAUTOLOGY = (
    re.compile(r"expect\s*\(\s*(?:true|1)\s*\)\s*\.\s*toBe\s*\(\s*(?:true|1)\s*\)"),
    re.compile(r"^\s*assert\s+(?:True|1)\s*$"),
    re.compile(r"assertEqual\s*\(\s*(\d+)\s*,\s*\1\s*\)"),
    re.compile(r"\[\s*(\d+)\s+=\s+\1\s*\]"),
)
ASSERTION = re.compile(
    r"\b(?:assert|expect|should|t\.(?:Error|Fatal|Errorf|Fatalf|Equal|True|False))"
    r"|\[\s*[^\]]+\s+(?:-eq|-ne|-gt|-ge|-lt|-le|=|!=)\s"
    r"|grep\s+-q|exit\s+[1-9]|throw\s+new\s+Error"
)
IDENTIFIER = (
    re.compile(r"^\s*(?:export\s+)?(?:async\s+)?function\s+([A-Za-z_]\w*)"),
    re.compile(r"^\s*(?:export\s+)?(?:const|let|var|class)\s+([A-Za-z_]\w*)"),
    re.compile(r"^\s*(?:async\s+)?def\s+([A-Za-z_]\w*)"),
    re.compile(r"^\s*func\s+(?:\([^)]*\)\s*)?([A-Za-z_]\w*)"),
    re.compile(r"^\s*([A-Za-z_]\w*)\s*\(\)\s*\{"),
)
STOPWORDS = {
    "main", "test", "tests", "data", "value", "values", "index", "init",
    "true", "false", "none", "null", "self", "this", "bash", "echo", "exit",
    "return", "const", "class", "function", "string", "number", "object",
    "export", "import", "default", "result", "results", "error", "errors",
    "local", "readonly", "declare", "module", "exports", "require",
}


def git(repo, *args):
    done = subprocess.run(
        ["git", "-C", repo, *args], capture_output=True, text=True
    )
    if done.returncode != 0:
        raise SystemExit(
            "test-quality: git %s failed: %s"
            % (" ".join(args), done.stderr.strip())
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


def normalize_test_path(path):
    while path.startswith("./"):
        path = path[2:]
    return path


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


def js_units(text):
    units = []
    for match in TEST_CALL.finditer(text):
        brace = text.find("{", match.end())
        if brace < 0:
            continue
        depth = 0
        quote = None
        escaped = False
        position = brace
        while position < len(text):
            char = text[position]
            if quote:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = None
            elif char in "'\"`":
                quote = char
            elif char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    units.append({
                        "name": match.group(2),
                        "line": text.count("\n", 0, match.start()) + 1,
                        "body": text[brace + 1:position],
                    })
                    break
            position += 1
    return units


def py_units(text):
    lines = text.splitlines()
    units = []
    index = 0
    while index < len(lines):
        match = PY_TEST.match(lines[index])
        if not match:
            index += 1
            continue
        indent = len(match.group(1))
        body = []
        cursor = index + 1
        while cursor < len(lines):
            line = lines[cursor]
            stripped = line.strip()
            if stripped and len(line) - len(line.lstrip()) <= indent:
                break
            body.append(line)
            cursor += 1
        units.append({
            "name": match.group(2),
            "line": index + 1,
            "body": "\n".join(body),
        })
        index = cursor
    return units


def go_units(text):
    units = []
    for match in GO_TEST.finditer(text):
        brace = text.find("{", match.end())
        if brace < 0:
            continue
        depth = 0
        position = brace
        while position < len(text):
            if text[position] == "{":
                depth += 1
            elif text[position] == "}":
                depth -= 1
                if depth == 0:
                    units.append({
                        "name": match.group(1),
                        "line": text.count("\n", 0, match.start()) + 1,
                        "body": text[brace + 1:position],
                    })
                    break
            position += 1
    return units


def units_for(path, text):
    if path.endswith(JS_SUFFIXES):
        return js_units(text)
    if path.endswith(".py"):
        return py_units(text)
    if path.endswith(".go"):
        return go_units(text)
    return None


def normalize(body):
    return re.sub(r"\s+", " ", body).strip()


def identifiers(repo, base, tip, path):
    names = set()
    stem = os.path.splitext(os.path.basename(path))[0]
    for candidate in (stem, stem.replace("-", "_"), stem.replace("_", "-")):
        if len(candidate) >= 4 and candidate.lower() not in STOPWORDS:
            names.add(candidate.lower())
    for part in re.split(r"[-_.]", stem):
        if len(part) >= 4 and part.lower() not in STOPWORDS:
            names.add(part.lower())
    for _line, text in added_lines(repo, base, tip, path):
        for pattern in IDENTIFIER:
            match = pattern.match(text)
            if match:
                name = match.group(1)
                if len(name) >= 4 and name.lower() not in STOPWORDS:
                    names.add(name.lower())
    return names


def bare_bound(text):
    for pattern in BARE_BOUND:
        if pattern.search(text):
            return True
    return False


def tautology(text):
    return any(pattern.search(text) for pattern in TAUTOLOGY)


def mentions_any(text, names):
    lowered = text.lower()
    for name in names:
        if re.search(r"(?<![a-z0-9_])%s(?![a-z0-9_])" % re.escape(name), lowered):
            return True
    return False


FILE_WORD = re.compile(
    r"(?<![\w-])[\w./-]+\.(?:sh|bash|py|js|jsx|ts|tsx|mjs|cjs|go|rb|rs|java|kt|c|h|cc|cpp)\b"
)


def names_a_file(command):
    return bool(FILE_WORD.search(command))


def runs_rows(path):
    rows = []
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = [line.rstrip("\n") for line in handle]
    except OSError:
        return rows
    for line in lines[1:]:
        fields = line.split("\t")
        if len(fields) >= 5:
            rows.append(fields)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--base", required=True)
    parser.add_argument("--tip", required=True)
    parser.add_argument("--worktree", required=True)
    parser.add_argument("--test-glob", action="append", default=[])
    parser.add_argument("--test-file", action="append", default=[])
    args = parser.parse_args()
    globs = tuple(args.test_glob) or DEFAULT_TEST_GLOBS
    extra_tests = {normalize_test_path(path) for path in args.test_file}

    rows = changed_files(args.repo, args.base, args.tip)
    tests = [(status, path) for status, path in rows
             if status in "AM" and (is_test(path, globs) or path in extra_tests)]
    # A file named as the test command is a test file even when its name matches no test glob, so it must not
    # contribute production keywords: its own added lines would otherwise always name themselves.
    code = [path for status, path in rows
            if status in "AMR" and not is_test(path, globs) and path not in extra_tests
            and path.endswith(CODE_SUFFIXES)]
    if not tests:
        print("ok    rule 2: no added or changed test file to judge")
        return 0

    flags = []
    added_by_file = {}
    units_by_file = {}
    for _status, path in tests:
        added_by_file[path] = added_lines(args.repo, args.base, args.tip, path)
        text = file_at(args.repo, args.tip, path)
        units = units_for(path, text)
        if units is None:
            units = []
            for line, value in added_by_file[path]:
                if value.strip():
                    units.append({"name": "", "line": line, "body": value})
        units_by_file[path] = units

    # A bare lower bound and a tautology are visible line by line.
    for path, lines in added_by_file.items():
        for line, text in lines:
            if bare_bound(text):
                flags.append(
                    "%s:%d: bare lower-bound assertion `%s`; an exact count or "
                    "set is known, so it passes on any non-empty result"
                    % (path, line, text.strip()[:100])
                )
            if tautology(text):
                flags.append(
                    "%s:%d: tautological assertion `%s` cannot fail"
                    % (path, line, text.strip()[:100])
                )

    # A declared test with no assertion cannot fail.
    for path, units in units_by_file.items():
        for unit in units:
            if not unit["name"] or not unit["body"].strip():
                continue
            if not ASSERTION.search(unit["body"]):
                flags.append(
                    "%s:%d: test `%s` has no assertion; it cannot fail"
                    % (path, unit["line"], unit["name"])
                )

    # Two added tests with the same body, or a test name that already exists.
    seen = {}
    for path, units in units_by_file.items():
        base_text = file_at(args.repo, args.base, path)
        base_names = {unit["name"] for unit in (units_for(path, base_text) or [])}
        for unit in units:
            if not unit["name"]:
                continue
            if unit["name"] in base_names:
                flags.append(
                    "%s:%d: test `%s` repeats a name already in the file"
                    % (path, unit["line"], unit["name"])
                )
            body = normalize(unit["body"])
            if not body:
                continue
            key = body
            if key in seen:
                flags.append(
                    "%s:%d: test `%s` duplicates %s:%d"
                    % (path, unit["line"], unit["name"], seen[key][0], seen[key][1])
                )
            else:
                seen[key] = (path, unit["line"])

    # A test file whose added lines name no changed production path.
    keywords = set()
    for path in code:
        keywords |= identifiers(args.repo, args.base, args.tip, path)
    if code and keywords and len(code) <= 5:
        for _status, path in tests:
            lines = added_by_file[path]
            if not lines:
                continue
            text = "\n".join(value for _line, value in lines)
            if not mentions_any(text, keywords):
                flags.append(
                    "%s:%d: the added tests name none of the changed production "
                    "paths (%s); check they exercise them"
                    % (path, lines[0][0], ", ".join(sorted(code)[:4]))
                )

    # A new or changed test with no failing-before run on record.
    tsv = os.path.join(args.worktree, ".ws-evidence", "runs.tsv")
    rows = runs_rows(tsv)
    if not os.path.exists(tsv):
        print("ok    rule 2: no .ws-evidence/runs.tsv, so failing-before evidence was not judged")
    elif not rows:
        print("ok    rule 2: .ws-evidence/runs.tsv has no runs, so failing-before evidence was not judged")
    else:
        failed_commands = [row for row in rows if row[2] not in ("0", "")]
        # A whole-suite runner (`pytest`, `npm test`) names no test file, so its non-zero exit is the only
        # evidence it can give. A command that names a file counts only when the file is one of these tests.
        test_names = {os.path.basename(path).lower() for _s, path in tests}
        if not any(
            mentions_any(row[4], test_names) or not names_a_file(row[4])
            for row in failed_commands
        ):
            names = ", ".join(path for _status, path in tests[:4])
            flags.append(
                "%s: new or changed tests have no failing-before run in "
                ".ws-evidence/runs.tsv" % names
            )

    for flag in flags:
        print("FLAG  rule 2: %s" % flag)
    if not flags:
        print("ok    rule 2: %d added or changed test file(s), no test-quality candidate" % len(tests))
    return 1 if flags else 0


if __name__ == "__main__":
    sys.exit(main())
