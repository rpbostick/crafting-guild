#!/usr/bin/env python3
"""Print each worksheet of an .xlsx as tab-separated text, for a document review's prompt.

Usage: xlsx_dump.py <file.xlsx> [<max-rows-per-sheet>] [<max-columns>]

Read-only, Python stdlib only. Deliberate: openpyxl (MIT) is the maintained reader where it is installed, but a
document review must run with the standard library alone (no dependency installed at run time), so this reads
the sheet XML directly. It covers what a report workbook stores: shared and inline strings, numbers, booleans,
errors and cached formula values.
"""
import re
import sys
import zipfile
import xml.etree.ElementTree as ET

# A report's tables are small; these bounds keep a stray export from filling the reviewer's prompt.
MAX_ROWS = 500
MAX_COLUMNS = 40
CELL_REF = re.compile(r"^([A-Z]+)([0-9]+)$")


def local(tag):
    return tag.rsplit("}", 1)[-1]


def attr(element, name):
    """An attribute by local name: the workbook's XML uses the relationships namespace for r:id."""
    for key, value in element.attrib.items():
        if key == name or local(key) == name:
            return value
    return None


def column_index(reference):
    match = CELL_REF.match(reference or "")
    if not match:
        return None
    index = 0
    for letter in match.group(1):
        index = index * 26 + (ord(letter) - ord("A") + 1)
    return index - 1


def text_of(element):
    """The text of one cell: a shared string, an inline string, or the stored value."""
    kind = attr(element, "t")
    if kind == "inlineStr":
        return "".join(node.text or "" for node in element.iter() if local(node.tag) == "t")
    value = next((node.text or "" for node in element if local(node.tag) == "v"), "")
    if kind == "b":
        return "true" if value == "1" else "false"
    return value


def shared_strings(archive):
    """The shared-string table, in index order; a workbook without one has an empty table."""
    try:
        root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
    except KeyError:
        return []
    return ["".join(node.text or "" for node in item.iter() if local(node.tag) == "t")
            for item in root if local(item.tag) == "si"]


def sheet_parts(archive):
    """[(name, zip path)] in workbook order, resolved through the workbook's relationships file."""
    workbook = ET.fromstring(archive.read("xl/workbook.xml"))
    rels = {}
    try:
        relationships = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
        for rel in relationships:
            target = attr(rel, "Target") or ""
            rels[attr(rel, "Id")] = target.lstrip("/") if target.startswith("/") else "xl/" + target
    except KeyError:
        pass
    found = []
    for sheet in workbook.iter():
        if local(sheet.tag) != "sheet":
            continue
        name = attr(sheet, "name") or "sheet"
        rid = attr(sheet, "id")
        path = rels.get(rid)
        if path:
            found.append((name, path))
    return found


def dump(path, max_rows=MAX_ROWS, max_columns=MAX_COLUMNS):
    """The workbook as text. Raises ValueError for a file that is not a readable .xlsx."""
    try:
        archive = zipfile.ZipFile(path)
    except (OSError, zipfile.BadZipFile) as error:
        raise ValueError(f"not a readable .xlsx: {error}")
    with archive:
        strings = shared_strings(archive)
        sheets = sheet_parts(archive)
        if not sheets:
            raise ValueError("no worksheets in the workbook")
        out = []
        for name, part in sheets:
            out.append(f"## Sheet: {name}")
            try:
                root = ET.fromstring(archive.read(part))
            except (KeyError, ET.ParseError) as error:
                raise ValueError(f"worksheet {name!r} ({part}) is unreadable: {error}")
            rows = 0
            for row in root.iter():
                if local(row.tag) != "row":
                    continue
                rows += 1
                if rows > max_rows:
                    out.append(f"(stopped after {max_rows} rows)")
                    break
                cells = {}
                for cell in row:
                    if local(cell.tag) != "c":
                        continue
                    index = column_index(attr(cell, "r"))
                    if index is None or index >= max_columns:
                        continue
                    value = text_of(cell)
                    if attr(cell, "t") == "s" and value.isdigit():
                        position = int(value)
                        value = strings[position] if position < len(strings) else ""
                    cells[index] = " ".join(value.replace("\t", " ").split("\n"))
                if not cells:
                    continue
                width = max(cells) + 1
                out.append("\t".join(cells.get(index, "") for index in range(width)))
            out.append("")
    return "\n".join(out)


def main(argv):
    if not argv:
        sys.exit(__doc__)
    path = argv[0]
    max_rows = int(argv[1]) if len(argv) > 1 else MAX_ROWS
    max_columns = int(argv[2]) if len(argv) > 2 else MAX_COLUMNS
    try:
        text = dump(path, max_rows, max_columns)
    except ValueError as error:
        print(f"xlsx_dump: {error}", file=sys.stderr)
        return 2
    print(text, end="" if text.endswith("\n") else "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
