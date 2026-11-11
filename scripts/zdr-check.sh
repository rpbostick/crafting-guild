#!/usr/bin/env bash
# Is an OpenCode model still zero-retention with no training? Reads the privacy page for the model's line (OpenCode's
# Go page's table for opencode-go/ models, its Zen page's prose free-model list for the opencode/ ones), from a
# saved copy when given one (--page, WS_ZDR_PAGE) or from a cache under runs/zdr-page-<go|zen>.html.
# Usage: zdr-check.sh [--page file] [--provider opencode-go|opencode]
#                     [model name as the page writes it, default "DeepSeek V4.1 Flash"]
# Exit 0 when the Go table lists the model as "Not used" (training) and "0 days" (retention), or the Zen list says
# its provider follows a zero-retention policy and does not train on your data, and, when a dated ZDR agreement
# covers it, that agreement has not lapsed; 1 otherwise, with the reason. Private code goes only to models
# that pass (the operator's rule), so a launcher refuses a model this fails on.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
page="" provider="opencode-go"
while [ $# -gt 0 ]; do
  case "$1" in
    --page) page="${2:?--page needs a path}"; shift 2 ;;
    --provider) provider="${2:?--provider needs opencode-go or opencode}"; shift 2 ;;
    -*) echo "zdr-check: unknown flag $1" >&2; exit 1 ;;
    *) break ;;
  esac
done
model="${1:-DeepSeek V4.1 Flash}"
case "$provider" in
  opencode-go) kind=go; url="https://opencode.ai/docs/go/" ;;
  opencode) kind=zen; url="https://opencode.ai/docs/zen" ;;
  *) echo "zdr-check: unknown provider '$provider' (opencode-go or opencode)" >&2; exit 1 ;;
esac
# An explicit page (a launcher passes WS_ZDR_PAGE) always wins over the cache.
[ -z "$page" ] && [ -n "${WS_ZDR_PAGE:-}" ] && page="$WS_ZDR_PAGE"
cache_dir="$WS/runs"; cache="$cache_dir/zdr-page-$kind.html"
cache_days="${WS_ZDR_CACHE_DAYS:-1}"
case "$cache_days" in ''|*[!0-9]*) echo "zdr-check: WS_ZDR_CACHE_DAYS takes whole days, not '$cache_days'" >&2; exit 1 ;; esac
tmp=""
cleanup() { [ -n "$tmp" ] && rm -f "$tmp"; }
trap cleanup EXIT
if [ -z "$page" ]; then
  fresh=0
  if [ -f "$cache" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$cache" 2>/dev/null || echo 0) ))
    [ "$age" -lt $(( cache_days * 86400 )) ] && fresh=1
  fi
  if [ "$fresh" = 1 ]; then
    page="$cache"
  else
    tmp=$(mktemp)
    if curl -fsSL --max-time 30 "$url" -o "$tmp"; then
      mkdir -p "$cache_dir"
      mv -f "$tmp" "$cache"; tmp=""
      page="$cache"
    elif [ -f "$cache" ]; then
      echo "zdr-check: cannot refresh $url; using the cached page ${cache#"$WS/"}" >&2
      page="$cache"
    else
      echo "zdr-check: cannot read $url"
      exit 1
    fi
  fi
fi
python3 -I - "$page" "$model" "${WS_TODAY:-$(date +%F)}" "$provider" <<'EOF'
import datetime, html, re, sys
page, model, today, provider = sys.argv[1], sys.argv[2], datetime.date.fromisoformat(sys.argv[3]), sys.argv[4]
text = html.unescape(re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", open(page, encoding="utf-8", errors="replace").read())))

ZEN_PASS = "follows a zero-retention policy and does not use your data for model training"
# A model id spells a name with hyphens while the page may use spaces ("glm-5.3-flash-free" / "GLM-5.3-Flash Free").
ZEN_NAME = re.compile(
    r"(?<![\w.-])" + r"[-\s]+".join(re.escape(part) for part in re.split(r"[-\s]+", model)) + r"(?![\w.-])",
    re.IGNORECASE,
)

def zen_passage():
    # The Zen page lists free models as prose list items, not table rows: the item names the model and the
    # clause after it states the provider's retention and training terms. Find every sentence naming the model
    # and judge it with its provider clause, which is its own sentence when one item carries both.
    sentences = re.split(r"(?<=[.!?])\s+", text)
    found = None
    for i, sentence in enumerate(sentences):
        if not ZEN_NAME.search(sentence):
            continue
        passage = sentence
        # The privacy clause is the item's next sentence when that sentence continues the provider's terms;
        # another model's item must not lend its terms to this one.
        if i + 1 < len(sentences) and re.match(r"(?i)(its|the) provider\b", sentences[i + 1]):
            passage += " " + sentences[i + 1]
        if ZEN_PASS in passage:
            return passage, True
        if found is None:
            found = passage
    return found, False

if provider == "opencode":
    passage, passed = zen_passage()
    if passage is None:
        sys.exit(print(f"zdr-check: {model!r} not found in the Zen page's free-model list") or 1)
    if not passed:
        sys.exit(print(f"zdr-check: {model}: not zero-retention with no training: {passage.strip()}") or 1)
    print(f"ok: {model}: no training, zero retention")
    sys.exit(0)
m = re.search(re.escape(model) + r" (Not used|Yes) (0 days|Not ZDR|\d+ days)(\*?)", text)
if not m:
    sys.exit(print(f"zdr-check: {model!r} not found in the privacy table") or 1)
training, retention, starred = m.groups()
if training != "Not used" or retention != "0 days":
    sys.exit(print(f"zdr-check: {model}: training {training}, retention {retention}") or 1)
if provider != "opencode" and starred:
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
