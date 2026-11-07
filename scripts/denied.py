#!/usr/bin/env python3
"""Group denied builder commands by why they were denied.

`ws audit` used to count denied commands by their first word, which hides the reason:
`git -C elsewhere status`, the ungranted half of a chain and a read into another
checkout all read as "git". This module gives every entry one class, first match wins:

  tool-name        one bare agent tool name (`read`, `edit`, ...), counted apart from shell denials
  outside-worktree an absolute path or a `../` path outside the worktree
  git-dir-flag     `git -C`
  part-of-chain    a `|`, `&&`, `||`, `;` or `$(` chain with a part the defaults do not grant
  interpreter-eval `node -e`/`-p`, `python3 -c`, `bash -c` or a combined short option carrying eval
  write-form       a write or destructive form the DENY list catches
  never-granted    a single command the default read-only grants do not run
  other            anything left, with its text kept

For a chain the module also returns the first ungranted-looking part, so a report can
name the part that cost the turn rather than the whole line. The classes are a reading
aid, not a security boundary: the real deny stays in scripts/dispatch.sh and
scripts/opencode_run.py.

Usage: denied.py <denied-calls.tsv> [--class CLASS | --first-word]
"""
import collections
import os
import re
import sys

CLASSES = (
    "tool-name",
    "outside-worktree",
    "git-dir-flag",
    "part-of-chain",
    "interpreter-eval",
    "write-form",
    "never-granted",
    "other",
)

TOOL_NAMES = frozenset({
    "read", "edit", "write", "glob", "grep", "list",
    "task", "webfetch", "websearch", "todowrite",
})

# The first words of the default builder TOOLS in scripts/dispatch.sh. An interpreter is listed here and
# narrowed by granted_form: its bare name is not a grant.
GRANTED_WORDS = frozenset({
    "git", "stat", "sha256sum", "file", "ls", "cat", "grep", "wc", "head", "tail",
    "mkdir", "cp", "chmod", "expr", "date", "diff", "bash", "pwd", "find", "sed",
    "which", "sort", "test", "true", "sqlite3", "command", "jq", "echo",
    "printenv", "du", "python3", "opencode", "node", "npm",
})

INTERPRETERS = frozenset({"python", "python3", "node", "bash", "sh", "dash", "zsh", "perl", "ruby"})
# The code option each interpreter reads, and the letters a combined short option must carry to select it.
EVAL_OPTIONS = {
    "python": ("-c",), "python3": ("-c",),
    "node": ("-e", "--eval", "-p", "--print"),
    "bash": ("-c",), "sh": ("-c",), "dash": ("-c",), "zsh": ("-c",),
    "perl": ("-e", "-E"), "ruby": ("-e",),
}
EVAL_LETTERS = {
    "python": "c", "python3": "c", "node": "ep",
    "bash": "c", "sh": "c", "dash": "c", "zsh": "c",
    "perl": "eE", "ruby": "e",
}
# Standard devices are not a read into another checkout; a redirect to one is a write form at most.
DEVICES = frozenset({"/dev/null", "/dev/stdin", "/dev/stdout", "/dev/stderr"})

QUOTED = re.compile(r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\"|`(?:[^`\\]|\\.)*`")
ENV_ASSIGNMENT = re.compile(r"^(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)+")
REDIRECT = re.compile(r">{1,2}\s*(?!&)(?=[^\s])")
OUTSIDE_RELATIVE = re.compile(r"(?:^|[\s'\"=:(])\.\./")
RUN_SUFFIX = re.compile(r"\.\d{8}T\d{6}Z$")


def unquoted(text):
    """The text with quoted spans removed, so a pattern inside a quoted argument is not mistaken for shell syntax."""
    return QUOTED.sub(" ", text)


def words_of(part):
    """The words of one command part, with leading KEY=value assignments dropped."""
    return ENV_ASSIGNMENT.sub("", part.strip()).split()


def split_chain(command):
    """Split a command at the shell separators OpenCode checks one at a time, keeping quoted text whole."""
    parts, buf = [], []
    i, n = 0, len(command)
    quote = None
    while i < n:
        char = command[i]
        if quote:
            buf.append(char)
            if char == "\\" and quote == '"' and i + 1 < n:
                buf.append(command[i + 1])
                i += 2
                continue
            if char == quote:
                quote = None
            i += 1
            continue
        if char in "'\"`":
            quote = char
            buf.append(char)
            i += 1
            continue
        if char == "\\" and i + 1 < n:
            buf.append(char)
            buf.append(command[i + 1])
            i += 2
            continue
        if command.startswith("$(", i):
            parts.append("".join(buf))
            buf = []
            i += 2
            continue
        if command.startswith("&&", i) or command.startswith("||", i):
            parts.append("".join(buf))
            buf = []
            i += 2
            continue
        if char in "|;":
            parts.append("".join(buf))
            buf = []
            i += 1
            continue
        buf.append(char)
        i += 1
    parts.append("".join(buf))
    return [part.strip().rstrip(")").strip() for part in parts if part.strip().rstrip(")").strip()]


GIT_READ_SUBCOMMANDS = frozenset({
    "status", "diff", "log", "show", "rev-parse", "ls-files", "merge-base",
    "add", "commit", "restore", "rm", "mv", "ls-tree", "check-ignore", "grep",
})


def git_granted(words):
    """Whether a git command is one of the subcommands the default TOOLS grant."""
    if len(words) < 2:
        return False
    sub = words[1]
    rest = words[2:]
    if sub in GIT_READ_SUBCOMMANDS:
        return True
    if sub == "branch":
        if not rest:
            return False
        if rest[0] in ("-a", "--contains"):
            return True
        return rest[0] == "--list" or rest[0] == "--show-current"
    if sub == "worktree":
        return rest[:1] == ["list"]
    if sub == "clean":
        return rest[:2] == ["-f", "--"]
    if sub == "checkout":
        return rest[:1] == ["--"]
    if sub == "merge":
        return rest in (["main"], ["main", "--no-edit"])
    return False


def granted_form(words):
    """Whether an interpreter's first words are one of the forms the default grants."""
    base = os.path.basename(words[0])
    rest = words[1:]
    second = rest[0] if rest else ""
    third = rest[1] if len(rest) > 1 else ""
    if base in ("python", "python3"):
        return second == "--version" or (second == "-m" and third == "py_compile")
    if base in ("node", "npm", "opencode", "sqlite3"):
        return second == "--version"
    if base == "bash":
        return second in ("-n", "--version")
    return False


def granted(part):
    """Whether the default TOOLS run this command part (its writing and eval forms are checked apart)."""
    if interpreter_eval(part) or write_form(part):
        return False
    words = words_of(part)
    if not words:
        return False
    base = os.path.basename(words[0])
    if base == "ws-run":  # bin/ws-run, or the workspace path dispatch names in the prompt
        return True
    if base == "env":  # only the bare command prints the environment; `env <command>` runs one
        return len(words) == 1
    if base == "firefox":  # only the version check is a read-only form
        return words[1:2] == ["--version"]
    if base in INTERPRETERS:
        return granted_form(words)
    if base == "git":
        return git_granted(words)
    if base in TOOL_NAMES:
        return False
    return base in GRANTED_WORDS


def interpreter_eval(part):
    """Whether a part runs code through an interpreter's own -c/-e/-p option, or its bundles."""
    words = words_of(part)
    if not words:
        return False
    base = os.path.basename(words[0])
    if base == "eval":
        return True
    if base not in EVAL_OPTIONS:
        return False
    options = EVAL_OPTIONS[base]
    letters = EVAL_LETTERS[base]
    for word in words[1:]:
        if word == "--":
            continue
        if not word.startswith("-"):
            return False  # the script/module word ends the interpreter's own options
        for option in options:
            if word == option or (option.startswith("--") and word.startswith(option)):
                return True
        if not word.startswith("--") and len(word) > 1:
            bundle = word[1:]
            if any(letter in bundle for letter in letters):
                return True
    return False


def write_form(part):
    """Whether a part is a write or destructive form the DENY list catches."""
    words = words_of(part)
    if not words:
        return False
    base = os.path.basename(words[0])
    text = unquoted(part)
    if REDIRECT.search(text):
        return True
    if base in ("rm", "mv", "tee"):
        return True
    if base == "sed" and any(word == "-i" or word.startswith("-i") for word in words[1:]):
        return True
    if base == "sort" and any(word == "-o" or word.startswith("-o") for word in words[1:]):
        return True
    if base in ("curl", "wget") and any(
            word in ("-o", "-O") or (word.startswith("-") and not word.startswith("--") and "o" in word[1:].lower())
            for word in words[1:]):
        return True
    if base == "git":
        rest = words[1:]
        if rest[:1] in (["push"], ["config"], ["rebase"]):
            return True
        if rest[:2] == ["reset", "--hard"]:
            return True
        if rest[:1] == ["worktree"] and rest[1:2] in (
                ["add"], ["remove"], ["move"], ["prune"], ["repair"], ["lock"], ["unlock"]):
            return True
        if rest[:1] == ["archive"] and any(word == "-o" or word.startswith("-o") for word in rest[1:]):
            return True
        if any(word == "--output" or word.startswith("--output=") for word in rest):
            return True
    if base == "find" and any(
            word in ("-exec", "-execdir", "-ok", "-okdir", "-delete")
            or word.startswith("-fprint") or word.startswith("-fls")
            for word in words[1:]):
        return True
    return any(word == "--output" or word.startswith("--output=") for word in words[1:])


def inside_worktree(path, run):
    """Whether an absolute path names this run's worktree, which is not outside it even when written in full."""
    name = RUN_SUFFIX.sub("", run or "")
    if not name:
        return False
    marker = re.escape("/.worktrees/" + name) + r"(?:/|$)"
    return re.search(marker, path) is not None


def outside_path(part, run=""):
    """Whether a part carries an absolute or `../` path outside the worktree."""
    if OUTSIDE_RELATIVE.search(part):
        return True
    for word in words_of(part):
        token = word.strip("'\"")
        if token.startswith("~/") or token.startswith("$HOME/"):
            return True
        if not token.startswith("/") or token in DEVICES:
            continue
        if not inside_worktree(token, run):
            return True
    return False


def classify(command, run=""):
    """One class for a denied call and the part that names the reason (the first ungranted part of a chain)."""
    text = command.strip()
    if not text:
        return "other", text
    if text.lower() in TOOL_NAMES:
        return "tool-name", text
    parts = split_chain(text)
    for part in parts:
        if outside_path(part, run):
            return "outside-worktree", part
    for part in parts:
        words = words_of(part)
        if len(words) > 1 and os.path.basename(words[0]) == "git" and words[1] == "-C":
            return "git-dir-flag", part
    if len(parts) > 1:
        ungranted = next((part for part in parts if not granted(part)), None)
        if ungranted is not None:
            return "part-of-chain", ungranted
    for part in parts:
        if interpreter_eval(part):
            return "interpreter-eval", part
    for part in parts:
        if write_form(part):
            return "write-form", part
    if len(parts) == 1 and not granted(parts[0]):
        return "never-granted", parts[0]
    return "other", text


ROW = re.compile(r"^([^\t]*)\t([^\t]*)\t([0-9]+)\t(.*)$")


def read_rows(path):
    """The TSV's rows as (name, count, command).

    A command can carry a newline, so a line that is not a four-column row continues the command above it
    instead of becoming a row of its own.
    """
    rows = []
    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            line = line.rstrip("\n")
            match = ROW.match(line)
            if match:
                project, run, count, command = match.groups()
                if project.strip().lower() == "project" and run.strip() == "name":
                    continue
                rows.append([run, int(count), command])
            elif rows:
                rows[-1][2] += "\n" + line
    return [(run, count, command) for run, count, command in rows]


def report(rows):
    """Print the count per class with its three commonest commands, then the ten commonest commands overall."""
    grouped = collections.defaultdict(collections.Counter)
    ranked = collections.Counter()
    total = occurrences = tools = 0
    for run, count, command in rows:
        name, _ = classify(command, run)
        grouped[name][command] += count
        ranked[(name, command)] += count
        total += 1
        occurrences += count
        if name == "tool-name":
            tools += count
    print(f"denied calls: {total} entries, {occurrences} occurrences, "
          f"{occurrences - tools} shell, {tools} tool-name")
    for name in CLASSES:
        counts = grouped.get(name, collections.Counter())
        count = sum(counts.values())
        print(f"\n{name}: {len(counts)} commands, {count} occurrences")
        for command, most_count in counts.most_common(3):
            print(f"  x{most_count}  {command[:120]}")
    print("\ntop 10 commands:")
    for rank, ((name, command), count) in enumerate(ranked.most_common(10), 1):
        print(f"{rank:2d}. {name}: x{count}  {command[:120]}")


def first_word_table(rows):
    """The old first-word grouping, kept so a change can be compared with it."""
    entries = collections.Counter()
    occurrences = collections.Counter()
    for run, count, command in rows:
        word = (command.split() or ["?"])[0][:30]
        entries[word] += 1
        occurrences[word] += count
    print("first_word\tentries\toccurrences")
    for word, count in entries.most_common():
        print(f"{word}\t{count}\t{occurrences[word]}")


USAGE = ("usage: denied.py <denied-calls.tsv> [--class CLASS | --first-word]"
         "  (TSV columns: project, name, count, command)")


def main(argv):
    if argv[1:2] in (["--help"], ["-h"]):
        print(USAGE)
        return 0
    if len(argv) not in (2, 3, 4) or (len(argv) == 4 and argv[2] != "--class") \
            or (len(argv) == 3 and argv[2] != "--first-word"):
        print(USAGE, file=sys.stderr)
        return 2
    try:
        rows = read_rows(argv[1])
    except OSError as error:
        print(f"denied.py: cannot read {argv[1]}: {error.strerror}", file=sys.stderr)
        return 1
    if len(argv) == 3:
        first_word_table(rows)
        return 0
    if len(argv) == 4:
        wanted = collections.Counter()
        parts = {}
        for run, count, command in rows:
            name, part = classify(command, run)
            if name == argv[3]:
                wanted[command] += count
                parts.setdefault(command, part)
        for command, count in wanted.most_common():
            print(f"x{count}\t{command}\t[{parts[command][:120]}]")
        return 0
    report(rows)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except BrokenPipeError:
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        sys.exit(0)
