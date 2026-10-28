#!/usr/bin/env bash
# Audit what publishes a personal address: the git identity, author/committer e-mails, reflogs and tracked files.
# Usage: email-audit.sh [--project slug | --repo path]... [--all] [--range <git range>] [--quiet]
# Policy: an author or committer address ending in @users.noreply.github.com (or noreply@github.com) passes;
# anything else is a finding, so a personal address is caught without naming it in this public repository.
# WS_EMAIL_DENY (comma-separated) names addresses to report explicitly; WS_EMAIL_ALLOW names third-party
# authors a repository legitimately carries (vendored or imported history). Both live in config.local.sh.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
roots=(); slug=""; range=""; quiet=false
while [ $# -gt 0 ]; do
  case "$1" in
    --project) slug="$2"; shift 2 ;;
    --repo) roots+=("$2"); shift 2 ;;
    --all) for f in "$WS"/projects/*.conf; do [ -f "$f" ] || continue; ( . "$f"; [ -n "${PROJECT_PATH:-}" ] && printf '%s\n' "$PROJECT_PATH" ); done > /tmp/email-audit-roots.$$; mapfile -t -O ${#roots[@]} roots < /tmp/email-audit-roots.$$; rm -f /tmp/email-audit-roots.$$ ;;
    --range) range="$2"; shift 2 ;;
    --quiet) quiet=true; shift ;;
    -*) die "unknown flag $1" ;;
    *) die "usage: email-audit.sh [--project slug | --repo path]... [--all] [--range R] [--quiet]" ;;
  esac
done
[ -n "$slug" ] && { load_project "$slug"; roots+=("$PROJECT_PATH"); }
[ ${#roots[@]} -eq 0 ] && roots=("$WS")
deny="${WS_EMAIL_DENY:-}"; allow="${WS_EMAIL_ALLOW:-}"
allowed() {
  local e="$1" a
  case "$e" in *@users.noreply.github.com|noreply@github.com) return 0 ;; esac
  IFS=, read -ra _deny <<< "$deny"; for a in ${_deny[@]+"${_deny[@]}"}; do [ "$a" = "$e" ] && return 1; done
  IFS=, read -ra _allow <<< "$allow"; for a in ${_allow[@]+"${_allow[@]}"}; do [ "$a" = "$e" ] && return 0; done
  return 1
}
fails=0
for root in ${roots[@]+"${roots[@]}"}; do
  [ -d "$root/.git" ] || [ -f "$root/.git" ] || continue
  name=$(basename "$root")
  problems=()
  # 1. The identity that authors the next commit (repo-local overrides the global).
  id_email=$(git -C "$root" config --get user.email 2>/dev/null || true)
  if [ -n "$id_email" ] && ! allowed "$id_email"; then problems+=("user.email is $id_email"); fi
  # 2. Author and committer addresses in history (or one range).
  logargs=(log --all --format='%ae%n%ce'); [ -n "$range" ] && logargs=(log "$range" --format='%ae%n%ce')
  mapfile -t emails < <(git -C "$root" "${logargs[@]}" 2>/dev/null | grep -v '^$' | sort -u)
  for e in ${emails[@]+"${emails[@]}"}; do allowed "$e" || problems+=("history: $e"); done
  # 3. Reflogs carry the old identity even after a commit is no longer referenced.
  if [ -d "$root/.git/logs" ]; then
    IFS=, read -ra _deny_logs <<< "$deny"
    for e in ${emails[@]+"${emails[@]}"} ${id_email:+"$id_email"} ${_deny_logs[@]+"${_deny_logs[@]}"}; do
      allowed "$e" && continue
      grep -rqsF "$e" "$root/.git/logs" && problems+=("reflog: $e")
    done
  fi
  # 4. Tracked file contents: every address history carried, plus the explicit deny list (a plan can quote
  #    an address that history no longer has).
  IFS=, read -ra _deny_list <<< "$deny"
  for e in ${emails[@]+"${emails[@]}"} ${id_email:+"$id_email"} ${_deny_list[@]+"${_deny_list[@]}"}; do
    allowed "$e" && continue
    git -C "$root" grep -IqF -- "$e" && problems+=("tracked file: $e")
  done
  if [ ${#problems[@]} -gt 0 ]; then
    fails=$((fails+1)); printf 'FAIL  %s\n' "$name"
    printf '      %s\n' "${problems[@]}" | sort -u | head -20
  elif ! $quiet; then
    printf 'ok    %s\n' "$name"
  fi
done
[ "$fails" -eq 0 ] && { $quiet || echo "no personal address found"; exit 0; }
echo "FAIL  $fails repository(ies) publish a personal address; see plans/crafting-guild/email-history-rewrite.md" >&2
exit 1
