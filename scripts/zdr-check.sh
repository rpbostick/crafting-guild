#!/usr/bin/env bash
# Is an OpenCode Go model still zero-retention with no training? Reads OpenCode's Go page (or a saved copy, for tests).
# Usage: zdr-check.sh [--page file] [model name as the page writes it, default "DeepSeek V4.1 Flash"]
# Exit 0 when the page lists the model as "Not used" (training) and "0 days" (retention) and, when a dated ZDR
# agreement covers it, that agreement has not lapsed; 1 otherwise, with the reason. Private code goes only to models
# that pass (the operator's rule), so a launcher refuses a model this fails on.
set -uo pipefail
page="" url="https://opencode.ai/docs/go/"
[ "${1:-}" = --page ] && { page="$2"; shift 2; }
model="${1:-DeepSeek V4.1 Flash}"
if [ -z "$page" ]; then
  page=$(mktemp); trap 'rm -f "$page"' EXIT
  curl -fsSL --max-time 30 "$url" -o "$page" || { echo "zdr-check: cannot read $url"; exit 1; }
fi
python3 -I - "$page" "$model" "${WS_TODAY:-$(date +%F)}" <<'EOF'
import datetime, html, re, sys
page, model, today = sys.argv[1], sys.argv[2], datetime.date.fromisoformat(sys.argv[3])
text = html.unescape(re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", open(page, encoding="utf-8", errors="replace").read())))
m = re.search(re.escape(model) + r" (Not used|Yes) (0 days|Not ZDR|\d+ days)(\*?)", text)
if not m:
    sys.exit(print(f"zdr-check: {model!r} not found in the privacy table") or 1)
training, retention, starred = m.groups()
if training != "Not used" or retention != "0 days":
    sys.exit(print(f"zdr-check: {model}: training {training}, retention {retention}") or 1)
if starred:
    # The star points at a vendor note: "<Vendor>: ZDR agreement is renewed monthly. The current agreement is valid through <date>."
    vendor = model.split()[0]
    d = re.search(re.escape(vendor) + r": ZDR agreement[^.]*\.[^.]*valid through ([A-Z][a-z]+ \d{1,2}, \d{4})", text)
    if not d:
        sys.exit(print(f"zdr-check: {model}: retention is starred but no dated {vendor} agreement was found") or 1)
    until = datetime.datetime.strptime(d.group(1), "%B %d, %Y").date()
    if until < today:
        sys.exit(print(f"zdr-check: {model}: the {vendor} ZDR agreement lapsed {until}") or 1)
    print(f"ok: {model}: no training, 0 days, agreement valid through {until}")
else:
    print(f"ok: {model}: no training, 0 days")
EOF
