#!/usr/bin/env bash
# The weekly maintenance check: what drifted between this machine's tools, the OpenCode install, the model list and
# the privacy pages the workspace relies on. It reports; it never changes a tool, a pin or a model. It writes only
# the report, runs/maintenance.last, zdr-check's cached privacy pages (and the model snapshot when none exists), and
# exits 0 even with drift so a scripted run can read the report.
# Usage: maintenance.sh [--report <path>] [--project <slug>]
set -uo pipefail
. "$(dirname "$0")/lib.sh"

report=""; project=""
while [ $# -gt 0 ]; do
  case "$1" in
    --report) report="${2:?--report needs a path}"; shift 2 ;;
    --project) project="${2:?--project needs a slug}"; shift 2 ;;
    -h|--help) echo "usage: ws maintenance [--report <path>] [--project <slug>]"; exit 0 ;;
    *) die "unknown argument '$1' (usage: ws maintenance [--report <path>] [--project <slug>])" ;;
  esac
done
if [ -n "$project" ] && [ ! -f "$WS/projects/$project.conf" ]; then
  die "unknown project '$project' (see projects/; register with: ws init <path>)"
fi
[ -n "$report" ] || report="reports/maintenance-$(today_local).md"
case "$report" in /*) ;; *) report="$WS/$report" ;; esac

# Every finding is one line in stdout and one bullet in the report's decision section.
findings=()
add_finding() { findings+=("$*"); }

# The first version-shaped run in a command's output ("v20.11.0", "git version 2.43.0", "jq-1.6").
norm_ver() { grep -oE '[0-9]+(\.[0-9]+)+' | head -n1; }
# True when <a> sorts before <b> as a version. Both are already normalized.
version_lt() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}
# The model list writes free models as ids ending -free; the [free] tag is only a display marker `ws models` adds.
is_free() {
  case "$1" in
    *-free) return 0 ;;
  esac
  return 1
}
# The Go page writes a model by display name, while the model list gives its id. The id's last path segment with
# hyphens and underscores as spaces and each word capitalized is the page's name ("beam-free" -> "Beam Free",
# "grok-4.7" -> "Grok 4.7"); the parser matches case-insensitively where the page capitalizes differently.
model_display_name() { # <provider/model>
  printf '%s' "${1##*/}" | sed -E 's/[-_]+/ /g' | awk '{ for (i = 1; i <= NF; i++) $i = toupper(substr($i, 1, 1)) substr($i, 2); print }'
}

models_tmp=""; xdg_tmp=""; node_index_tmp=""; go_tmp=""; zen_tmp=""; spec=""; privacy_tsv=""
current_raw=""; current_sorted=""; base_sorted=""; tmp_report=""
cleanup() {
  local f
  for f in "$models_tmp" "$node_index_tmp" "$go_tmp" "$zen_tmp" "$spec" "$privacy_tsv" \
           "$current_raw" "$current_sorted" "$base_sorted" "$tmp_report"; do
    [ -n "$f" ] && rm -f "$f"
  done
  [ -n "$xdg_tmp" ] && rm -rf "$xdg_tmp"
}
trap cleanup EXIT

# --- OpenCode lines -------------------------------------------------------------------------------------
# A version that cannot be read is not the same as no install: a broken or quiet binary still exists on PATH.
oc_present="no"
if [ -n "${WS_MAINTENANCE_OPENCODE_VERSION:-}" ] || command -v opencode >/dev/null 2>&1; then
  oc_present="yes"
fi
oc_ver=""
if [ -n "${WS_MAINTENANCE_OPENCODE_VERSION:-}" ]; then
  oc_ver=$(printf '%s' "$WS_MAINTENANCE_OPENCODE_VERSION" | norm_ver)
elif command -v opencode >/dev/null 2>&1; then
  oc_ver=$(timeout 15 opencode --version 2>/dev/null | norm_ver)
fi
oc_major="${oc_ver%%.*}"
oc_line="unknown"
case "$oc_major" in
  ''|*[!0-9]*) ;;
  1) oc_line="1.x" ;;
  *) [ "$oc_major" -ge 2 ] && oc_line="2.x" ;;
esac

npm_1x=""
if [ -n "${WS_MAINTENANCE_NPM_1X_VERSION:-}" ]; then
  npm_1x=$(printf '%s' "$WS_MAINTENANCE_NPM_1X_VERSION" | norm_ver)
elif command -v npm >/dev/null 2>&1; then
  npm_1x=$(timeout 20 npm view opencode-ai version 2>/dev/null | norm_ver)
fi
npm_2x=""
if [ -n "${WS_MAINTENANCE_NPM_2X_VERSION:-}" ]; then
  npm_2x=$(printf '%s' "$WS_MAINTENANCE_NPM_2X_VERSION" | norm_ver)
elif command -v npm >/dev/null 2>&1; then
  npm_2x=$(timeout 20 npm view @opencode/cli version 2>/dev/null | norm_ver)
fi

oc_behind="no"
if [ -z "$oc_ver" ]; then
  if [ "$oc_present" = "yes" ]; then
    add_finding "OpenCode is installed, version unknown; its version could not be read"
  else
    add_finding "OpenCode is not installed; install it to run builders and reviews"
  fi
elif { [ -n "$npm_1x" ] && version_lt "$oc_ver" "$npm_1x"; } \
  || { [ -n "$npm_2x" ] && version_lt "$oc_ver" "$npm_2x"; }; then
  oc_behind="yes"
  add_finding "update OpenCode: installed $oc_ver is behind (1.x latest ${npm_1x:-unknown}, 2.x latest ${npm_2x:-unknown})"
fi
oc_installed_text="${oc_ver:-not installed}"
if [ -z "$oc_ver" ] && [ "$oc_present" = "yes" ]; then oc_installed_text="installed, version unknown"; fi

# --- Tools ----------------------------------------------------------------------------------------------
# Node's latest comes from nodejs.org's release index; the other tools have no cheap latest source, so their
# latest column stays blank rather than inventing a number.
node_ver=""
node_current=""
node_lts=""
node_index="${WS_MAINTENANCE_NODE_INDEX:-}"
if [ -z "$node_index" ] && command -v curl >/dev/null 2>&1; then
  node_index_tmp=$(mktemp)
  if timeout 20 curl -fsSL https://nodejs.org/dist/index.json -o "$node_index_tmp"; then
    node_index="$node_index_tmp"
  else
    node_index=""
  fi
fi
if [ -n "$node_index" ] && [ -f "$node_index" ]; then
  # Newest overall is the Current line; the update check follows newest entry still on the LTS line.
  node_current=$(jq -r '.[0].version // empty' "$node_index" 2>/dev/null | norm_ver)
  node_lts=$(jq -r '[.[] | select(.lts != null and .lts != false)][0].version // empty' "$node_index" 2>/dev/null | norm_ver)
fi
tools_rows=""
for tool in node npm git gh jq; do
  tool_ver=""; latest=""
  if command -v "$tool" >/dev/null 2>&1; then
    tool_ver=$(timeout 15 "$tool" --version 2>/dev/null | norm_ver)
  fi
  [ "$tool" = node ] && latest="$node_lts"
  [ "$tool" = node ] && node_ver="$tool_ver"
  tools_rows+="| $tool | ${tool_ver:-not installed} | ${latest:--} |"$'\n'
done
if [ -n "$node_ver" ] && [ -n "$node_lts" ] && version_lt "$node_ver" "$node_lts"; then
  add_finding "update Node: installed $node_ver is behind the latest LTS $node_lts"
fi
node_note=""
if [ -n "$node_current" ]; then
  node_note="Node's newest Current release is $node_current (a note; the update check uses the newest LTS, ${node_lts:-unknown})."
fi

# --- Models ---------------------------------------------------------------------------------------------
models_file="${WS_MAINTENANCE_MODELS:-}"
models_unavailable=""
if [ -n "$models_file" ] && [ ! -f "$models_file" ]; then
  die "model list not found: $models_file"
fi
if [ -z "$models_file" ] && command -v opencode >/dev/null 2>&1; then
  models_tmp=$(mktemp)
  # A 2.x first start migrates and locks the shared data directory; a probe of its model list runs against a
  # throwaway one. Only a known 1.x reads the real dir, since that is what it already does; any other line,
  # including an unreadable version, gets the throwaway.
  if [ "$oc_line" != "1.x" ]; then
    xdg_tmp=$(mktemp -d)
    XDG_DATA_HOME="$xdg_tmp" timeout 60 opencode models > "$models_tmp" 2>/dev/null
    probe_rc=$?
  else
    timeout 60 opencode models > "$models_tmp" 2>/dev/null
    probe_rc=$?
  fi
  case "$probe_rc" in
    0) ;;
    124) models_unavailable="opencode models timed out" ;;
    *) models_unavailable="opencode models exited $probe_rc" ;;
  esac
  if [ -z "$models_unavailable" ] && ! grep -q '[^[:space:]]' "$models_tmp"; then
    models_unavailable="opencode models returned an empty list"
  fi
  models_file="$models_tmp"
elif [ -z "$models_file" ]; then
  models_unavailable="opencode is not on PATH"
fi
if [ -z "$models_unavailable" ] && [ -n "$models_file" ] && ! grep -q '[^[:space:]]' "$models_file"; then
  models_unavailable="the model list is empty"
fi

used_keys=(); used_displays=(); used_entries=()
if [ "${#WS_OPENCODE_MODEL_NAMES[@]}" -gt 0 ]; then
  for entry in "${WS_OPENCODE_MODEL_NAMES[@]}"; do
    key="${entry%%=*}"
    display="${entry#*=}"
    [ "$display" = "$entry" ] && display="$key"
    used_keys+=("$key"); used_displays+=("$display"); used_entries+=("$key")
  done
fi
allowance_entries=()
read -r -a allowance_entries <<< "${WS_ALLOWANCE_LIMITS:-}"
for entry in "${allowance_entries[@]}"; do
  [ -n "$entry" ] || continue
  key="${entry%%=*}"
  used_entries+=("$key")
done
# A model named by both WS_OPENCODE_MODEL_NAMES and WS_ALLOWANCE_LIMITS is one pin, not two.
declare -A pin_seen=()
pin_keys=()
for key in "${used_entries[@]}"; do
  [ -n "$key" ] || continue
  [ -n "${pin_seen[$key]:-}" ] && continue
  pin_seen[$key]=1
  pin_keys+=("$key")
done

models_rows=""
added=""; removed=""
snapshot="$WS/runs/models.snapshot"
if [ -n "$models_unavailable" ]; then
  add_finding "model list unavailable: $models_unavailable"
  models_rows+="| - | model list unavailable | |"$'\n'
elif [ -n "$models_file" ] && [ -f "$models_file" ]; then
  current_raw=$(mktemp); current_sorted=$(mktemp); base_sorted=$(mktemp)
  sed '/^[[:space:]]*$/d' "$models_file" | LC_ALL=C sort -u > "$current_raw"
  cp "$current_raw" "$current_sorted"
  if [ -f "$snapshot" ]; then
    sed -e '/^#/d' -e '/^[[:space:]]*$/d' "$snapshot" | LC_ALL=C sort -u > "$base_sorted"
  else
    # The run that creates the snapshot has no earlier list to compare with, so the current list is its own
    # baseline: nothing is added and every model is not new on a first run.
    cp "$current_sorted" "$base_sorted"
    mkdir -p "$WS/runs"
    partial="$snapshot.tmp.$$"
    { printf '# ws models snapshot %s\n' "$(now_local)"; cat "$current_sorted"; } > "$partial" \
      && mv -f "$partial" "$snapshot"
    note "models: no snapshot existed; wrote ${snapshot#"$WS"/}"
  fi
  added=$(LC_ALL=C comm -13 "$base_sorted" "$current_sorted")
  removed=$(LC_ALL=C comm -23 "$base_sorted" "$current_sorted")

  while IFS= read -r model; do
    [ -n "$model" ] || continue
    if is_free "$model"; then
      models_rows+="| added | $model | free |"$'\n'
      add_finding "new free model $model is listed; check its privacy row and whether it is a candidate"
    else
      models_rows+="| added | $model | |"$'\n'
    fi
  done <<< "$added"
  while IFS= read -r model; do
    [ -n "$model" ] || continue
    models_rows+="| removed | $model | |"$'\n'
  done <<< "$removed"

  # A pin missing from the list is retired only when the snapshot had it; otherwise it was never listed.
  for key in "${pin_keys[@]}"; do
    [ -n "$key" ] || continue
    if ! grep -Fxq "$key" "$current_sorted"; then
      if grep -Fxq "$key" "$base_sorted"; then
        add_finding "retired pin: $key disappeared from the model list"
      else
        add_finding "pin: $key is not in the current model list"
      fi
    fi
  done
else
  models_rows+="| - | no model list available | |"$'\n'
fi
[ -n "$models_rows" ] || models_rows+="| - | no change | |"$'\n'

# --- Privacy ---------------------------------------------------------------------------------------------
go_page="${WS_MAINTENANCE_GO_PAGE:-}"
zen_page="${WS_MAINTENANCE_ZEN_PAGE:-}"
# A fetched page also refreshes zdr-check's cache, so the weekly check keeps the cache current.
mkdir -p "$WS/runs"
if [ -z "$go_page" ] && command -v curl >/dev/null 2>&1; then
  go_tmp=$(mktemp)
  if timeout 20 curl -fsSL https://opencode.ai/docs/go -o "$go_tmp"; then
    go_page="$go_tmp"; cp "$go_tmp" "$WS/runs/zdr-page-go.html"
  else go_page=""; fi
fi
if [ -z "$zen_page" ] && command -v curl >/dev/null 2>&1; then
  zen_tmp=$(mktemp)
  if timeout 20 curl -fsSL https://opencode.ai/docs/zen -o "$zen_tmp"; then
    zen_page="$zen_tmp"; cp "$zen_tmp" "$WS/runs/zdr-page-zen.html"
  else zen_page=""; fi
fi

privacy_rows=""
free_zero=()
if [ -z "$go_page" ] && [ -z "$zen_page" ]; then
  add_finding "privacy pages unavailable; no model's training or retention could be checked"
else
  spec=$(mktemp); privacy_tsv=$(mktemp)
  declare -A spec_seen=() display_seen=()
  for i in "${!used_keys[@]}"; do
    key="${used_keys[$i]}"; display="${used_displays[$i]}"
    [ -n "${spec_seen[$key]:-}" ] && continue
    spec_seen[$key]=1
    display_seen[$display]=1
    printf '%s\t%s\t0\n' "$key" "$display" >> "$spec"
  done
  if [ -n "$models_file" ] && [ -f "$current_raw" ]; then
    while IFS= read -r model; do
      [ -n "$model" ] || continue
      model_id=$(printf '%s' "$model" | sed 's/ *\[free\]$//')
      is_free "$model" || continue
      [ -n "${spec_seen[$model_id]:-}" ] && continue
      # Two providers can carry the same model; the page names it once, so one row is enough.
      free_display=$(model_display_name "$model_id")
      [ -n "${display_seen[$free_display]:-}" ] && continue
      spec_seen[$model_id]=1
      display_seen[$free_display]=1
      printf '%s\t%s\t1\n' "$model_id" "$free_display" >> "$spec"
    done < "$current_raw"
  fi
  parser_ok=0
  if python3 -I - "go=${go_page}" "zen=${zen_page}" "$spec" > "$privacy_tsv" <<'PY'
import html, re, sys

def text(path):
    with open(path, encoding="utf-8", errors="replace") as handle:
        raw = handle.read()
    return html.unescape(re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", raw)))

pages = []
for item in (sys.argv[1], sys.argv[2]):
    label, _, path = item.partition("=")
    if not path:
        continue
    try:
        pages.append((label, text(path)))
    except OSError:
        pass

ZEN_PASS = "follows a zero-retention policy and does not use your data for model training"

def zen_row(name, body):
    # The live Zen page lists free models as prose list items: the item names the model and the clause after it
    # states the provider's retention and training terms. Judge every sentence naming the model with its provider
    # clause, which is its own sentence when one item carries both.
    # A model id spells a name with hyphens while the page may use spaces; either separator matches.
    prose = re.compile(
        r"(?<![\w.-])" + r"[-\s]+".join(re.escape(part) for part in re.split(r"[-\s]+", name)) + r"(?![\w.-])",
        re.IGNORECASE,
    )
    sentences = re.split(r"(?<=[.!?])\s+", body)
    passage = None
    for i, sentence in enumerate(sentences):
        if not prose.search(sentence):
            continue
        candidate = sentence
        # The privacy clause is the item's next sentence when that sentence continues the provider's terms;
        # another model's item must not lend its terms to this one.
        if i + 1 < len(sentences) and re.match(r"(?i)(its|the) provider\b", sentences[i + 1]):
            candidate += " " + sentences[i + 1]
        if ZEN_PASS in candidate:
            return ("Not used", "0 days")
        if passage is None:
            passage = candidate
    if passage is None:
        return None
    days = re.search(r"(\d+) days", passage)
    return ("Yes", f"{days.group(1)} days" if days else "Not ZDR")

spec = [line.rstrip("\n").split("\t") for line in open(sys.argv[3], encoding="utf-8") if line.strip()]
for row in spec:
    key, display, free = row[0], row[1], row[2]
    candidates = []
    for candidate in (display, key, key.rsplit("/", 1)[-1]):
        if candidate and candidate not in candidates:
            candidates.append(candidate)
    found = None
    for name in candidates:
        # The page's capitalization is not derivable from an id ("Deepseek" for "DeepSeek", "Longcat" for "LongCat"),
        # so a name is matched without regard to case.
        pattern = re.compile(re.escape(name) + r" (Not used|Yes) (0 days|Not ZDR|\d+ days)(\*?)", re.IGNORECASE)
        for label, body in pages:
            match = pattern.search(body)
            if match:
                found = (label, match.group(1), match.group(2))
                break
        if found:
            break
        for label, body in pages:
            terms = zen_row(name, body) if label == "zen" else None
            if terms:
                found = (label, terms[0], terms[1])
                break
        if found:
            break
    if found:
        label, training, retention = found
        print("\t".join((key, display, free, label, training, retention)))
    else:
        print("\t".join((key, display, free, "-", "-", "-")))
PY
  then
    parser_ok=1
  fi
  if [ "$parser_ok" -eq 0 ]; then
    add_finding "privacy parser failed; no model's training or retention could be checked"
  elif [ -s "$spec" ] && ! grep -q '[^[:space:]]' "$privacy_tsv"; then
    add_finding "privacy parser returned no rows; no model's training or retention could be checked"
    parser_ok=0
  fi

  prev_report=""
  if [ -f "$report" ]; then
    prev_report="$report"
  else
    for f in "$WS"/reports/maintenance-*.md; do
      [ -f "$f" ] || continue
      if [ -z "$prev_report" ] || [ "$f" -nt "$prev_report" ]; then prev_report="$f"; fi
    done
  fi
  prev_row() { # <report> <display>
    if [ -z "$1" ] || [ ! -f "$1" ]; then return 0; fi
    awk -F'|' -v name="$2" '
      function trim(s) { gsub(/^[ \t]+/, "", s); gsub(/[ \t]+$/, "", s); return s }
      /^\|/ { if (trim($2) == name) { print trim($3) "\t" trim($4); exit } }
    ' "$1"
  }
  if [ "$parser_ok" -eq 1 ]; then
    while IFS=$'\t' read -r key display free page training retention; do
      if [ "$page" = "-" ]; then
        if [ "$free" = 0 ]; then
          add_finding "used model $display has no privacy row on the Go or Zen page"
        fi
        continue
      fi
      privacy_rows+="| $display | $training | $retention | $page |"$'\n'
      if [ "$free" = 0 ]; then
        prev=$(prev_row "$prev_report" "$display")
        if [ -n "$prev" ]; then
          prev_training="${prev%%$'\t'*}"
          prev_retention="${prev#*$'\t'}"
          if [ "$prev_training" != "$training" ] || [ "$prev_retention" != "$retention" ]; then
            add_finding "privacy row for $display changed since the previous report: $prev_training/$prev_retention -> $training/$retention"
          fi
        fi
      elif [ "$training" = "Not used" ] && [ "$retention" = "0 days" ]; then
        free_zero+=("$display")
      fi
    done < "$privacy_tsv"
  fi
fi
[ -n "$privacy_rows" ] || privacy_rows="| - | - | - | - |"$'\n'

# --- Pins -----------------------------------------------------------------------------------------------
pins_rows=""
if [ -n "${WS_MIN_OPENCODE:-}" ]; then
  min_oc=$(printf '%s' "$WS_MIN_OPENCODE" | norm_ver)
  if [ -n "$oc_ver" ] && [ -n "$min_oc" ] && version_lt "$oc_ver" "$min_oc"; then
    pins_rows+="| WS_MIN_OPENCODE | $min_oc | installed $oc_ver is below it |"$'\n'
  else
    pins_rows+="| WS_MIN_OPENCODE | $min_oc | installed ${oc_ver:-unknown} is not below it |"$'\n'
  fi
fi
for key in "${pin_keys[@]}"; do
  [ -n "$key" ] || continue
  if [ -n "$models_unavailable" ]; then
    pins_rows+="| $key | model list unavailable | not checked |"$'\n'
  elif [ -n "$models_file" ] && [ -f "$current_sorted" ] && grep -Fxq "$key" "$current_sorted"; then
    pins_rows+="| $key | in the model list | ok |"$'\n'
  else
    pins_rows+="| $key | not in the model list | retired or missing |"$'\n'
  fi
done
[ -n "$pins_rows" ] || pins_rows="| - | - | - |"$'\n'

# --- Claude path ----------------------------------------------------------------------------------------
claude_state="absent"; claude_ver=""
if command -v claude >/dev/null 2>&1; then
  claude_state="present"
  claude_ver=$(timeout 15 claude --version 2>/dev/null | norm_ver)
fi
claude_rows="| claude on PATH | $claude_state |
| claude version | ${claude_ver:--} |
| WS_CLAUDE_DAY_CAP | ${WS_CLAUDE_DAY_CAP:-empty} |
| WS_REVIEW_AGENT | ${WS_REVIEW_AGENT:-empty (auto)} |"
if [ "$claude_state" = absent ]; then
  claude_roles=""
  [ "${WS_AGENT:-}" = claude ] && claude_roles="WS_AGENT"
  [ "${WS_REVIEW_AGENT:-}" = claude ] && claude_roles="${claude_roles:+$claude_roles and }WS_REVIEW_AGENT"
  if [ -n "$claude_roles" ]; then
    add_finding "claude is not on PATH but $claude_roles needs it"
  fi
fi

# --- Report ---------------------------------------------------------------------------------------------
mkdir -p "$(dirname "$report")" || die "cannot create $(dirname "$report")"
tmp_report="$report.tmp.$$"
{
  echo "# Maintenance report $(now_local)"
  echo
  echo "## Needs a decision"
  if [ "${#findings[@]}" -eq 0 ]; then
    echo "- none"
  else
    for finding in "${findings[@]}"; do printf -- '- %s\n' "$finding"; done
  fi
  echo
  echo "## OpenCode"
  echo
  echo "| item | value |"
  echo "| --- | --- |"
  echo "| installed | $oc_installed_text |"
  echo "| installed line | $oc_line |"
  echo "| latest 1.x (opencode-ai) | ${npm_1x:-unknown} |"
  echo "| latest 2.x (@opencode/cli) | ${npm_2x:-unknown} |"
  echo "| behind | $oc_behind |"
  echo
  echo "## Tools"
  echo
  echo "| tool | installed | latest |"
  echo "| --- | --- | --- |"
  printf '%s' "$tools_rows"
  if [ -n "$node_note" ]; then
    echo
    echo "$node_note"
  fi
  echo
  echo "## Models"
  echo
  echo "| change | model | note |"
  echo "| --- | --- | --- |"
  printf '%s' "$models_rows"
  echo
  echo "## Privacy"
  echo
  echo "| model | training | retention | source |"
  echo "| --- | --- | --- | --- |"
  printf '%s' "$privacy_rows"
  if [ "${#free_zero[@]}" -gt 0 ]; then
    echo
    printf 'Free models with no training and 0 days: %s\n' "$(printf '%s\n' "${free_zero[@]}" | paste -sd ',' - | sed 's/,/, /g')"
  fi
  echo
  echo "## Pins"
  echo
  echo "| pin | value | state |"
  echo "| --- | --- | --- |"
  printf '%s' "$pins_rows"
  echo
  echo "## Claude path"
  echo
  echo "| item | value |"
  echo "| --- | --- |"
  printf '%s\n' "$claude_rows"
} > "$tmp_report" || die "cannot write $tmp_report"
mv -f "$tmp_report" "$report" || die "cannot replace $report"
tmp_report=""

mkdir -p "$WS/runs"
printf '%s\n' "$(now_local)" > "$WS/runs/maintenance.last" || die "cannot write runs/maintenance.last"

if [ "${#findings[@]}" -eq 0 ]; then echo "maintenance: no drift"; fi
for finding in "${findings[@]}"; do printf 'maintenance: %s\n' "$finding"; done
echo "maintenance: report ${report#"$WS"/}"
exit 0
