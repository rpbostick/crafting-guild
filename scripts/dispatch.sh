#!/usr/bin/env bash
# Run one builder on one task, headless, in its own worktree on branch agent/<name>.
# Usage: dispatch.sh [--project slug] [--budget USD] [--model M] [--effort E] [--timeout 90m]
#                    [--temperature T] [--top-p P] [--allow "Bash(cmd *)"]... [--dry-run] [--print-prompt]
#                    [--names-ok] [--base <sha>] [--instructions <dir>] [--input <file>]...
#                    [--agent claude|opencode] <name> <task-file>
# --agent opencode runs the builder through scripts/opencode-builder.sh (default WS_AGENT); --model is then a
# provider/model ID, WS_OPENCODE_MODEL when not given. --effort is a model variant there (`opencode run --variant`),
# checked against `opencode models <provider> --verbose` before anything starts. --temperature and --top-p set the
# OpenCode build agent's sampling; Claude has no such settings and the flags are ignored with a warning there.
# --input copies a file the builder needs but cannot fetch or write (a data file, a prebuilt grid) into the
# worktree's .ws-evidence/ before the builder starts; the task names it there.
# --print-prompt is a dry run that also prints the builder's whole prompt.
# --base branches a fresh worktree from that commit instead of the main branch (a replay, ws bench); the builder
# then gets no grant to merge the main branch in, which would bring in the work the replay is measured on.
# --instructions takes the builder sheet from <dir>/agents/builder.md and the lessons from <dir>/lessons/ (builder.md,
# and builder.local.md when present), each where the directory has it, the workspace's otherwise. Every other file
# under <dir> is copied to the worktree's .ws-evidence/given/arm/ and the prompt names it.
# The builder gets: the builder sheet, lessons/builder.md (and builder.local.md), the task file, a grant to edit inside its
# worktree and commit on its branch plus the project's test command and EXTRA_TOOLS, a budget, a timeout,
# and a JSON result schema. Logs to runs/<slug>/<name>.jsonl; the result check lands in <name>.result.txt.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
slug="" budget="$WS_DEFAULT_BUDGET" model="$WS_MODEL" effort="$WS_EFFORT" tmo="" dry=false show_prompt=false names_ok=false from="" instr=""; extra=() inputs=()
temperature="" top_p=""; agent="$WS_AGENT" model_flag=false
while [ $# -gt 0 ]; do
  case "$1" in
    --project) slug="$2"; shift 2 ;;
    --budget) budget="$2"; shift 2 ;;
    --model) model="$2"; model_flag=true; shift 2 ;;
    --agent) agent="$2"; shift 2 ;;
    --effort) effort="$2"; shift 2 ;;
    --temperature) temperature="$2"; shift 2 ;;
    --top-p) top_p="$2"; shift 2 ;;
    --timeout) tmo="$2"; shift 2 ;;
    --allow) extra+=("$2"); shift 2 ;;
    --dry-run) dry=true; shift ;;
    --print-prompt) dry=true; show_prompt=true; shift ;;
    --names-ok) names_ok=true; shift ;;
    --base) from="$2"; shift 2 ;;
    --instructions) instr="$2"; shift 2 ;;
    --input) [ -f "$2" ] || die "no input file $2"; inputs+=("$2"); shift 2 ;;
    -*) die "unknown flag $1" ;;
    *) break ;;
  esac
done
name="${1:?usage: dispatch.sh [flags] <name> <task-file>}"; task="${2:?missing task file}"
[ $# -gt 2 ] && die "flags go before the name; ignored would be: ${*:3}"
case "$agent" in
  claude) ;;
  opencode) $model_flag || model="$WS_OPENCODE_MODEL"; case "$model" in */*) ;; *) die "--agent opencode takes a provider/model ID for --model, not '$model'" ;; esac ;;
  *) die "unknown agent '$agent' (claude or opencode)" ;;
esac
# OpenCode takes effort as a model variant. An unknown one fails here, with the model's list, rather than after
# OpenCode has started without the reasoning the caller asked for.
variant=""
if [ "$agent" = opencode ] && [ -n "$effort" ]; then
  if ! valid_variants=$(python3 -I "$WS/scripts/opencode_run.py" variants "$model" 2>&1); then
    die "cannot read the variants of $model for --effort '$effort': $valid_variants"
  fi
  [ -n "$valid_variants" ] || die "$model has no variants, so --effort '$effort' cannot be set"
  grep -qxF -- "$effort" <<< "$valid_variants" \
    || die "--effort '$effort' is not a variant of $model; valid: $(paste -sd ',' <<< "$valid_variants" | sed 's/,/, /g')"
  variant="$effort"
fi
[ -z "$temperature" ] || sampling_temperature --temperature "$temperature"
[ -z "$top_p" ] || sampling_top_p --top-p "$top_p"
if [ "$agent" = claude ] && [ -n "$temperature$top_p" ]; then
  ignored=""
  [ -n "$temperature" ] && ignored="--temperature"
  [ -n "$top_p" ] && ignored="${ignored:+$ignored and }--top-p"
  note "warning: Claude ignores $ignored; sampling applies only to --agent opencode"
fi
case "$name" in *[!A-Za-z0-9._-]*) die "bad name '$name'" ;; esac
task=$(ws_path "$task"); [ -f "$task" ] || die "no task file $task"
# Builders copy a task's wording into comments: tasks state requirements, not who asked or when.
if [ -n "${WS_ATTRIBUTION_RE:-}" ] && ! $names_ok; then
  hits=$(grep -niE "$WS_ATTRIBUTION_RE" "$task" | cut -c1-160 | head -5 || true)
  [ -z "$hits" ] || die "task $task attributes work to a person or to this process (first 5 below); state the requirement plainly, or pass --names-ok for a task that must quote the words (a scrub):
$hits"
fi
# Timeout follows the track unless --timeout was given: a light task gets the short cap.
if [ -z "$tmo" ]; then if grep -qi 'track: *light' "$task"; then tmo="$WS_LIGHT_TIMEOUT"; else tmo="$WS_DEFAULT_TIMEOUT"; fi; fi
# A bare number means minutes (coreutils timeout would read it as seconds: --timeout 180 once killed a run after 3 minutes).
case "$tmo" in *[!0-9]*) ;; *) tmo="${tmo}m" ;; esac
load_project "$slug"
[ -z "$(git -C "$PROJECT_PATH" rev-parse --verify "$PROJECT_BRANCH" 2>/dev/null)" ] && die "no branch $PROJECT_BRANCH in $PROJECT_PATH"
start_point="$PROJECT_BRANCH"
if [ -n "$from" ]; then start_point=$(git -C "$PROJECT_PATH" rev-parse --verify -q "$from^{commit}") || die "no commit $from in $PROJECT_PATH"; fi
sheet="$WS/agents/builder.md"
if [ -n "$instr" ]; then
  [ -d "$instr" ] || die "no instructions directory $instr"
  [ -f "$instr/agents/builder.md" ] || [ -d "$instr/lessons" ] || die "$instr has neither agents/builder.md nor lessons/"
  [ -f "$instr/agents/builder.md" ] && sheet="$instr/agents/builder.md"
  if [ -d "$instr/lessons" ]; then
    [ -f "$instr/lessons/builder.md" ] || die "$instr/lessons has no builder.md"
    # shellcheck disable=SC2034  # read by lessons_for (lib.sh)
    WS_LESSONS_DIR="$instr/lessons"
  fi
fi
wt="$(worktree_dir "$name")"; br="$(branch_of "$name")"
if pid_file_alive "$RUNS/$name.pid"; then die "a run named $name is still going (pid $(cat "$RUNS/$name.pid"))"; fi

# Worktree: create on a fresh branch from the main branch, or reuse an existing one (a resume).
fresh_wt=false fresh_br=false
if [ ! -d "$wt" ]; then
  fresh_wt=true
  wroot="$(worktree_root "$PROJECT_PATH")"; wrel="${wroot#"$PROJECT_PATH"/}"
  case "$wrel" in ''|/*|"$wroot") die "worktree_root must be inside the project: $wroot is not under $PROJECT_PATH" ;; esac
  mkdir -p "$WT_ROOT"
  excl="$(git -C "$PROJECT_PATH" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
  for e in "$wrel" .ws-evidence; do grep -qx "$e" "$excl" 2>/dev/null || echo "$e" >> "$excl"; done
  if git -C "$PROJECT_PATH" show-ref --verify --quiet "refs/heads/$br"; then
    git -C "$PROJECT_PATH" worktree add -q "$wt" "$br"
  else
    git -C "$PROJECT_PATH" worktree add -q -b "$br" "$wt" "$start_point"; fresh_br=true
  fi
  # Share gitignored environments and data with the main checkout instead of rebuilding them.
  for src in "$PROJECT_PATH"/.venv "$PROJECT_PATH"/node_modules "$PROJECT_PATH"/*/.venv "$PROJECT_PATH"/*/node_modules; do
    [ -d "$src" ] || continue
    rel="${src#"$PROJECT_PATH"/}"; [ -e "$wt/$rel" ] && continue
    mkdir -p "$(dirname "$wt/$rel")"; ln -s "$src" "$wt/$rel"
  done
  if [ -f "$PROJECT_PATH/.worktree-links" ]; then
    while IFS= read -r rel; do
      case "$rel" in ''|'#'*) continue ;; /*|*..*) note "skipping .worktree-links entry '$rel'"; continue ;; esac
      [ -e "$PROJECT_PATH/$rel" ] && [ ! -e "$wt/$rel" ] && { mkdir -p "$(dirname "$wt/$rel")"; ln -s "$PROJECT_PATH/$rel" "$wt/$rel"; }
    done < "$PROJECT_PATH/.worktree-links"
  fi
  # A package.json dependency "file:../<sibling>" resolves one level wrong from .worktrees/; link the sibling in.
  if [ -f "$PROJECT_PATH/package.json" ]; then
    for sib in $(grep -o '"file:\.\./[^"/]*"' "$PROJECT_PATH/package.json" | sed 's/"file:\.\.\///;s/"//'); do
      [ -d "$PROJECT_PATH/../$sib" ] && [ ! -e "$WT_ROOT/$sib" ] && ln -s "$(cd "$PROJECT_PATH/.." && pwd)/$sib" "$WT_ROOT/$sib" && note "linked sibling $sib into $WT_ROOT"
    done
  fi
  note "worktree $wt on $br"
else
  note "reusing worktree $wt ($(git -C "$wt" status --short | wc -l) uncommitted files)"
fi
mkdir -p "$wt/.ws-evidence"   # untracked; logs and renders go here, never into the branch (ws merge keeps it under runs/)
for i in ${inputs[@]+"${inputs[@]}"}; do cp "$i" "$wt/.ws-evidence/" && note "input $(basename "$i") copied into .ws-evidence/"; done

# An instructions directory (a bench arm) may carry maps and stage contracts beside the sheet and lessons; the
# builder runs in this worktree and cannot read the arm folder, so copy them to a folder it can. Rebuilt on every
# start and resume, so a changed arm never leaves an earlier file behind. Untracked evidence, never committed.
arm_note=""
if [ -n "$instr" ]; then
  arm_files=()
  while IFS= read -r rel; do
    case "$rel" in agents/*|lessons/*) continue ;; esac
    arm_files+=("$rel")
  done < <(cd "$instr" && find . -type f -printf '%P\n' | LC_ALL=C sort)
  arm_dir="$wt/.ws-evidence/given/arm"
  rm -rf "$arm_dir"
  if [ ${#arm_files[@]} -gt 0 ]; then
    for rel in "${arm_files[@]}"; do
      mkdir -p "$arm_dir/$(dirname "$rel")"
      cp "$instr/$rel" "$arm_dir/$rel"
    done
    arm_list=$(printf '%s, ' "${arm_files[@]}"); arm_list="${arm_list%, }"
    arm_note="
Arm files for this run are in \`.ws-evidence/given/arm/\` ($arm_list); read them as the sheet says."
  fi
fi

# WORKTREE_ENV (KEY=value lines) goes into WORKTREE_ENV_FILE in the worktree, for tests that read their
# environment from a file (Vite's loadEnv reads .env.local): builders cannot run `env VAR=... <cmd>`.
if [ ${#WORKTREE_ENV[@]} -gt 0 ] || [ -n "$WORKTREE_ENV_FILE" ]; then
  refuse() { if $fresh_wt; then git -C "$PROJECT_PATH" worktree remove --force "$wt"; $fresh_br && git -C "$PROJECT_PATH" branch -q -D "$br"; fi; die "$1"; }
  [ -n "$WORKTREE_ENV_FILE" ] || refuse "WORKTREE_ENV is set in projects/$SLUG.conf but WORKTREE_ENV_FILE is not"
  [ ${#WORKTREE_ENV[@]} -gt 0 ] || refuse "WORKTREE_ENV_FILE is set in projects/$SLUG.conf but WORKTREE_ENV has no lines"
  case "$WORKTREE_ENV_FILE" in /*|*..*) refuse "WORKTREE_ENV_FILE '$WORKTREE_ENV_FILE' must be a path inside the worktree" ;; esac
  for line in "${WORKTREE_ENV[@]}"; do
    [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || refuse "WORKTREE_ENV line '$line' is not KEY=value"
    case "$line" in *$'\n'*) refuse "WORKTREE_ENV line '${line%%$'\n'*}...' has an embedded newline" ;; esac
  done
  # Deliberate: an ignored file only, so the values (machine paths) are never committed from the branch.
  git -C "$wt" check-ignore -q -- "$WORKTREE_ENV_FILE" || refuse "$WORKTREE_ENV_FILE is not git-ignored in $wt; add it to the project's .gitignore before dispatching"
  envf="$wt/$WORKTREE_ENV_FILE" want="$(printf '%s\n' "${WORKTREE_ENV[@]}")"
  if [ -e "$envf" ] && [ "$(cat "$envf")" != "$want" ]; then
    keep="$wt/.ws-evidence/$(basename "$WORKTREE_ENV_FILE").before-$(date -u +%Y%m%dT%H%M%SZ)"; cp "$envf" "$keep"
    echo "ws: warning: $WORKTREE_ENV_FILE in the worktree had other content; replaced from projects/$SLUG.conf, the old file is at $keep" >&2
  fi
  mkdir -p "$(dirname "$envf")"; printf '%s\n' "$want" > "$envf"
fi

# Grant: edit inside the worktree, read anything, commit on this branch, run the project's tests. No push, no config.
TOOLS=(Read Grep Glob "Edit(./**)"
  "Bash(git status*)" "Bash(git diff*)" "Bash(git log*)" "Bash(git show*)" "Bash(git rev-parse*)" "Bash(git ls-files*)"
  "Bash(git branch -a)" "Bash(git branch --list*)" "Bash(git worktree list*)" "Bash(git merge-base*)"
  "Bash(git add *)" "Bash(git commit *)" "Bash(git branch --show-current)" "Bash(git checkout -- *)"
  "Bash(git restore *)" "Bash(git clean -f -- *)" "Bash(git ls-tree*)" "Bash(git check-ignore*)" "Bash(stat *)" "Bash(sha256sum *)" "Bash(file *)"
  "Bash(git rm *)" "Bash(git mv *)" "Bash(ls *)" "Bash(cat *)" "Bash(grep *)" "Bash(wc *)" "Bash(head *)" "Bash(tail *)"
  "Bash(mkdir *)" "Bash(cp *)" "Bash(chmod *)" "Bash(expr *)" "Bash(date *)" "Bash(diff *)" "Bash(bash -n *)" "Bash(git grep *)" "Bash(pwd)" "Bash(find *)" "Bash(sed *)" "Bash(which *)"
  # Read-only probes the audit found builders denied: command lookup, printed versions, jq, echo and a syntax
  # compile. The versions are listed, not `* --version`: that leading wildcard also runs a script ending in it.
  "Bash(command -v *)" "Bash(jq *)" "Bash(echo *)" "Bash(python3 -m py_compile *)"
  "Bash(bash --version)" "Bash(opencode --version)" "Bash(node --version)" "Bash(python3 --version)" "Bash(npm --version)")
[ -z "$from" ] && TOOLS+=("Bash(git merge $PROJECT_BRANCH)" "Bash(git merge $PROJECT_BRANCH --no-edit)")
[ -n "$TEST_CMD" ] && TOOLS+=("Bash($TEST_CMD)" "Bash($TEST_CMD *)")
# Per-project extras from projects/<slug>.conf (EXTRA_TOOLS), then this dispatch's --allow flags.
[ ${#EXTRA_TOOLS[@]} -gt 0 ] && TOOLS+=("${EXTRA_TOOLS[@]}")
[ ${#extra[@]} -gt 0 ] && TOOLS+=("${extra[@]}")
# A shell grant that names no script is a grant to run any command, and no deny list can spell every option
# word that selects -c (`bash -ecx id`, `bash -lce id`). EXTRA_TOOLS and --allow add commands, so drop such an
# entry instead of trying to narrow it, and say so. A pattern that names its script (`bash tests/*`,
# `bash scripts/selftest.sh`) and one constrained by an option (`bash -n *`) stay.
bare_shell_grant() {
  local body w1
  case "$1" in Bash\(*\)) body="${1#Bash(}"; body="${body%)}" ;; *) return 1 ;; esac
  # shellcheck disable=SC2086  # word splitting under set -f is intended: one pattern becomes its words
  set -f; set -- $body; set +f
  [ $# -gt 0 ] || return 1
  w1="${1##*/}"   # a path to the shell counts as the shell
  case "$w1" in
    bash|sh|dash|zsh) ;;
    bash:*|sh:*|dash:*|zsh:*|bash\*|sh\*|dash\*|zsh\*) return 0 ;;
    *) return 1 ;;
  esac
  shift || true
  [ $# -gt 0 ] || return 0
  case "$1" in
    -*) return 1 ;;
    \*) return 0 ;;
    *) return 1 ;;
  esac
}
shellless=(); keep=()
for t in "${TOOLS[@]}"; do if bare_shell_grant "$t"; then shellless+=("$t"); else keep+=("$t"); fi; done
if [ ${#shellless[@]} -gt 0 ]; then
  TOOLS=("${keep[@]}")
  slist=$(printf '%s, ' "${shellless[@]}"); slist=${slist%, }
  note "not granted (a shell needs a named command): $slist"
fi
# Denied outright, whatever an allow grants: a broad `Bash(bash*)` or `Bash(bash scripts/*)` must not re-open
# command execution through a shell's -c. The globs keep `*` inside the option word so they cannot land on a
# later argument: `bash -c*` is an option word beginning with c, and `bash -*c *` is a c inside an option word
# followed by more arguments (a combined -lc, or -e -c). A script path whose c is not followed by a blank
# (`bash -n scripts/dispatch.sh`) therefore stays runnable under the default `Bash(bash -n *)`. shell_pattern
# refuses any option word carrying a c at grant time; these DENY rules are the backstop for a broad EXTRA_TOOLS
# allow. A glob cannot tell an option word from another argument, so `bash -n foo.c bar` is denied too, and a c
# in an option word with no argument after it (`bash -lc` alone) is refused by shell_pattern but not here: the
# form runs nothing. OpenCode applies the last matching rule, so these are written after every allow; Claude
# Code's --disallowedTools wins over --allowedTools.
DENY=("Bash(git push *)" "Bash(git -c *)" "Bash(git config *)" "Bash(git * --output*)" "Bash(git reset --hard *)" "Bash(git rebase *)"
  "Bash(git worktree add *)" "Bash(git worktree remove *)" "Bash(git worktree move *)" "Bash(git worktree prune*)" "Bash(git worktree repair*)" "Bash(git worktree lock *)" "Bash(git worktree unlock *)"
  "Bash(sed -i *)" "Bash(find * -delete*)" "Bash(find * -exec*)" "Bash(find * -execdir*)"
  "Bash(bash -c*)" "Bash(sh -c*)" "Bash(dash -c*)" "Bash(zsh -c*)"
  "Bash(bash -*c *)" "Bash(sh -*c *)" "Bash(dash -*c *)" "Bash(zsh -*c *)"
  "Bash(*/bash -c*)" "Bash(*/sh -c*)" "Bash(*/dash -c*)" "Bash(*/zsh -c*)"
  "Bash(*/bash -*c *)" "Bash(*/sh -*c *)" "Bash(*/dash -*c *)" "Bash(*/zsh -*c *)" "Bash(eval*)")
# An interpreter's own code option runs arbitrary code: python's -c, node's -e/--eval/-p/--print,
# perl's -e/-E and ruby's -e. Only those are denied. Python has no -e or -p, so a module's -p (as in
# `python3 -m unittest discover -p "test_*.py"`) is not the interpreter's option and must not be denied.
# A glob's `*` spans spaces, so an unanchored letter matched any later word ending in c, e or p: `* -*c *`
# denied `node x.js --static --port 8791`. The deny therefore anchors the option word: an exact option word
# (`-* -c *`), the attached-code spelling (`-* -c*`, for `-c'code'`), and a combined short option, but only for
# the combinations listed in interp_combos: one leading flag letter (`-uc`, `-ne`, `-pe`, `-lE`), plus the
# two-flag python bundles and perl/ruby idioms named there (`-Buc`, `-IEc`, `-anle`, `-lape`). A long option
# (`--test`, `--static`) starts with `--` and matches none of these. Direct and pathed forms are denied, so
# a TEST_CMD such as `.venv/bin/python -m pytest` keeps a grant it can use while the deny wins over a broad
# EXTRA_TOOLS or --allow grant (`Bash(node *)`, `Bash(*/.venv/bin/python *)`) on both agents and ws-run.
# The limit: a bundle with a flag letter outside the listed combinations, in another order, or longer than the
# listed ones (`python3 -Bubc code`, `perl -nlaE code`) is not denied. A glob cannot say "an option word ending
# in c", and spelling every cluster would take thousands of rules (each combination becomes four), so both the
# deny and the grant-time note cover the listed forms and no others (the note still stops at an option value).
# Each interpreter stops reading its own options at the script word, so a later code option can only come after
# another option word: the later-position denies start with `-*`, and `node scripts/serve.js -p 8080` or `python3
# tool.py -c setup.cfg` is the script's own option and runs. Deliberate: a glob cannot see where the options end once
# the command starts with one, so `python -m pytest -c setup.cfg` and `node --inspect x.js -p 1` are still denied;
# telling them apart needs a shell parser. A builder that needs such an option runs `pytest` instead of `python -m
# pytest`, or drops the leading option.
# OpenCode matches these rules with the command's quotes kept, so `python3 "-c" 1` passes all of them;
# scripts/opencode-plugins/deny-guard.js re-tests the list on the unquoted text. bin/ws-run sees the words after the
# shell removed the quotes, so its match needs no such step.
declare -A interp_combos=(
  [python]="bc Bc dc Ec ic Ic Oc OOc Pc qc Rc sc Sc uc vc xc Buc IEc"
  [python3]="bc Bc dc Ec ic Ic Oc OOc Pc qc Rc sc Sc uc vc xc Buc IEc"
  [node]="ic ie ip vc ve vp hc he hp"
  [perl]="ac ae aE dc de dE ic ie iE Ic Ie IE lc le lE nc ne nE sc se sE tc te tE uc ue uE wc we wE Wc We WE xc xe xE Xc Xe XE 0c 0e 0E Cc Ce CE fc fe fE pe pE ipe 0pe lne lane lpe lwe wne 0ne ane nle lnE lanE lpE lwE wnE 0nE anE nlE Cne anle lape nlpe anlE lapE nlpE"
  [ruby]="ac ae aE dc de dE ic ie iE Ic Ie IE lc le lE nc ne nE sc se sE tc te tE uc ue uE wc we wE Wc We WE xc xe xE Xc Xe XE 0c 0e 0E Cc Ce CE pe pE lne lane lpe lwe wne 0ne ane nle lnE lanE lpE lwE wnE 0nE anE nlE Cne anle lape nlpe anlE lapE nlpE"
)
# Each interpreter's real code options, and the letters a combined short option must end in to carry one.
declare -A interp_code=(
  [python]="-c" [python3]="-c"
  [node]="-e --eval -p --print"
  [perl]="-e -E"
  [ruby]="-e"
)
declare -A interp_code_letters=(
  [python]="c" [python3]="c"
  [node]="ep"
  [perl]="eE"
  [ruby]="e"
)
interpreter_deny=()
for i in python python3 node perl ruby; do
  for opt in ${interp_code[$i]}; do
    interpreter_deny+=("$i $opt*" "$i -* $opt *" "$i -* $opt*")
  done
  for combo in ${interp_combos[$i]}; do
    last="${combo: -1}"
    case "${interp_code_letters[$i]}" in *"$last"*) ;; *) continue ;; esac
    interpreter_deny+=("$i -$combo*" "$i -* -$combo*")
  done
done
for d in "${interpreter_deny[@]}"; do DENY+=("Bash($d)" "Bash(*/$d)"); done
# Every backticked command in the task's "## Commands" section is granted by its name: its first word (first two
# for npx, npm, node, python3, python, git), except a shell, which is granted as the exact entry written so
# `bash scripts/t.sh` never becomes `Bash(bash*)` and with it `bash -c 'anything'`. A shell entry whose script is
# a bare glob (`bash *`) is refused: `Bash(bash *)` matches `bash -ecx 'anything'` too. A task therefore never
# names a command the builder cannot run: an ungranted command is denied silently and the run ends partial
# (`npm install *` does not cover `npx expo install`). Destructive forms stay in DENY, above. The interpreter
# check below is a convenience for the direct spelling (`python3 -c`, `node -e`); an option after an option
# value (`perl -I lib -e 1`) slips past it, and the DENY above still refuses that command at run time. A forbidden command
# ("No `pip`", "no plain `rm` or `mv`", "never run `ws`") is dropped before the backticks are read, or the
# prohibition itself would grant it ("No `pip`" would grant pip). A verb between the prohibition and the command
# ("never run", "do not use") must not defeat the drop; one sentence can forbid several commands ("Never run `a`
# or `b` for real"), and a command outside the prohibition on the same line ("`grep *`, but never `rm`") is
# still granted.
section=$(awk '/^## Commands/{f=1; next} /^## /{f=0} f' "$task")
all_cmds=$(printf '%s\n' "$section" | grep -o '`[^`]*`' | tr -d '`' | sed 's/^ *//' || true)
cmds=$(printf '%s\n' "$section" | sed -E 's/\b([Nn]o|[Nn]ever|[Nn]ot|[Dd]o +[Nn]ot|[Dd]on'\''t)( (plain|a bare|any))?( (run|use|call|start))? `[^`]*`(( *, *((or|and|nor) +)?| +(or|and|nor) +)`[^`]*`)*//g' | grep -o '`[^`]*`' | tr -d '`' | sed 's/^ *//' || true)
# The grant name for a backticked command: its first word, or the first two when the second narrows a tool
# that carries subcommands (npx, npm, node, python3, python, git).
grant_name() {
  local c="$1" w1 w2 g
  set -f; set -- $c; set +f; w1="${1:-}"; w2="${2:-}"
  case "$w1" in ''|'<'*|'#'*|'$'*|'-'*|'.'*|*/) return 1 ;; esac
  case "$w1" in npx|npm|node|python3|python|git) [ -n "$w2" ] && [ "${w2#<}" = "$w2" ] && [ "${w2#-}" = "$w2" ] && [ "${w2#\*}" = "$w2" ] && g="$w1 $w2" || g="$w1" ;; *) g="$w1" ;; esac
  printf '%s\n' "$g"
}
# An entry with its quoting removed, which is what the command receives: `bash "-c" id` is `bash -c id`. Every check
# on an entry's words reads this text, so a quoted word cannot end an option scan early.
bare_entry() { printf '%s' "$1" | tr -d "\"'\\\\"; }
# A shell entry's grant pattern: the entry as written, so only that script (or that glob) runs. A bare shell,
# any option word containing c (-c, a combined -lc, or a long option such as --norc), and a bare glob where the
# script belongs (`bash *`, which would also match `bash -ecx 'anything'`) return 1: none is granted, matching
# the DENY rules below.
shell_pattern() {
  local c="$1" w1 w bare
  bare=$(bare_entry "$c")
  # shellcheck disable=SC2086  # word splitting under set -f is intended: one command string becomes its words
  set -f; set -- $bare; set +f; w1="${1:-}"; shift || true
  case "$w1" in bash|sh|dash|zsh) ;; *) return 1 ;; esac
  [ $# -gt 0 ] || return 1
  for w in "$@"; do
    case "$w" in
      --) break ;;
      -*) case "$w" in *c*) return 1 ;; esac ;;
      '*'|'**') return 1 ;;
      *) break ;;
    esac
  done
  printf '%s\n' "$c"
}
# An interpreter's basename, however the entry paths it (`.venv/bin/python`).
interp_name() {
  local w1="$1" b
  case "$w1" in */*) b="${w1##*/}" ;; *) b="$w1" ;; esac
  case "$b" in python|python3|node|perl|ruby) printf '%s\n' "$b" ;; *) return 1 ;; esac
}
# An interpreter entry's grant pattern: the entry as written, so only the script (or the module, or `--test`)
# it names runs. The code-option check is a convenience for the direct form, where the interpreter's own option
# (python -c; node -e/--eval/-p/--print; perl -e/-E; ruby -e), or a combined short option carrying one (`-ne`),
# comes before the script word: it then returns 2 and dispatch's note names the entry. An option after an option
# value (`perl -I lib -e 1`) ends the scan at `lib`, so the entry is granted; the DENY above still refuses that
# command at run time. A bare entry or a bare glob where the script belongs (`node *`) returns 1.
interp_pattern() {
  local c="$1" base="$2" w opt combo last script=false test_mode=false bare
  bare=$(bare_entry "$c")
  # shellcheck disable=SC2086  # word splitting under set -f is intended: one command string becomes its words
  set -f; set -- $bare; set +f
  shift || true
  [ $# -gt 0 ] || return 1
  for w in "$@"; do
    case "$w" in
      --) continue ;;
      -*)
        for opt in ${interp_code[$base]}; do
          case "$w" in "$opt"*) return 2 ;; esac
        done
        for combo in ${interp_combos[$base]}; do
          last="${combo: -1}"
          case "${interp_code_letters[$base]}" in *"$last"*) ;; *) continue ;; esac
          case "$w" in -"$combo"*) return 2 ;; esac
        done
        [ "$base" = node ] && [ "$w" = --test ] && test_mode=true
        continue ;;
      '*'|'**') return 1 ;;
      *) script=true; break ;;
    esac
  done
  if $script || $test_mode; then printf '%s\n' "$c"; else return 1; fi
}
# Whether a command string matches one Claude-style Bash(<pattern>) rule body.
matches_rule() {
  local cmd="$1" pat="$2"
  # shellcheck disable=SC2053  # the rule is a glob on purpose, as Claude Code's Bash(...) rules are
  [[ "$cmd" == $pat ]]
}
derived=() unsafe=() interp_unsafe=() eval_forms=()
while IFS= read -r c; do
  [ -n "$c" ] || continue
  # No glob expansion: `node *` is a pattern, not this folder's files.
  bare=$(bare_entry "$c")
  # shellcheck disable=SC2086  # word splitting under set -f is intended: one command string becomes its words
  set -f; set -- $bare; set +f; w1="${1:-}"; w2="${2:-}"; w3="${3:-}"; w4="${4:-}"
  # git with an option first: `git -C <dir> <sub>` is granted as exactly that; any other option form is not
  # granted at all, since the fallback below would be Bash(git*), every git command.
  if [ "$w1" = git ] && [ "${w2#-}" != "$w2" ]; then
    case "$w4" in ''|push|config|reset|rebase|worktree|branch|stash|checkout|clean|rm|mv) continue ;; esac
    [ "$w2" = -C ] && [ -n "$w3" ] || continue
    pat="Bash(git -C $w3 $w4*)"; printf '%s\n' "${TOOLS[@]}" "${derived[@]}" | grep -qxF "$pat" || derived+=("$pat"); continue
  fi
  case "$w1" in ''|'<'*|'#'*|'$'*|'-'*) continue ;; rm|mv|sudo|su|dd|mkfs|shutdown|reboot|kill|pkill|killall) continue ;; esac
  if base=$(interp_name "$w1"); then
    if pat=$(interp_pattern "$c" "$base"); then
      pat="Bash($pat*)"
    else
      rc=$?
      # An entry an existing grant already runs exactly (a TEST_CMD's `Bash(node --test)`) is runnable, so it is
      # not refused; only an entry no grant covers is unsafe.
      pat="Bash($c)"
      printf '%s\n' "${TOOLS[@]}" "${derived[@]}" | grep -qxF "$pat" && continue
      if [ "$rc" = 2 ]; then eval_forms+=("$c"); else interp_unsafe+=("$c"); fi
      continue
    fi
  else
    case "$w1" in '.'*|*/) continue ;; esac
    g=$(grant_name "$(bare_entry "$c")") || continue
    case "$g" in "git push"|"git config"|"git reset"|"git rebase"|"git worktree"|"git branch"|"git stash"|"git checkout") continue ;; esac
    case "$w1" in
      bash|sh|dash|zsh)
        if g=$(shell_pattern "$c"); then pat="Bash($g)"; else
          # A shell entry an existing grant already runs exactly (the default `Bash(bash -n *)`) is runnable, so it is
          # not refused; only an entry no grant covers is unsafe.
          pat="Bash($c)"
          printf '%s\n' "${TOOLS[@]}" "${derived[@]}" | grep -qxF "$pat" && continue
          unsafe+=("$c"); continue
        fi ;;
      *) pat="Bash($g*)" ;;
    esac
  fi
  printf '%s\n' "${TOOLS[@]}" "${derived[@]}" | grep -qxF "$pat" || derived+=("$pat")
done <<< "$cmds"
[ ${#derived[@]} -gt 0 ] && { TOOLS+=("${derived[@]}"); note "grants from ## Commands: ${derived[*]}"; }
if [ ${#interp_unsafe[@]} -gt 0 ]; then
  ulist=$(printf '%s, ' "${interp_unsafe[@]}"); ulist=${ulist%, }
  note "not granted (an interpreter entry needs a named script): $ulist"
fi
if [ ${#eval_forms[@]} -gt 0 ]; then
  elist=$(printf '%s, ' "${eval_forms[@]}"); elist=${elist%, }
  note "not granted (interpreter command or eval option): $elist"
fi
if [ ${#unsafe[@]} -gt 0 ]; then
  ulist=$(printf '%s, ' "${unsafe[@]}"); ulist=${ulist%, }
  note "not granted (bare shell, a shell option word carrying c, or a shell whose command is a bare glob): $ulist"
fi
# A command the filter removed was forbidden by the task, but not necessarily unrunnable: a default grant
# (Bash(git add *)) or a broader grant from another entry (Bash(npm run*) for `npm run deploy`) can still cover
# it. Reporting "not granted" then would claim the sentence narrowed the grants while the command stays
# runnable, so a covered command is named in a warning instead and only the rest are listed as refused.
dropped=()
covered=()
while IFS= read -r c; do
  [ -n "$c" ] || continue
  printf '%s\n' "$cmds" | grep -qxF "$c" && continue
  n=$(grant_name "$c") || continue
  cov=""
  # A command a deny rule matches stays unrunnable however an allow is written, so it is reported as not
  # granted rather than "still covered".
  # A command with no arguments after its grant name is covered by `word *` and `word*`: the pattern's
  # trailing `*` matches an empty argument list, but the bare text has no space for it to match.
  probe="$c"; [ "$c" = "$n" ] && probe="$c "
  denied=false
  for d in "${DENY[@]}"; do
    case "$d" in Bash\(*\)) dp="${d#Bash(}"; dp="${dp%)}" ;; *) continue ;; esac
    matches_rule "$probe" "$dp" && { denied=true; break; }
  done
  if ! $denied; then
    for t in "${TOOLS[@]}"; do
      case "$t" in Bash\(*\)) p="${t#Bash(}"; p="${p%)}" ;; *) continue ;; esac
      matches_rule "$probe" "$p" && { cov="$p"; break; }
    done
  fi
  if [ -n "$cov" ]; then
    entry="$n (Bash($cov))"
    case " ${covered[*]} " in *" $entry "*) ;; *) covered+=("$entry") ;; esac
    continue
  fi
  case " ${dropped[*]} " in *" $n "*) ;; *) dropped+=("$n") ;; esac
done <<< "$all_cmds"
if [ ${#covered[@]} -gt 0 ]; then
  covlist=$(printf '%s, ' "${covered[@]}"); covlist=${covlist%, }
  note "warning: forbidden in ## Commands but still covered by an existing grant: $covlist"
fi
if [ ${#dropped[@]} -gt 0 ]; then
  refused=$(printf '%s, ' "${dropped[@]}"); refused=${refused%, }
  note "not granted (forbidden in ## Commands): $refused"
fi
# Both commands in a compound entry can be granted and the call is still denied as one Bash call. Say it at
# dispatch: the audit found the denied-call class the most recurrent defect, and a lost turn is silent.
if printf '%s\n' "$cmds" | grep -qE '(\|\||&&|\||;)'; then
  note "warning: a ## Commands entry looks compound (|, &&, ||, ;); builders run one command per call, so split it"
fi
# A task that names WebSearch or WebFetch (research) gets them; without a grant they are denied silently.
# "WebSearch", "web search" and "web-search" all count (research tasks are written in prose).
grep -qiE '\bweb[ -]?search\b' "$task" && TOOLS+=("WebSearch")
grep -qiE '\bweb[ -]?fetch\b' "$task" && TOOLS+=("WebFetch")
# A build task names what it reuses (agents/planner.md). Light tasks and research-only tasks are exempt.
if ! grep -q "^## Prior art" "$task" && ! grep -q "Track: light" "$task" && ! grep -q -i -E "research only|no code" "$task"; then
  echo "ws: warning: $task has no ## Prior art section (what existing software it reuses, or why nothing fits)" >&2
fi
# The evidence runner (bin/ws-run) checks each command against these same Bash grants and denials, read from
# files the builder cannot edit, so wrapping a command in it grants nothing new.
RUN_GRANTS="$RUNS/$name.grants"
RUN_DENY="$RUNS/$name.deny"
TOOLS+=("Bash($WS/bin/ws-run *)")

# Paths .worktree-links linked in from the main checkout: builders read them but cannot write through them
# (outside the worktree), so the prompt says so, and where outputs to keep go instead.
links_note=""
if [ -f "$PROJECT_PATH/.worktree-links" ]; then
  lk=$(grep -v -E '^(#|$)' "$PROJECT_PATH/.worktree-links" | sed 's/.*/`&`/' | paste -sd, - | sed 's/,/, /g')
  [ -n "$lk" ] && links_note="
Linked paths: $lk are links into the main checkout. Read them; writing through them is denied (they resolve outside the worktree). Save files that must outlive this run under \`.ws-evidence/\` (kept at merge) and say in the result where they should go."
fi
prompt="You are a headless builder launched by Crafting Guild. Working directory: $wt (a git worktree of $PROJECT_PATH on branch $br). Do only the task below, then answer with the JSON result.

# Your role
$(cat "$sheet")

# Review checklist (the reviewer applies it to your whole branch)
$(cat "$WS/checklist.md")

# Lessons from earlier runs
$(lessons_for builder)

# Project
Main branch: $PROJECT_BRANCH. Project test command: ${TEST_CMD:-none configured}. The merge gate runs it on the merged tree; you do not. Run only the test files that cover what you changed, with the same runners, from the worktree root, in the foreground.
Evidence: run every check you will cite (test files, typecheck, render scripts) through the evidence runner, one command per call: \`$WS/bin/ws-run <label> <command> [args...]\` (for example \`$WS/bin/ws-run before-frames npx jest --runInBand test/a.test.ts\`). That line is the runner's whole usage; do not read \`bin/ws-run\` from the main checkout. It runs the command in the foreground, saves .ws-evidence/<label>.log ending in the real exit code, and adds a row to .ws-evidence/runs.tsv; use a label that says before or after the change. Do not write your own run-and-log scripts. Save every other log and render under .ws-evidence/ in the worktree root (it is untracked and the reviewer reads it there). Commit code, tests and docs; commit a render only when the task asks for one.
Dependencies: \`node_modules\` (and \`.venv\`) may be a link to the main checkout, outside the worktree, so Bash \`cat\`, \`ls\`, \`grep\` and \`stat\` on paths inside it are denied; read them with the Read, Grep and Glob tools, which are allowed there.
Paths: work inside \`$wt\` and read files from it. The main checkout at \`$PROJECT_PATH\` is outside the worktree, so every read there (the read tool and Bash \`cat\`/\`find\`/\`sed\`) is denied; your worktree is the full checkout of the same branch, so read the same path under it.$links_note$arm_note
Files: delete a tracked file with \`git rm <path>\` and an untracked one (a scratch test, a probe) with \`git clean -f -- <path>\`; bring a file back from a commit with \`git restore --source=<ref> -- <path>\`. Plain \`rm\`, \`mv\`, \`git checkout <ref> -- <path>\`, \`git stash\` and \`git reset\` are not granted.

# Task
$(cat "$task")

# Result schema
The schema your final answer is validated against. It is here so you do not need to read the workspace's \`schema/result.json\`:
$(cat "$WS/schema/result.json")

# Result
Your final answer is validated against the schema above: status (done|partial|blocked), summary, files_changed, commits (SHAs you made), tests (command, passed, failed, log_path, or null), denied (every denied call), done_when, edge_cases (platform, time, stored_data, state_resets), unknowns, open_questions, and web_requests when you need web sources you do not have."

cmd=(claude -p "$prompt" --allowedTools "${TOOLS[@]}" --disallowedTools "${DENY[@]}"
  --permission-prompts none --json-schema "$(cat "$WS/schema/result.json")"
  --max-budget-usd "$budget" --output-format stream-json --verbose --name "ws:$SLUG:$name")
[ -n "$model" ] && cmd+=(--model "$model")
[ -n "$effort" ] && cmd+=(--effort "$effort")
# OpenCode: the same grants as an OpenCode permission config, the prompt from a file, the result line written by
# the launcher. Effort arrives as the model variant checked above.
if [ "$agent" = opencode ]; then
  oc_config="$RUNS/$name.opencode.json"; oc_prompt="$RUNS/$name.prompt.txt"
  dargs=(); for d in "${DENY[@]}"; do dargs+=(--deny "$d"); done
  sampling=()
  [ -n "$temperature" ] && sampling+=(--temperature "$temperature")
  [ -n "$top_p" ] && sampling+=(--top-p "$top_p")
  WS_SANDBOX="$WS_SANDBOX" python3 -I "$WS/scripts/opencode_run.py" config ${sampling[@]+"${sampling[@]}"} "${TOOLS[@]}" "${dargs[@]}" > "$oc_config" || die "could not build the OpenCode config"
  variant_args=()
  [ -n "$variant" ] && variant_args=(--variant "$variant")
  printf '%s\n' "$prompt" > "$oc_prompt"
  cmd=("$WS/scripts/opencode-builder.sh" --model "$model" --budget "$budget" --config "$oc_config" --log "$RUNS/$name.jsonl" --name "ws:$SLUG:$name" "${variant_args[@]}" "$oc_prompt")
fi

# The agent matches a grant as written, quotes included; ws-run matches the words the shell passed it, so its copy
# of the list carries no quoting.
printf '%s\n' "${TOOLS[@]}" | sed -n 's/^Bash(\(.*\))$/\1/p' | grep -v '/bin/ws-run ' | tr -d "\"'\\\\" > "$RUN_GRANTS"
printf '%s\n' "${DENY[@]}" | sed -n 's/^Bash(\(.*\))$/\1/p' > "$RUN_DENY"
if $dry; then
  [ "$agent" = opencode ] && { echo "agent: opencode model: $model${variant:+ variant: $variant}"; echo "opencode config ($oc_config):"; cat "$oc_config"; }
  echo "cwd: $wt"; echo "tools: ${TOOLS[*]}"; echo "deny: ${DENY[*]}"; echo "budget: \$$budget timeout: $tmo model: ${model:-default} memory cap: ${WS_BUILDER_MEM:-none}"
  echo "prompt bytes: ${#prompt}"; echo "evidence: $wt/.ws-evidence"; echo "base: $(git -C "$wt" rev-parse HEAD)"
  if $show_prompt; then echo "--- prompt ---"; printf '%s\n' "$prompt"; fi
  # A dry run leaves nothing behind: a worktree (and branch) it made goes again, so a later dispatch branches from
  # the main branch as it is then. One that existed before (a resume) stays.
  if $fresh_wt; then git -C "$PROJECT_PATH" worktree remove --force "$wt"; $fresh_br && git -C "$PROJECT_PATH" branch -q -D "$br"; fi
  exit 0
fi

if [ "$agent" = opencode ]; then allowance_warn "$model"; fi
# Previous run's files move aside; this run's log, pid and task record are written fresh.
stamp=$(date -u +%Y%m%dT%H%M%SZ)
for ext in jsonl result.txt task.txt events.jsonl serve.log; do [ -e "$RUNS/$name.$ext" ] && mv "$RUNS/$name.$ext" "$RUNS/$name.$stamp.$ext"; done
# The Claude Code version goes into the run record, so a capability change is traceable to an upgrade.
claude_version=""
if [ "$agent" = claude ]; then
  claude_version=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
fi
{ echo "task=$(cd "$(dirname "$task")" && pwd)/$(basename "$task")"; echo "started=$(now_local)"; echo "budget=$budget"; echo "timeout=$tmo"; echo "worktree=$wt"; if [ -n "$claude_version" ]; then echo "claude_version=$claude_version"; fi; } > "$RUNS/$name.task.txt"
start_sha=$(git -C "$wt" rev-parse HEAD); echo "since=$start_sha" >> "$RUNS/$name.task.txt"
# Memory cap: the run gets its own systemd scope, so a runaway script is killed alone (OOMPolicy=continue
# keeps the builder alive to see it) instead of the kernel taking out the editor the session runs in.
cap=() mem="uncapped"
if [ -n "$WS_BUILDER_MEM" ] && systemd-run --user --scope --quiet true >/dev/null 2>&1; then
  cap=(systemd-run --user --scope --quiet -p "MemoryMax=$WS_BUILDER_MEM" -p MemorySwapMax=0 -p OOMPolicy=continue --unit "ws-$SLUG-$name-$stamp" --description "ws builder $SLUG/$name"); mem="$WS_BUILDER_MEM"
fi
(
  cd "$wt"
  WS_RUN_GRANTS="$RUN_GRANTS" WS_RUN_DENY="$RUN_DENY" "${cap[@]}" timeout --kill-after=30s "$tmo" "${cmd[@]}" < /dev/null > "$RUNS/$name.jsonl" 2>&1
  rc=$?
  "$WS/scripts/check-result.sh" --project "$SLUG" --since "$start_sha" "$name" > "$RUNS/$name.result.txt" 2>&1 || true
  [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ] && sed -i "1i TIMEOUT after $tmo (exit $rc); partial work may be in $wt" "$RUNS/$name.result.txt"
  rm -f "$RUNS/$name.pid"
) < /dev/null > /dev/null 2>&1 &
echo $! > "$RUNS/$name.pid"
echo "dispatched $name (pid $!) in $wt (budget \$$budget, timeout $tmo, memory $mem)"
echo "  log:    runs/$SLUG/$name.jsonl"
echo "  result: runs/$SLUG/$name.result.txt (written when it finishes)"
echo "  wait:   bin/ws wait $name      watch: bin/ws tail $name"
