#!/usr/bin/env bash
# shellcheck disable=SC2154  # the alert keys are assigned by alerts_load_config in alerts-lib.sh
# ws alerts [on|off|status|test]: install, remove or inspect the two comfort pieces, or raise one sample alert.
# `on` merges docs/alerts-claude-hooks.json into ~/.claude/settings.json (backing it up first), links the OpenCode
# plugin into the workspace's .opencode/plugins/ and enables ws-break.timer the way `ws autostart` installs units;
# `off` removes exactly what `on` added. The config file itself is never written: docs/alerts.conf.sample has every
# key, and the defaults apply while ~/.config/crafting-guild/alerts.conf is absent.
# No model runs for any of this.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
# shellcheck source=./alerts-lib.sh
. "$(dirname "$0")/alerts-lib.sh"

settings="$HOME/.claude/settings.json"
plugin_src="$WS/scripts/opencode-plugins/attention.js"
plugin_link="$WS/.opencode/plugins/attention.js"
hooks_snippet="$WS/docs/alerts-claude-hooks.json"
unit_dir="$HOME/.config/systemd/user"
state_dir=$(alerts_state_dir)
marker="$state_dir/alerts.install"

alerts_backup_settings() {
  local backup
  backup="$settings.bak-$(date -u +%Y%m%dT%H%M%SZ)"
  cp -p "$settings" "$backup" && echo "backed up $settings to $backup"
}

# The jq that adds one object of hook events to .hooks: every entry whose command runs an attention.sh is replaced,
# so a second `on` is a no-op, and every other event and key is left alone.
alerts_merge_hooks() { # <before-json> <snippet-json>
  printf '%s' "$1" | jq --argjson add "$2" '
    def ours: ([.hooks[]?.command // ""] | join(" ") | test("scripts/attention\\.sh"));
    .hooks = (
      (.hooks // {}) as $cur
      | reduce ($add | to_entries[]) as $e
          ( ($cur | with_entries(select(.key as $k | ($add | has($k)) | not)))
            ; . + { ($e.key): ((($cur[$e.key] // []) | map(select(ours | not))) + $e.value) }
          )
    )'
}

# Removing is the same filter without the append; an empty .hooks is deleted only when `on` created that key (the
# marker records it), so a file with no hooks comes back byte for byte.
alerts_strip_hooks() { # <json> <hooks-key-created: yes|no>
  local stripped
  stripped=$(printf '%s' "$1" | jq '
    def ours: ([.hooks[]?.command // ""] | join(" ") | test("scripts/attention\\.sh"));
    if (.hooks // {}) == {} then .
    else .hooks |= (with_entries(.value |= map(select(ours | not))) | with_entries(select(.value != [])))
    end') || return 1
  if [ "$2" = yes ]; then
    printf '%s' "$stripped" | jq 'if .hooks == {} then del(.hooks) else . end'
  else
    printf '%s' "$stripped"
  fi
}

alerts_lock() {
  command -v flock >/dev/null 2>&1 || die "flock is required"
  mkdir -p "$state_dir" || die "cannot create $state_dir"
  exec 9>"$state_dir/alerts.lock"
  flock 9
}

alerts_link_plugin() {
  [ -f "$plugin_src" ] || die "no $plugin_src"
  if [ -e "$plugin_link" ] || [ -L "$plugin_link" ]; then
    if [ -L "$plugin_link" ] && [ "$(readlink "$plugin_link")" = "$plugin_src" ]; then
      echo "plugin: already linked at ${plugin_link#"$WS"/}"
      return 0
    fi
    die "$plugin_link exists and is not the attention plugin; move it aside, then run ws alerts on again"
  fi
  mkdir -p "$(dirname "$plugin_link")" || die "cannot create $(dirname "$plugin_link")"
  ln -sfn "$plugin_src" "$plugin_link" || die "cannot link $plugin_link"
  echo "plugin: linked at ${plugin_link#"$WS"/} (OpenCode loads .opencode/plugins/ from this folder)"
}

alerts_install_units() {
  [ -f "$WS/systemd/ws-break.service" ] && [ -f "$WS/systemd/ws-break.timer" ] || die "no ws-break units under $WS/systemd"
  mkdir -p "$unit_dir" || die "cannot create $unit_dir"
  ln -sfn "$WS/systemd/ws-break.service" "$unit_dir/ws-break.service"
  ln -sfn "$WS/systemd/ws-break.timer" "$unit_dir/ws-break.timer"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload || note "systemctl --user daemon-reload failed"
    if systemctl --user enable --now ws-break.timer; then
      echo "break timer: on (ws-break.timer, every minute; log: journalctl --user -u ws-break)"
    else
      note "the units are linked but ws-break.timer could not be enabled"
    fi
  else
    echo "break timer: units linked but not enabled (no systemctl on PATH)"
  fi
}

alerts_remove_units() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user disable --now ws-break.timer >/dev/null 2>&1 || true
  fi
  rm -f "$unit_dir/ws-break.service" "$unit_dir/ws-break.timer"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload >/dev/null 2>&1 || true
  fi
  echo "break timer: removed"
}

alerts_on() {
  command -v jq >/dev/null 2>&1 || die "jq is required"
  [ -f "$hooks_snippet" ] || die "no $hooks_snippet"
  alerts_lock
  local created=no had_hooks=no hooks_created=no previous_created=no before after snippet
  if [ -f "$marker" ]; then
    previous_created=$(sed -n 's/^hooks_key_created=//p' "$marker" | head -n 1)
    [ "$(sed -n 's/^settings_created=//p' "$marker" | head -n 1)" = yes ] && created=yes
  fi
  if [ -f "$settings" ]; then
    before=$(cat "$settings") || die "cannot read $settings"
  else
    before='{}'
    created=yes
    mkdir -p "$(dirname "$settings")" || die "cannot create $(dirname "$settings")"
  fi
  printf '%s' "$before" | jq -e . >/dev/null 2>&1 || die "$settings is not valid JSON; fix it by hand first"
  printf '%s' "$before" | jq -e 'has("hooks")' >/dev/null && had_hooks=yes
  snippet=$(jq --arg ws "$WS" 'walk(if type == "string" then gsub("__WS__"; $ws) else . end)' "$hooks_snippet") \
    || die "cannot read $hooks_snippet"
  after=$(alerts_merge_hooks "$before" "$snippet") || die "could not merge the hook snippet into $settings"
  if [ "$after" != "$before" ]; then
    [ -f "$settings" ] && alerts_backup_settings
    printf '%s\n' "$after" >"$settings.tmp.$$" && mv "$settings.tmp.$$" "$settings" || die "cannot write $settings"
    echo "hooks: merged into $settings"
  else
    echo "hooks: already in $settings"
  fi
  [ "$had_hooks" = no ] && hooks_created=yes
  [ "$previous_created" = yes ] && hooks_created=yes
  printf 'settings=%s\nsettings_created=%s\nhooks_key_created=%s\n' "$settings" "$created" "$hooks_created" >"$marker"
  alerts_link_plugin
  alerts_install_units
  echo "config: $(alerts_config_path)$( [ -f "$(alerts_config_path)" ] || echo ' (absent; defaults apply)')"
  echo "turn a piece off alone with attention=off or break_minutes=0 in it, or remove everything with ws alerts off"
}

alerts_off() {
  command -v jq >/dev/null 2>&1 || die "jq is required"
  alerts_lock
  local created=no hooks_created=no before after
  if [ -f "$marker" ]; then
    hooks_created=$(sed -n 's/^hooks_key_created=//p' "$marker" | head -n 1)
    created=$(sed -n 's/^settings_created=//p' "$marker" | head -n 1)
  fi
  if [ -f "$settings" ] && [ "$(cat "$settings")" != '{}' ]; then
    before=$(cat "$settings") || die "cannot read $settings"
    after=$(alerts_strip_hooks "$before" "${hooks_created:-no}") || die "could not remove the hooks from $settings"
    if [ "$after" != "$before" ]; then
      alerts_backup_settings
      if [ "$created" = yes ] && [ "$(printf '%s' "$after" | jq -c .)" = '{}' ]; then
        rm -f "$settings"
        echo "hooks: removed; $settings was created by ws alerts and is gone"
      else
        printf '%s\n' "$after" >"$settings.tmp.$$" && mv "$settings.tmp.$$" "$settings" || die "cannot write $settings"
        echo "hooks: removed from $settings"
      fi
    else
      echo "hooks: none of ours in $settings"
    fi
  else
    echo "hooks: no $settings"
  fi
  if [ -L "$plugin_link" ] && [ "$(readlink "$plugin_link")" = "$plugin_src" ]; then
    rm -f "$plugin_link"
    echo "plugin: unlinked"
  fi
  alerts_remove_units
  rm -f "$marker"
}

alerts_status() {
  local cfg count enabled active lines
  alerts_load_config
  cfg=$(alerts_config_path)
  if [ -f "$cfg" ]; then
    echo "config: $cfg"
  else
    echo "config: $cfg (absent; defaults in effect)"
  fi
  echo "  attention=$attention visual=$visual sound=$sound volume=$volume break_minutes=$break_minutes alert_after_seconds=$alert_after_seconds repeat_minutes=$repeat_minutes quiet_hours=${quiet_hours:-none}"
  echo "  break_message: $break_message"
  count=0
  if [ -f "$settings" ]; then
    count=$(jq '[.hooks[]? | .[]? | .hooks[]? | select((.command // "") | test("scripts/attention\\.sh"))] | length' "$settings" 2>/dev/null || echo 0)
  fi
  if [ "$count" -gt 0 ]; then
    echo "claude hooks: $count command(s) in $settings"
  else
    echo "claude hooks: not installed ($settings)"
  fi
  if [ -L "$plugin_link" ] && [ "$(readlink "$plugin_link")" = "$plugin_src" ]; then
    echo "opencode plugin: linked at ${plugin_link#"$WS"/}"
  else
    echo "opencode plugin: not linked (${plugin_link#"$WS"/})"
  fi
  if command -v systemctl >/dev/null 2>&1; then
    enabled=$(systemctl --user is-enabled ws-break.timer 2>/dev/null | head -n 1)
    [ -n "$enabled" ] || enabled=unknown
    active=$(systemctl --user is-active ws-break.timer 2>/dev/null | head -n 1)
    [ -n "$active" ] || active=unknown
    echo "break timer: $enabled, $active (ws-break.timer)"
  else
    echo "break timer: unknown (no systemctl on PATH)"
  fi
  lines=0
  [ -f "$(alerts_attention_log)" ] && lines=$(wc -l <"$(alerts_attention_log)")
  echo "state: $state_dir (attention.log: $lines line(s))"
}

# One sample pop-up and one log line, through the same handler and with the same config: the whole path except the
# agent event. The pop-up is real, so `test` only runs on request.
alerts_test() {
  local project="${WS_PROJECT:-}"
  [ -n "$project" ] || project=$(head -n 1 "$WS/state/current" 2>/dev/null || true)
  [ -n "$project" ] || project=crafting-guild
  "$WS/scripts/attention.sh" --agent claude --session "alerts-test-$$" --project "$project" --reason question --event test
}

case "${1:-status}" in
  on) alerts_on ;;
  off) alerts_off ;;
  status) alerts_status ;;
  test) alerts_test ;;
  *) die "usage: ws alerts [on|off|status|test]" ;;
esac
