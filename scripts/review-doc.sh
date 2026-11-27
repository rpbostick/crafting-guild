#!/usr/bin/env bash
# A fresh-context review of a research document against its own evidence: its claim table (or manifest), its
# sources index and its workbook. This is scripts/review.sh's document mode: the same OpenCode two-pass runner, the
# same verdict JSON and the same record files, without teeth and without a merge.
# Usage: review-doc.sh [--project slug] [--budget USD] [--model provider/model] [--variant <name>]
#                      [--passes N] [--workbook <file.xlsx>] [--sources <sources.tsv>] [--print-prompt] <doc.md>
# The record is runs/<slug>/<name>.review-doc.{json,md}; <name> is the document's file name, slugified, plus a short
# digest of its absolute path, so two documents with one file name keep separate records. Every record carries the
# document's path and SHA-256: a rewritten document is a new review, and the review it replaces is kept beside it
# under rounds/.
# Exit: 0 clean (verdict merge), 1 blocking (fix-first or do-not-merge), 2 a meter or tool failure (a config that
# cannot be built, a digest that cannot be read, a pass union that fails, or a run past its budget).
set -uo pipefail
. "$(dirname "$0")/lib.sh"
# A tool failure exits 2: the review found nothing to say about the document because a part of the tooling failed,
# which is neither a clean document nor a blocking one.
tool_die() { echo "ws: $*" >&2; exit 2; }
# The document's identity is read from disk, so a digest that cannot be read is a tool failure, not a verdict.
digest_value=""
digest_of() { # <path>: sets digest_value; false when the file cannot be read
  digest_value=$(sha256sum "$1" 2>/dev/null | cut -d' ' -f1)
  [ -n "$digest_value" ]
}
slug="" budget="$WS_REVIEW_BUDGET" model="${WS_OPENCODE_MODEL:-}" variant="" passes="" passes_flag=""
doc="" workbook="" sources="" show_prompt=false
while [ $# -gt 0 ]; do case "$1" in
  --project) slug="$2"; shift 2 ;; --budget) budget="$2"; shift 2 ;;
  --model) model="$2"; shift 2 ;; --variant) variant="$2"; shift 2 ;;
  --passes) passes="$2"; passes_flag=1; shift 2 ;;
  --workbook) workbook="$2"; shift 2 ;; --sources) sources="$2"; shift 2 ;;
  --print-prompt) show_prompt=true; shift ;;
  -*) die "unknown flag $1" ;;
  *) [ -z "$doc" ] || die "review-doc takes one document, not '$doc' and '$1'"; doc="$1"; shift ;;
esac; done
[ -n "$doc" ] || die "usage: ws review-doc <doc.md> [--workbook <file.xlsx>] [--sources <sources.tsv>] [--passes N]"
[ -f "$doc" ] || die "no document at $doc"
[ -z "$workbook" ] || [ -f "$workbook" ] || die "no workbook at $workbook"
[ -z "$sources" ] || [ -f "$sources" ] || die "no sources index at $sources"
if [ -z "$passes_flag" ]; then passes="${WS_REVIEW_PASSES:-1}"; fi
case "$passes" in 1|2|3) ;; *) die "--passes and WS_REVIEW_PASSES take 1, 2 or 3, not '$passes'" ;; esac
[ -n "$model" ] || die "no OpenCode model: set WS_OPENCODE_MODEL or pass --model provider/model"
case "$model" in */*) ;; *) die "--model takes a provider/model ID, not '$model'" ;; esac
load_project "$slug"
# Absolute paths: a 1.x review runs in the document's directory, a 2.x review runs from the workspace and reads the
# document by absolute path under its external-directory grant.
abs_dir() { (cd "$1" && pwd -P); }
doc_dir=$(abs_dir "$(dirname "$doc")") || die "cannot enter the directory of $doc"
doc="$doc_dir/$(basename "$doc")"
if [ -n "$workbook" ]; then
  wb_dir=$(abs_dir "$(dirname "$workbook")") || die "cannot enter the directory of $workbook"
  workbook="$wb_dir/$(basename "$workbook")"
fi
if [ -n "$sources" ]; then
  src_dir=$(abs_dir "$(dirname "$sources")") || die "cannot enter the directory of $sources"
  sources="$src_dir/$(basename "$sources")"
fi
# The document's identity: its path picks the record's name, its content digest says which text was reviewed.
digest_of "$doc" || tool_die "cannot read the document $doc"
doc_sha="$digest_value"
workbook_sha=""; [ -z "$workbook" ] || { digest_of "$workbook" || tool_die "cannot read the workbook $workbook"; workbook_sha="$digest_value"; }
sources_sha=""; [ -z "$sources" ] || { digest_of "$sources" || tool_die "cannot read the sources index $sources"; sources_sha="$digest_value"; }
base=$(basename "$doc"); base="${base%.markdown}"; base="${base%.md}"
name=$(printf '%s' "$base" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-' | sed 's/^-*//;s/-*$//')
[ -n "$name" ] || name=document
name="$name-$(printf '%s' "$doc" | sha256sum | cut -c1-8)"
note "document: $doc (sha256 $doc_sha)"
[ -z "$workbook" ] || note "workbook: $workbook (sha256 $workbook_sha)"
[ -z "$sources" ] || note "sources: $sources (sha256 $sources_sha)"
line=$(opencode_line)
doc_text=$(cat "$doc")
[ "${#doc_text}" -le 200000 ] || { doc_text="${doc_text:0:200000}"; note "the document is longer than 200 KB; the reviewer gets its first 200 KB and reads the rest from $doc"; }
sources_text=""
[ -z "$sources" ] || sources_text=$(cat "$sources")
[ "${#sources_text}" -le 40000 ] || sources_text="${sources_text:0:40000}"
# The workbook's rows go into the prompt as text: the reviewer has no shell and no interpreter, so this dump is all
# it can recompute from. The dump is capped, and a cut dump says so in the prompt and in the record: a reviewer told
# it has every row when the dump holds a fraction of them would pass a figure it never saw. A workbook that cannot be
# read is a tool failure.
dump_row_count() { awk 'NF && $0 !~ /^## Sheet: / && index($0, "(stopped after ") == 0 { n++ } END { print n+0 }'; }
dump_sheet_count() { awk '/^## Sheet: / { n++ } END { print n+0 }'; }
workbook_text=""
workbook_dump_cap=60000
wb_dump_bytes=0; wb_dump_kept_bytes=0; wb_dump_rows_kept=0; wb_dump_rows_total=0
wb_dump_sheets=0; wb_dump_cut=false; wb_dump_stopped_in=""
wb_dump_note=""
if [ -n "$workbook" ]; then
  wb_err=$(mktemp) || { echo "review-doc: cannot make a temporary file" >&2; exit 2; }
  if ! workbook_text=$(python3 -I "$WS/scripts/xlsx_dump.py" "$workbook" 2>"$wb_err"); then
    echo "review-doc: cannot read the workbook $workbook: $(head -1 "$wb_err" 2>/dev/null || echo "no output")" >&2
    rm -f "$wb_err"
    exit 2
  fi
  rm -f "$wb_err"
  wb_dump_bytes=${#workbook_text}
  wb_dump_kept_bytes=$wb_dump_bytes
  wb_dump_rows_total=$(dump_row_count <<< "$workbook_text")
  wb_dump_rows_kept=$wb_dump_rows_total
  wb_dump_sheets=$(dump_sheet_count <<< "$workbook_text")
  if [ "$wb_dump_bytes" -gt "$workbook_dump_cap" ]; then
    wb_dump_cut=true
    wb_dump_full="$workbook_text"
    # Keep whole rows: a row cut in half would read as a value the reviewer could recompute against.
    workbook_text="${workbook_text:0:$workbook_dump_cap}"
    case "$workbook_text" in *$'\n'*) workbook_text="${workbook_text%$'\n'*}" ;; esac
    [ -n "$workbook_text" ] || workbook_text="${wb_dump_full:0:$workbook_dump_cap}"
    wb_dump_kept_bytes=${#workbook_text}
    wb_dump_rows_kept=$(dump_row_count <<< "$workbook_text")
    wb_dump_stopped_in=$(awk '/^## Sheet: / { name = $0 } END { print name }' <<< "$workbook_text" | sed 's/^## Sheet: //')
    wb_dump_note="The workbook dump below is cut: it holds the first $wb_dump_rows_kept of $wb_dump_rows_total rows across $wb_dump_sheets worksheets, and it stops inside sheet \"$wb_dump_stopped_in\". Rows after that, and any later sheet, are not shown. A figure that depends on one of them cannot be checked from this prompt and is blocking: say which row is missing rather than passing it."
    note "the workbook dump is longer than $workbook_dump_cap bytes; the reviewer gets $wb_dump_rows_kept of $wb_dump_rows_total rows, stopping inside sheet $wb_dump_stopped_in (the prompt and the record say so)"
  fi
fi
workbook_label=${workbook:-(none given)}
sources_label=${sources:-(none given)}
[ -z "$workbook" ] || workbook_label="$workbook (sha256 $workbook_sha)"
[ -z "$sources" ] || sources_label="$sources (sha256 $sources_sha)"
workbook_rows=${workbook_text:-(no workbook was given; recompute a table figure from the claim table inputs and say so)}
[ -z "$wb_dump_note" ] || workbook_rows="$wb_dump_note

$workbook_rows"
sources_block=${sources_text:-(no sources index was given; check a claim against whatever file the document names beside it)}
prompt="You are a fresh-context reviewer of a research document for project $SLUG. You did not write this document and you have no stake in it: check its claims against the evidence the document itself names, and answer with the JSON verdict.

# The four checks
For every claim in the document's claim table (or its audit manifest, a file or section it names), and for every figure in its prose:
1. **Does the cited source say this?** Quote the sentence of the source that supports the claim, or say it does not. The source index below gives each source's id, URL, digest, title and what it evidences; the source files saved beside it hold the text. A source that is silent, says something narrower, or contradicts the claim is blocking.
2. **Is the denominator named?** A rate must be over a declared group (\"of the 62 biographies with declared education\", \"of the 100 sampled\"), never over everyone or an unstated group. A rate whose denominator is missing or implied to be everyone is blocking.
3. **Does the arithmetic reproduce?** Recompute every number that comes from a table or the workbook from its inputs, doing the arithmetic yourself from the rows dumped below. State the inputs, the recomputation and the stored value. A row whose value does not follow from its inputs is blocking, and so is a figure that depends on a workbook row the dump does not carry.
4. **Is a prose figure missing from the claim table?** Any figure in the prose that the claim table does not carry cannot be checked, and is blocking.

A document with no claim table and no manifest cannot be checked at all: say that once, as blocking.

You have no shell and no interpreter: read the files you need with the read tool, work the arithmetic out yourself from the rows shown, write no file and fetch nothing. There is no network.

# Document
Path: $doc
SHA-256: $doc_sha
Workbook: $workbook_label
Sources index: $sources_label

## The document
$doc_text

## The workbook's rows
$workbook_rows

## Sources index
$sources_block

# The verdict
Answer with one JSON object and nothing else:
{\"verdict\": \"merge\" | \"fix-first\" | \"do-not-merge\", \"summary\": \"one paragraph\", \"blocking\": [{\"file\": \"<document path>\", \"line\": <line in the document>, \"rule\": 1, \"why\": \"the finding, quoting the source and the claim\"}], \"suggestions\": [{\"file\": \"<document path>\", \"line\": <line>, \"why\": \"...\"}]}
\`merge\` when every claim passes all four checks; \`fix-first\` when a claim fails but the document can be corrected; \`do-not-merge\` when its evidence does not support it. \`blocking\` and \`suggestions\` are always arrays: write \`[]\`, never \`false\` or \`true\`. \`file\` is the document's path, \`line\` its line in the document file, \`rule\` the number of the check above, and \`why\` carries the finding text. Suggestions carry a \`file\`, a \`line\` and a \`why\`."
if $show_prompt; then printf '%s\n' "$prompt"; exit 0; fi
out="$RUNS/$name.review-doc.json"; errf="$RUNS/$name.review-doc.err"; mdf="$RUNS/$name.review-doc.md"
oc_config="$RUNS/$name.review-doc.opencode.json"
oc_prompt="$RUNS/$name.review-doc-prompt.txt"
# The result lines a client wrote into a raw log; grep -a keeps a log whose truncation left NUL bytes from reading as a
# binary match, and fromjson? drops a line a partial or interleaved write left unparsable.
review_result_lines() { tr -d '\000' < "$1" 2>/dev/null | grep -a '"type":"result"' | jq -R -c 'fromjson? // empty' 2>/dev/null; }
review_last_result_line() { review_result_lines "$1" | tail -1; }
review_structured_output() { review_result_lines "$1" | jq -c 'select(.structured_output != null) | .structured_output' 2>/dev/null | tail -1; }
# One review pass, logged to <raw> and <err>. A retry names the attempt it repeats in <earlier raw>, newest first;
# the review is taken from the first log that holds one, so a retry that wrote nothing usable does not throw away the
# attempt's review. Sets so (the structured review), result_line and pass_cost; returns 2 after printing why when no
# log gave a review.
run_pass() { # <raw> <err> <config> <prompt> [<earlier raw>...]
  local raw="$1" err="$2" cfg="$3" pf="$4" r rs
  local -a cmd raws
  raws=("$raw"); shift 4; raws+=("$@")
  result_line=""; so=""
  # Read-only and no shell at all: the reviewer recomputes from the rows in its prompt, so an interpreter that could
  # open a socket is not needed for the "no network" promise to hold. A 2.x review runs from the workspace, so its
  # config grants read access to the document's directory (and the workbook's and index's, when they sit elsewhere)
  # as external directories.
  local -a cfg_args=(--read-only --no-shell --line "$line")
  if [ "$line" = 2 ]; then
    cfg_args+=(--directory "$doc_dir")
    [ -z "$workbook" ] || cfg_args+=(--directory "$(dirname "$workbook")")
    [ -z "$sources" ] || cfg_args+=(--directory "$(dirname "$sources")")
  fi
  python3 -I "$WS/scripts/opencode_run.py" config "${cfg_args[@]}" > "$cfg" || tool_die "could not build the OpenCode document-review config"
  printf '%s\n' "$prompt" > "$pf"
  cmd=("$WS/scripts/opencode-review.sh" --model "$model" --budget "$budget" --config "$cfg"
    --log "$raw" --name "ws:$SLUG:review-doc:$name")
  [ -n "$variant" ] && cmd+=(--variant "$variant")
  cmd+=("$pf")
  ( cd "$doc_dir" && timeout --kill-after=30s 30m "${cmd[@]}" ) < /dev/null > "$raw" 2>"$err" || true
  for r in "${raws[@]}"; do
    [ -f "$r" ] || continue
    rs=$(review_structured_output "$r")
    if [ -n "$rs" ]; then so="$rs"; result_line=$(review_last_result_line "$r"); break; fi
    [ -n "$result_line" ] || result_line=$(review_last_result_line "$r")
  done
  if [ -z "$so" ] || [ "$so" = "null" ]; then
    echo "review-doc failed: $(printf '%s' "$result_line" | jq -r '.result // .subtype // "no output"' 2>/dev/null | head -c 300)"
    tail -n 5 "$err"
    return 2
  fi
  pass_cost=$(printf '%s' "$result_line" | jq -r '.total_cost_usd // "?"' 2>/dev/null)
}
# One pass in its own subshell: it writes its record, then leaves its cost and status in files keyed by the pass, so
# passes share no state and can run at the same time.
run_pass_job() { # <i> <status file> <cost file> <raw> <err> <config> <prompt> [<earlier raw>...]
  local i="$1" status="$2" costf="$3" pass_out
  pass_out="${out%.json}.pass$i.json"
  run_pass "$4" "$5" "$6" "$7" "${@:8}" || { echo "fail" > "$status"; return 2; }
  jq -n --arg doc "$doc" --arg sha "$doc_sha" --arg when "$(now_local)" --argjson r "$so" \
    '{doc:$doc, doc_sha256:$sha, when:$when} + $r' > "$pass_out" || { echo "fail" > "$status"; return 2; }
  printf '%s\n' "$pass_cost" > "$costf"
  echo ok > "$status"
}
if [ "$passes" -eq 1 ]; then
  run_pass "$out.raw" "$errf" "$oc_config" "$oc_prompt" || exit 2
  cost="$pass_cost"
else
  pass_pids=()
  for i in $(seq 1 "$passes"); do
    pass_out="${out%.json}.pass$i.json"
    status="${out%.json}.pass$i.status"; costf="${out%.json}.pass$i.cost"
    : > "$status"; : > "$costf"
    ( run_pass_job "$i" "$status" "$costf" "$pass_out.raw" "${errf%.err}.pass$i.err" \
        "${oc_config%.json}.pass$i.json" "${oc_prompt%.txt}.pass$i.txt" ) >> "${errf%.err}.pass$i.err" 2>&1 &
    pass_pids+=($!)
  done
  for pid in "${pass_pids[@]}"; do wait "$pid" || true; done
  # A pass that dies on a transient OpenCode server error is retried once, after the other passes finish. The retry
  # writes its own raw and err files: a retried attempt's log may still be open and must not be truncated under it.
  if [ "${WS_REVIEW_PASS_RETRY:-1}" -gt 0 ]; then
    for i in $(seq 1 "$passes"); do
      status="${out%.json}.pass$i.status"
      [ "$(cat "$status" 2>/dev/null)" != ok ] || continue
      attempt_raw="${out%.json}.pass$i.json.raw"
      retry_raw="${out%.json}.pass$i.retry1.json.raw"
      retry_err="${errf%.err}.pass$i.retry1.err"
      note "pass $i failed; retrying it once (raw: ${retry_raw#"$RUNS/"}; err: ${retry_err#"$RUNS/"})"
      sleep "${WS_REVIEW_PASS_RETRY_DELAY:-5}"
      : > "$status"
      run_pass_job "$i" "$status" "${out%.json}.pass$i.cost" "$retry_raw" "$retry_err" \
        "${oc_config%.json}.pass$i.json" "${oc_prompt%.txt}.pass$i.txt" "$attempt_raw" >> "$retry_err" 2>&1 || true
    done
  fi
  failed=0
  for i in $(seq 1 "$passes"); do
    if [ "$(cat "${out%.json}.pass$i.status" 2>/dev/null)" != ok ]; then
      echo "pass $i of $passes failed; no union written"
      grep -h -m1 '^review-doc failed:' "${errf%.err}.pass$i.err" "${errf%.err}.pass$i".retry*.err 2>/dev/null | head -1 || true
      failed=1
    fi
  done
  [ "$failed" = 0 ] || exit 2
  union_args=()
  for i in $(seq 1 "$passes"); do
    pass_out="${out%.json}.pass$i.json"
    union_args+=("$pass_out" "$(cat "${out%.json}.pass$i.cost")")
    note "pass $i of $passes: $(jq -r '.verdict' "$pass_out"), $(jq '.blocking | length' "$pass_out") blocking"
  done
  so=$(python3 -I "$WS/scripts/review_match.py" union "${union_args[@]}") || tool_die "could not union the $passes document-review passes"
  cost=$(jq -r '.total_cost_usd' <<< "$so")
fi
# A meter failure is not a verdict: a run that cost past its budget is reported as a tool failure (exit 2), so an
# over-budget stop cannot read as a clean document or a blocking one.
if [ "$passes" -eq 1 ]; then cost_limit="$budget"; else cost_limit=$(jq -rn --argjson b "$budget" --argjson n "$passes" '$b * $n'); fi
case "$cost" in
  ''|*[!0-9.]*) ;;
  *) if jq -en --argjson c "$cost" --argjson l "$cost_limit" '$c > $l' >/dev/null 2>&1; then
       echo "review-doc: the run cost \$$cost, over the \$$cost_limit allowed; no verdict is trusted" >&2
       exit 2
     fi ;;
esac
[ ! -f "$out" ] || keep_review_round "$out" "$mdf"
# What the reviewer was given of the workbook, in the record too: a cut dump is part of the review's evidence.
wb_dump_json=$(jq -n --argjson cap "$workbook_dump_cap" --argjson bytes "$wb_dump_bytes" \
  --argjson kept "$wb_dump_kept_bytes" --argjson cut "$wb_dump_cut" \
  --argjson rows_kept "$wb_dump_rows_kept" --argjson rows_total "$wb_dump_rows_total" \
  --argjson sheets "$wb_dump_sheets" --arg sheet "$wb_dump_stopped_in" \
  '{cap_bytes:$cap, total_bytes:$bytes, kept_bytes:$kept, cut:$cut, rows_kept:$rows_kept, rows_total:$rows_total, sheets:$sheets, stopped_in_sheet:$sheet}')
jq -n --arg doc "$doc" --arg sha "$doc_sha" --arg wb "$workbook" --arg wbsha "$workbook_sha" \
  --arg src "$sources" --arg srcsha "$sources_sha" --arg when "$(now_local)" --argjson passes "$passes" --argjson r "$so" \
  --argjson wbdump "$wb_dump_json" \
  '$r + {doc:$doc, doc_sha256:$sha, workbook:$wb, workbook_sha256:$wbsha, sources:$src, sources_sha256:$srcsha, when:$when, passes:$passes, workbook_dump:$wbdump}' > "$out"
verdict=$(jq -r '.verdict' "$out")
{
  echo "# Document review of $doc ($(now_local))"; echo
  echo "**Verdict: $verdict.** $(jq -r '.summary' "$out")"; echo
  echo "- document: $doc"; echo "- doc_sha256: $doc_sha"
  [ -z "$workbook" ] || echo "- workbook: $workbook (sha256 $workbook_sha)"
  if [ "$wb_dump_cut" = true ]; then
    echo "- workbook dump: cut at $workbook_dump_cap bytes: $wb_dump_rows_kept of $wb_dump_rows_total rows, stopping inside sheet \"$wb_dump_stopped_in\"; rows after that are not shown"
  fi
  [ -z "$sources" ] || echo "- sources: $sources (sha256 $sources_sha)"
  echo; echo "## Blocking"; jq -r '.blocking[] | "- \(.file):\(.line) (rule \(.rule)): \(.why)"' "$out"; [ "$(jq '.blocking|length' "$out")" -eq 0 ] && echo "- none"
  echo; echo "## Suggestions (carry forward, do not block)"; jq -r '.suggestions[] | "- \(.file):\(.line): \(.why)"' "$out"; [ "$(jq '.suggestions|length' "$out")" -eq 0 ] && echo "- none"
  echo; echo "cost=\$$cost  doc_sha256=$doc_sha"
} > "$mdf"
cat "$mdf"
# Same severities as ws review: only merge is clean; a blocking verdict is the caller's work, not a tool failure.
[ "$verdict" = "merge" ]
