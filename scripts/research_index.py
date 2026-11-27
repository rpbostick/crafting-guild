#!/usr/bin/env python3
"""The row indexes a research run keeps: a locked append that refuses a repeated id, and the ids one holds.

A research run may fan out subagents, so more than one process can index a row at the same time. An append holds an
exclusive lock on the index itself and checks the ids before writing, so an id never gets two rows and no reader
sees half a row. Cells are one line each: a tab or a newline in a value would shift every column after it.
"""
import contextlib
import fcntl
import re

ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")


class Duplicate(Exception):
    """The id already has a row; an id must keep naming the same page, so it is never overwritten."""


class BadCell(Exception):
    """A value a tab-separated row cannot carry."""


class BadRow(Exception):
    """An index row whose shape a migration cannot map onto the new header."""


def check_id(value):
    if not ID.fullmatch(value):
        raise BadCell(f"id {value!r} may use only letters, digits, '.', '_' and '-' and must not be empty")


def cell(value):
    if "\t" in value or "\n" in value or "\r" in value:
        raise BadCell(f"value {value[:60]!r} holds a tab or a newline, which a tab-separated row cannot carry")
    return value


def ids(path):
    """The ids an index already holds, and none when it does not exist yet."""
    try:
        with open(path, encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except FileNotFoundError:
        return set()
    return {line.split("\t", 1)[0] for line in lines[1:] if line}


def migrate(path, old_header, header, insert_at):
    """Give every row of an index written under old_header an empty cell at insert_at, and rewrite its header.

    Returns True when the file was migrated and False when it is new or already carries the new header, so a caller
    can say whether it moved old data rather than leave the shape change silent. The rewrite holds the same exclusive
    lock an append takes: a run that fans out subagents cannot have one process migrating a table another is
    appending to. A header that is neither shape, or a row with a different number of cells than the old header,
    raises BadRow: the rows cannot be mapped without guessing where a value belonged.
    """
    try:
        handle = open(path, "r+", encoding="utf-8")
    except FileNotFoundError:
        return False
    new_header = header.rstrip("\n")
    old_columns = old_header.rstrip("\n").split("\t")
    with handle:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        lines = handle.read().splitlines()
        if not lines or lines[0] == new_header:
            return False
        if lines[0] != old_header.rstrip("\n"):
            raise BadRow(f"{path} has the header {lines[0]!r}; expected {old_header.rstrip()!r}")
        rows = []
        for number, line in enumerate(lines[1:], 2):
            if not line:
                continue
            cells = line.split("\t")
            if len(cells) != len(old_columns):
                raise BadRow(f"{path} line {number} has {len(cells)} cells; the old header has {len(old_columns)}")
            cells.insert(insert_at, "")
            rows.append("\t".join(cells))
        handle.seek(0)
        handle.write("\n".join([new_header] + rows) + "\n")
        handle.truncate()
        handle.flush()
        return True


@contextlib.contextmanager
def opening(path, header):
    """The index open and locked for appending, with its header when the file is new; yields (handle, known ids)."""
    handle = open(path, "a+", encoding="utf-8")
    try:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        handle.seek(0)
        text = handle.read()
        if not text:
            handle.write(header)
            handle.flush()
            text = header
        elif not text.endswith("\n"):
            # A writer killed mid-row left no closing newline; the next row still starts on its own line.
            handle.write("\n")
            handle.flush()
            text += "\n"
        yield handle, {line.split("\t", 1)[0] for line in text.splitlines()[1:] if line}
    finally:
        handle.close()


def append(handle, values):
    handle.write("\t".join(cell(value) for value in values) + "\n")
    handle.flush()
