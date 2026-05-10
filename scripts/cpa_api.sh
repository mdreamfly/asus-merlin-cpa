#!/bin/sh
set -e

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
CONFIG_SCRIPT="$SCRIPT_DIR/cpa_config.sh"
RUNTIME_SCRIPT="$SCRIPT_DIR/cpa_runtime.sh"
UPDATE_SCRIPT="$SCRIPT_DIR/cpa_update.sh"
VERSION_FILE="$SCRIPT_DIR/../version"
CPA_BUNDLED_RUNTIME_VERSION=${CPA_BUNDLED_RUNTIME_VERSION:-6.10.9}

. "$RUNTIME_SCRIPT"

json_escape() {
  printf '%s' "$1" | tr '\r\n' '  ' | sed 's/\\/\\\\/g; s/"/\\"/g'
}

dbus_get_or_empty() {
  dbus get "$1" 2>/dev/null || true
}

read_current_version() {
  if [ -f "$VERSION_FILE" ]; then
    tr -d '\r\n' < "$VERSION_FILE"
    return 0
  fi

  printf 'unknown\n'
}

get_service_port() {
  port=$(dbus_get_or_empty cpa_port)
  case "$port" in
    ''|*[!0-9]*)
      printf '%s\n' "$CPA_PORT_DEFAULT"
      ;;
    *)
      printf '%s\n' "$port"
      ;;
  esac
}

json_ok() {
  result=$(json_escape "$1")
  printf '{"success":true,"result":"%s"}' "$result"
}

json_err() {
  error=$(json_escape "$1")
  printf '{"success":false,"error":"%s"}' "$error"
}

run_action() {
  action="$1"
  output=$(
    sh "$CONFIG_SCRIPT" "$action" 2>&1
  ) && {
    [ -n "$output" ] && json_ok "$output" || json_ok "$action"
    return 0
  }

  [ -n "$output" ] && json_err "$output" || json_err "$action failed"
  return 1
}

run_update_check() {
  output=$(
    sh "$UPDATE_SCRIPT" check 2>&1
  ) && {
    [ -n "$output" ] && json_ok "$output" || json_ok "check"
    return 0
  }

  [ -n "$output" ] && json_err "$output" || json_err "check failed"
  return 1
}

status_json() {
  status_output=$(sh "$CONFIG_SCRIPT" status 2>/dev/null || true)
  running=false
  case "$status_output" in
    running:*) running=true ;;
  esac

  current_version=$(dbus_get_or_empty cpa_runtime_version)
  [ -n "$current_version" ] || current_version="$CPA_BUNDLED_RUNTIME_VERSION"
  latest_version=$(dbus_get_or_empty cpa_latest_version)
  [ -n "$latest_version" ] || latest_version="$current_version"

  update_available=$(dbus_get_or_empty cpa_update_available)
  case "$update_available" in
    1|true|yes) update_available=true ;;
    *) update_available=false ;;
  esac

  last_check_time=$(dbus_get_or_empty cpa_last_check_time)
  [ -n "$last_check_time" ] || last_check_time='-'

  port=$(get_service_port)
  ui_path=/management.html
  management_key=$(read_management_key 2>/dev/null || printf '%s' cpa-merlin)

  printf '{"success":true,"running":%s,"version":"%s","latestVersion":"%s","updateAvailable":%s,"lastCheckTime":"%s","port":%s,"uiPath":"%s","managementKey":"%s"}' \
    "$running" \
    "$(json_escape "$current_version")" \
    "$(json_escape "$latest_version")" \
    "$update_available" \
    "$(json_escape "$last_check_time")" \
    "$port" \
    "$(json_escape "$ui_path")" \
    "$(json_escape "$management_key")"
}

case "$1" in
  start|stop|restart)
    run_action "$1"
    ;;
  status)
    status_json
    ;;
  check-update)
    run_update_check
    ;;
  update)
    output=$(sh "$UPDATE_SCRIPT" update 2>&1) && {
      [ -n "$output" ] && json_ok "$output" || json_ok "update"
      exit 0
    }

    [ -n "$output" ] && json_err "$output" || json_err "update failed"
    exit 1
    ;;
  *)
    json_err "unknown action"
    exit 1
    ;;
esac
