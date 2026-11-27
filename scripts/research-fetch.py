#!/usr/bin/env python3
"""Save one web page under .ws-evidence/sources/ and index it, so a finding cites bytes that can be read again.

Usage: research-fetch.py <id> <url> --evidences <what the page evidences> [--max-mb N]

The page is written exactly as served, so the row's SHA-256 names the bytes a finding was read from; nothing in it
is executed or interpreted, and the body is streamed to the file in chunks rather than held whole in memory. http
and https only, redirects included. 25 MB is the most a page may be: --max-mb may lower that cap and a value above
25 is refused. The body is downloaded as <id>.body.part and renamed only after it is whole, so a body that stops
short of its declared length, or a stream cut off mid-chunk, fails and leaves no body and no row behind. An id that
already has a row or a file is refused: a citation must not come to mean different bytes.
"""
import argparse
import codecs
import hashlib
import html
import http.client
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime

import research_index

SOURCES = os.path.join(".ws-evidence", "sources")
INDEX = os.path.join(".ws-evidence", "sources.tsv")
HEADER = "id\turl\tfetched_at\tsha256\ttitle\tevidences\n"
DEFAULT_MAX_MB = 25
TIMEOUT = 60
CHUNK = 64 * 1024
TITLE_TAIL = len("</title>") - 1
USER_AGENT = "crafting-guild-research (source fetch)"


def discard(path):
    """Remove a partial body, so a failed fetch leaves nothing a citation could read."""
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass


def title_of(path, charset):
    """The page's <title>, collapsed to one line, or "" when it has none.

    Scanned from the saved file a chunk at a time, so the title is found without holding the body in memory.
    """
    decoder = codecs.getincrementaldecoder(charset or "utf-8")("replace")
    pending = ""
    parts = []
    started = False
    with open(path, "rb") as handle:
        for raw in iter(lambda: handle.read(CHUNK), b""):
            text = pending + decoder.decode(raw)
            if not started:
                opened = re.search(r"<title[^>]*>", text, re.I)
                if not opened:
                    # Keep only the tail from the last "<": a tag can split across chunks, text that cannot be a
                    # <title> tag never has to be kept.
                    pending = text[text.rfind("<"):] if "<" in text else ""
                    continue
                started = True
                text = text[opened.end():]
            closed = re.search(r"</title>", text, re.I)
            if closed:
                parts.append(text[:closed.start()])
                return " ".join(html.unescape("".join(parts)).split())
            parts.append(text[:-TITLE_TAIL] if len(text) > TITLE_TAIL else "")
            pending = text[-TITLE_TAIL:]
    return ""


def fetch(url, destination, limit):
    """(charset, digest, size) after streaming the page into destination, or exit naming what the fetch did not get.

    The body goes to <destination>.part and is renamed into place only once it is whole, so no file a citation could
    read exists for a fetch that did not finish. Each chunk is written and hashed as it arrives, so a body larger
    than the cap is never held whole in memory; the cap is checked before the chunk that crosses it is kept, and
    every failure removes the .part file on the way out.
    """
    partial = destination + ".part"
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    digest = hashlib.sha256()
    size = 0
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            status = response.status
            if status != 200:
                sys.exit(f"research-fetch: {url} answered HTTP {status}")
            charset = response.headers.get_content_charset()
            # The declared Content-Length, or None for a chunked body or one that declares no length.
            expected = response.length
            with open(partial, "xb") as out:
                for chunk in iter(lambda: response.read(CHUNK), b""):
                    size += len(chunk)
                    if size > limit:
                        discard(partial)
                        sys.exit(f"research-fetch: {url} is over the {limit // (1024 * 1024)} MB cap")
                    out.write(chunk)
                    digest.update(chunk)
    except FileExistsError:
        sys.exit(f"research-fetch: {partial} is left from an interrupted fetch: remove it before fetching this id "
                 "again")
    except (urllib.error.URLError, OSError, ValueError, http.client.HTTPException) as exc:
        discard(partial)
        sys.exit(f"research-fetch: cannot fetch {url}: {exc}")
    # HTTPResponse.read(amt) returns b"" when the peer closed early instead of raising, so a body shorter than the
    # length it declared would otherwise read as finished; the count is compared against that declaration.
    if expected is not None and size != expected:
        discard(partial)
        sys.exit(f"research-fetch: {url} closed after {size} of the {expected} bytes it declared: the body is "
                 "incomplete")
    # A body with no declared length and no chunking is delimited only by the connection closing, which http.client
    # cannot tell from a body cut short: it is accepted only when every read returned normally (a cut-off chunked
    # stream raises IncompleteRead, caught above) and the last one returned b"" at end of file rather than a short
    # read. Deliberate: the alternative is refusing every such response, and servers that omit Content-Length are
    # the ones this path exists for.
    if os.path.exists(destination):
        discard(partial)
        sys.exit(f"research-fetch: {destination} exists without a row: an id is never overwritten; fetch under "
                 "a new id")
    os.rename(partial, destination)
    return charset, digest.hexdigest(), size


def main(argv):
    parser = argparse.ArgumentParser(description="save one web page under .ws-evidence/sources/ and index it")
    parser.add_argument("id")
    parser.add_argument("url")
    parser.add_argument("--evidences", required=True, help="what the page evidences, quoted into the index")
    parser.add_argument("--max-mb", type=int, default=DEFAULT_MAX_MB,
                        help=f"cap on the body in MB; {DEFAULT_MAX_MB} is the maximum")
    opts = parser.parse_args(argv)
    if opts.max_mb <= 0:
        sys.exit(f"research-fetch: --max-mb takes a positive number of MB, not {opts.max_mb}")
    if opts.max_mb > DEFAULT_MAX_MB:
        sys.exit(f"research-fetch: --max-mb {opts.max_mb} is above the {DEFAULT_MAX_MB} MB maximum: a call may lower "
                 "the cap, not raise it")
    if not re.match(r"https?://", opts.url, re.I):
        sys.exit(f"research-fetch: {opts.url} is not an http(s) URL")
    try:
        research_index.check_id(opts.id)
        research_index.cell(opts.evidences)
    except research_index.BadCell as exc:
        sys.exit(f"research-fetch: {exc}")
    os.makedirs(SOURCES, exist_ok=True)
    destination = os.path.join(SOURCES, opts.id + ".body")
    if opts.id in research_index.ids(INDEX):
        sys.exit(f"research-fetch: {opts.id} is already in {INDEX}: fetch under a new id, so a citation keeps naming "
                 "the same bytes")
    charset, digest, size = fetch(opts.url, destination, opts.max_mb * 1024 * 1024)
    stamp = datetime.now().astimezone().strftime("%Y-%m-%dT%H:%M:%S%z")
    try:
        with research_index.opening(INDEX, HEADER) as (handle, known):
            if opts.id in known:
                discard(destination)
                sys.exit(f"research-fetch: {opts.id} is already in {INDEX}: fetch under a new id, so a citation keeps "
                         "naming the same bytes")
            try:
                research_index.append(handle, [opts.id, opts.url, stamp, digest, title_of(destination, charset),
                                               opts.evidences])
            except BaseException:
                discard(destination)
                raise
    except research_index.BadCell as exc:
        discard(destination)
        sys.exit(f"research-fetch: {exc}")
    print(f"fetched {opts.id}: {opts.url} -> {destination} ({size} bytes, sha256 {digest})")
    print(f"indexed {opts.id} in {INDEX}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
