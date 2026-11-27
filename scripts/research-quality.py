#!/usr/bin/env python3
"""Record what one source is worth: its kind, publisher, publication date and independence group.

Usage: research-quality.py <id> --kind primary|secondary|aggregator --publisher "<name>" \
         --published <YYYY-MM-DD|unknown> --independence-group <slug> [--url <url>] [--rdap-base <url>]

One row per source in .ws-evidence/source-quality.tsv, with the columns id, kind, publisher, published_on,
independence_group, domain, domain_age_days, https, checked_on. kind says whether the page is the originating
source, a report of it, or a site that gathers other sites; independence_group names the thing a figure would
actually be counting if it cited this page twice (the originating wire, the publisher, or the study the pages
report), so five copies of one wire story are one group. The domain comes from --url, or from the URL the source
index holds when the flag is left out; https is yes or no for that URL.

domain_age_days comes from the registry: one RDAP lookup per domain (https://rdap.org/domain/<domain> unless
--rdap-base names another), cached under .ws-evidence/rdap/ so a second source on the same domain costs none. The
age is counted from the registration event to checked_on. A lookup that fails, times out, answers with no
registration event, or names no domain is recorded as unknown with the reason in the cache and on stdout: an age
this script could not establish is never written as a number, and an unregistered domain is never recorded as old.
A domain under a multi-label public suffix (example.co.uk) is looked up whole, because splitting it needs the public
suffix list; that lookup may fail and then the age is unknown, which is visible rather than guessed.

Deliberate: a quality row is written once per id and never overwritten, so what a source was judged to be cannot
change under an existing citation.
"""
import argparse
import http.client
import json
import os
import re
import sys
import tempfile
import urllib.error
import urllib.request
from datetime import date, datetime
from urllib.parse import urlsplit

import research_index

SOURCES = os.path.join(".ws-evidence", "sources.tsv")
QUALITY = os.path.join(".ws-evidence", "source-quality.tsv")
CACHE = os.path.join(".ws-evidence", "rdap")
HEADER = "id\tkind\tpublisher\tpublished_on\tindependence_group\tdomain\tdomain_age_days\thttps\tchecked_on\n"
KINDS = ("primary", "secondary", "aggregator")
RDAP = "https://rdap.org/domain"
TIMEOUT = 20
YOUNG_DAYS = 365
BODY_CAP = 1024 * 1024
USER_AGENT = "crafting-guild-research (source quality)"
DATE = re.compile(r"\d{4}-\d{2}-\d{2}")


def source_url(source_id):
    """The url the source index holds for the id, or exit when the row is gone."""
    try:
        with open(SOURCES, encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except FileNotFoundError:
        sys.exit(f"research-quality: no {SOURCES}; fetch the source before recording what it is worth")
    for line in lines[1:]:
        cells = line.split("\t")
        if cells and cells[0] == source_id:
            return cells[1] if len(cells) > 1 else ""
    sys.exit(f"research-quality: {source_id} is not in {SOURCES}; fetch it first, so only a source that was saved "
             "gets a quality row")


def domain_of(url):
    """(host, "yes"/"no" for https) of an http(s) URL, with a leading www. dropped so the registry is asked for the
    domain."""
    parts = urlsplit(url)
    if parts.scheme not in ("http", "https") or not parts.hostname:
        sys.exit(f"research-quality: {url} is not an http(s) URL with a host")
    host = parts.hostname.lower().rstrip(".")
    if host.startswith("www."):
        host = host[len("www."):]
    return host, "yes" if parts.scheme == "https" else "no"


def read_cache(domain):
    """The cached lookup for the domain, None when it was never made, or exit when the cache file is unreadable."""
    path = os.path.join(CACHE, domain + ".json")
    try:
        with open(path, encoding="utf-8") as handle:
            record = json.load(handle)
    except FileNotFoundError:
        return None
    except (json.JSONDecodeError, UnicodeDecodeError):
        sys.exit(f"research-quality: {path} is not the JSON this script writes; remove it to look the domain up again")
    if not isinstance(record, dict):
        sys.exit(f"research-quality: {path} does not hold one lookup record; remove it to look the domain up again")
    return record


def registration_of(record):
    """(registration date or None, why there is none) from an RDAP domain object."""
    for event in record.get("events") or []:
        if not isinstance(event, dict) or event.get("eventAction") != "registration":
            continue
        stamp = str(event.get("eventDate") or "")
        try:
            return date.fromisoformat(stamp[:10]), ""
        except ValueError:
            return None, f"an unreadable registration date {stamp!r}"
    return None, "no registration event"


def lookup(domain, base):
    """One RDAP lookup: (registration date or None, reason it could not be read; empty when it could)."""
    url = base.rstrip("/") + "/" + domain
    request = urllib.request.Request(url, headers={"Accept": "application/rdap+json", "User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            body = response.read(BODY_CAP)
    except urllib.error.HTTPError as exc:
        return None, "not registered" if exc.code == 404 else f"HTTP {exc.code}"
    except (urllib.error.URLError, OSError, ValueError, http.client.HTTPException) as exc:
        return None, str(exc)
    try:
        record = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return None, "the registry did not answer with RDAP JSON"
    if not isinstance(record, dict):
        return None, "the registry did not answer with an RDAP domain object"
    return registration_of(record)


def write_cache(domain, record):
    """Replace the domain's cache file atomically, so a second process never reads a half-written lookup."""
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, domain + ".json")
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=CACHE, prefix=domain + ".",
                                     suffix=".json.tmp", delete=False) as handle:
        json.dump(record, handle, sort_keys=True)
        handle.write("\n")
        temporary = handle.name
    os.replace(temporary, path)


def age_of(domain, base, today):
    """(days since registration, or None and the reason): the cache first, then one lookup written into it."""
    record = read_cache(domain)
    if record is None:
        registered, reason = lookup(domain, base)
        record = {"domain": domain, "registration": registered.isoformat() if registered else None, "reason": reason}
        write_cache(domain, record)
    if not record.get("registration"):
        return None, record.get("reason") or "the lookup recorded no registration date"
    try:
        registered = date.fromisoformat(str(record["registration"]))
    except ValueError:
        sys.exit(f"research-quality: {os.path.join(CACHE, domain + '.json')} holds no readable registration date; "
                 "remove it to look the domain up again")
    days = (today - registered).days
    if days < 0:
        return None, f"the registry dates the domain after {today.isoformat()}"
    return days, ""


def main(argv):
    parser = argparse.ArgumentParser(description="record what one research source is worth in .ws-evidence/"
                                                 "source-quality.tsv")
    parser.add_argument("id")
    parser.add_argument("--kind", required=True, help=", ".join(KINDS))
    parser.add_argument("--publisher", required=True, help="the organisation or person that published the page")
    parser.add_argument("--published", required=True, help="YYYY-MM-DD, or unknown")
    parser.add_argument("--independence-group", required=True,
                        help="a slug shared by pages that report one originating source")
    parser.add_argument("--url", default="", help="the page's URL; the source index row's URL when left out")
    parser.add_argument("--rdap-base", default=RDAP, help=f"RDAP base URL (default {RDAP})")
    opts = parser.parse_args(argv)
    try:
        research_index.check_id(opts.id)
        research_index.cell(opts.publisher)
    except research_index.BadCell as exc:
        sys.exit(f"research-quality: {exc}")
    if opts.kind not in KINDS:
        sys.exit(f"research-quality: {opts.kind} is not a kind; use one of {', '.join(KINDS)}")
    if opts.published != "unknown":
        try:
            date.fromisoformat(opts.published)
        except ValueError:
            sys.exit(f"research-quality: {opts.published} is neither unknown nor a YYYY-MM-DD date")
        if not DATE.fullmatch(opts.published):
            sys.exit(f"research-quality: {opts.published} is neither unknown nor a YYYY-MM-DD date")
    if not opts.publisher.strip():
        sys.exit("research-quality: publisher is empty; name the organisation or person that published the page")
    if not opts.independence_group.strip():
        sys.exit("research-quality: independence-group is empty; name the originating source pages share a group when "
                 "they report one article, one publisher or one study")
    try:
        research_index.check_id(opts.independence_group)
    except research_index.BadCell as exc:
        sys.exit(f"research-quality: independence-group: {exc}")
    url = opts.url or source_url(opts.id)
    domain, https = domain_of(url)
    today = datetime.now().astimezone().date()
    days, reason = age_of(domain, opts.rdap_base, today)
    row = [opts.id, opts.kind, opts.publisher.strip(), opts.published, opts.independence_group, domain,
           str(days) if days is not None else "unknown", https, today.isoformat()]
    try:
        with research_index.opening(QUALITY, HEADER) as (handle, recorded):
            if opts.id in recorded:
                sys.exit(f"research-quality: {opts.id} is already in {QUALITY}; a quality row is never overwritten")
            research_index.append(handle, row)
    except research_index.BadCell as exc:
        sys.exit(f"research-quality: {exc}")
    if days is None:
        print(f"recorded {opts.id}: {opts.kind} from {opts.publisher}, {domain}, domain age unknown ({reason})")
    else:
        print(f"recorded {opts.id}: {opts.kind} from {opts.publisher}, {domain}, {days} days old")
    if days is not None and days < YOUNG_DAYS:
        print(f"young-source warning: {opts.id}'s domain {domain} is {days} days old; report it in the run's unknowns")
    if days is None:
        print(f"warning: {opts.id}'s domain age is unknown; report it in the run's unknowns")
    if opts.published == "unknown":
        print(f"warning: {opts.id} has no publication date; report it in the run's unknowns")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
