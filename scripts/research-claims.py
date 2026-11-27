#!/usr/bin/env python3
"""Record one figure a research run reports, in .ws-evidence/claims.tsv, citing source ids that exist.

Usage: research-claims.py <id> <claim> <value> <computation> <source_ids> [<denominator>]
         [--quote <fragment>] [--require-quote]

source_ids is a comma- or space-separated list of ids from the run's source index. Every id must already be there,
so a figure cannot cite a page the run never fetched. denominator stays empty for a figure that is not a rate.
--quote is the fragment of the cited page that states the figure, copied verbatim. One row per figure, with the
columns id, claim, value, quote, computation, source_ids, denominator.

A six-column table (no quote column) is migrated in place the first time this script touches it: every existing row
gets an empty quote cell, so an older run's table stays readable.

--require-quote refuses a claim whose quote is empty, and one whose quote is not in the saved body of any source it
cites. Deliberate: a quote the cited page does not carry is the failure the column exists to catch, so the check is
against the bytes research-fetch.py saved, not against the claim's own wording.
"""
import argparse
import os
import sys

import research_index

SOURCES = os.path.join(".ws-evidence", "sources.tsv")
CLAIMS = os.path.join(".ws-evidence", "claims.tsv")
BODIES = os.path.join(".ws-evidence", "sources")
HEADER = "id\tclaim\tvalue\tquote\tcomputation\tsource_ids\tdenominator\n"
OLD_HEADER = "id\tclaim\tvalue\tcomputation\tsource_ids\tdenominator\n"
QUOTE_COLUMN = 3
CHUNK = 64 * 1024


def cited(value):
    return [part for part in value.replace(",", " ").split() if part]


def carries(path, needle):
    """Whether the saved body holds the quote, read a chunk at a time so a 25 MB page is never held whole.

    Each chunk is joined with the tail of the one before it, so a quote that straddles a chunk boundary is still
    found.
    """
    tail = b""
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(CHUNK), b""):
            if needle in tail + chunk:
                return True
            tail = chunk[-(len(needle) - 1):] if len(needle) > 1 else b""
    return False


def quoted_by(quote, sources):
    """(sources whose saved body carries the quote, sources with no saved body)."""
    needle = quote.encode("utf-8")
    found, absent = [], []
    for source in sources:
        path = os.path.join(BODIES, source + ".body")
        try:
            if carries(path, needle):
                found.append(source)
        except FileNotFoundError:
            absent.append(source)
    return found, absent


def main(argv):
    parser = argparse.ArgumentParser(description="record one figure of a research run in .ws-evidence/claims.tsv")
    parser.add_argument("id")
    parser.add_argument("claim")
    parser.add_argument("value")
    parser.add_argument("computation")
    parser.add_argument("source_ids")
    parser.add_argument("denominator", nargs="?", default="", help="the group a rate is over; empty for a count")
    parser.add_argument("--quote", default="", help="the cited page's own words that state the figure")
    parser.add_argument("--require-quote", action="store_true",
                        help="refuse a claim with no quote, or one whose quote no cited source's saved body carries")
    opts = parser.parse_args(argv)
    try:
        research_index.check_id(opts.id)
        for name, text in (("claim", opts.claim), ("value", opts.value), ("computation", opts.computation)):
            if not text.strip():
                sys.exit(f"research-claims: {name} is empty; a figure needs its claim, value and computation")
            research_index.cell(text)
        research_index.cell(opts.denominator)
        research_index.cell(opts.quote)
        sources = cited(opts.source_ids)
        if not sources:
            sys.exit("research-claims: name at least one source id")
        for source in sources:
            research_index.check_id(source)
    except research_index.BadCell as exc:
        sys.exit(f"research-claims: {exc}")
    known = research_index.ids(SOURCES)
    missing = [source for source in sources if source not in known]
    if missing:
        sys.exit(f"research-claims: {', '.join(missing)} is not in {SOURCES}; fetch it first, so every figure cites "
                 "the sources the run used")
    try:
        if research_index.migrate(CLAIMS, OLD_HEADER, HEADER, QUOTE_COLUMN):
            print(f"migrated {CLAIMS}: added the quote column; earlier rows keep their values and have an empty quote")
    except research_index.BadRow as exc:
        sys.exit(f"research-claims: {exc}")
    if opts.require_quote:
        if not opts.quote.strip():
            sys.exit(f"research-claims: {opts.id} has no quote; --require-quote refuses a figure with no fragment of "
                     "its cited page's own words")
        found, absent = quoted_by(opts.quote, sources)
        if not found:
            sys.exit(f"research-claims: {opts.id}'s quote is not in the saved body of {', '.join(sources)}"
                     + (f" (no body was saved for {', '.join(absent)})" if absent else "")
                     + "; copy the fragment from the saved body, not from memory")
    try:
        with research_index.opening(CLAIMS, HEADER) as (handle, recorded):
            if opts.id in recorded:
                sys.exit(f"research-claims: {opts.id} is already in {CLAIMS}; give the figure a new id")
            research_index.append(handle, [opts.id, opts.claim, opts.value, opts.quote, opts.computation,
                                           ",".join(sources), opts.denominator])
    except research_index.BadCell as exc:
        sys.exit(f"research-claims: {exc}")
    print(f"recorded {opts.id}: {opts.value} ({', '.join(sources)}) in {CLAIMS}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
