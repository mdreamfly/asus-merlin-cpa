#!/bin/sh

SCRIPT_DIR=/koolshare/scripts
LOCAL_SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)/../scripts"

if [ ! -f "$SCRIPT_DIR/cpa_api.sh" ] && [ -f "$LOCAL_SCRIPT_DIR/cpa_api.sh" ]; then
  SCRIPT_DIR="$LOCAL_SCRIPT_DIR"
fi

urldecode() {
  value=$(printf '%s' "$1" | sed 's/+/ /g; s/%/\\x/g')
  printf '%b' "$value"
}

get_action() {
  if [ -n "$1" ]; then
    printf '%s\n' "$1"
    return 0
  fi

  query=${QUERY_STRING:-}
  case "$query" in
    action=*)
      value=${query#action=}
      value=${value%%&*}
      urldecode "$value"
      return 0
      ;;
    *'&action='*)
      value=${query#*'&action='}
      value=${value%%&*}
      urldecode "$value"
      return 0
      ;;
    *)
      printf 'status\n'
      return 0
      ;;
  esac
}

printf 'Content-Type: application/json\r\n\r\n'
action=$(get_action "$1")
sh "$SCRIPT_DIR/cpa_api.sh" "$action" || true
