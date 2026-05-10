#!/bin/sh
set -e

if [ -f /koolshare/scripts/base.sh ]; then
  . /koolshare/scripts/base.sh 2>/dev/null || true
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/cpa_runtime.sh"

dbus_get_or_empty() {
  dbus get "$1" 2>/dev/null || true
}

dbus_set_if_available() {
  dbus set "$1=$2" >/dev/null 2>&1 || true
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

start_service() {
  ensure_runtime_dirs
  port=$(get_service_port)

  if cpa_process_status >/dev/null 2>&1; then
    pid=$(read_pid)
    dbus_set_if_available cpa_enable 1
    dbus_set_if_available cpa_status running
    printf 'running:%s\n' "$pid"
    return 0
  fi

  if is_port_in_use "$port"; then
    echo "port in use:$port" >&2
    return 1
  fi

  pid=$(start_cpa_process "$port")
  dbus_set_if_available cpa_enable 1
  dbus_set_if_available cpa_status running
  printf 'running:%s\n' "$pid"
}

stop_service() {
  stop_cpa_process
  dbus_set_if_available cpa_enable 0
  dbus_set_if_available cpa_status stopped
  printf 'stopped\n'
}

status_service() {
  if cpa_process_status; then
    dbus_set_if_available cpa_status running
    return 0
  fi

  dbus_set_if_available cpa_status stopped
  return 1
}

api_response() {
  if command -v http_response >/dev/null 2>&1; then
    http_response "$1"
    return 0
  fi

  printf '%s\n' "$1"
}

case "$2" in
  start)
    api_response "$1"
    start_service >/dev/null 2>&1 || true
    exit 0
    ;;
  stop)
    api_response "$1"
    stop_service >/dev/null 2>&1 || true
    exit 0
    ;;
  restart)
    api_response "$1"
    stop_service >/dev/null 2>&1 || true
    start_service >/dev/null 2>&1 || true
    exit 0
    ;;
  status)
    api_response "$1"
    status_service >/dev/null 2>&1 || true
    exit 0
    ;;
esac

case "$1" in
  start)
    start_service
    ;;
  stop)
    stop_service
    ;;
  restart)
    stop_service
    start_service
    ;;
  status)
    status_service
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac
