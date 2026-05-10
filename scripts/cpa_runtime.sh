#!/bin/sh

CPA_ROOT=${CPA_ROOT:-/koolshare/cpa}
CPA_APP_DIR=${CPA_APP_DIR:-$CPA_ROOT/app}
CPA_WEB_DIR=${CPA_WEB_DIR:-$CPA_ROOT/web}
CPA_DATA_DIR=${CPA_DATA_DIR:-$CPA_ROOT/data}
CPA_LOG_DIR=${CPA_LOG_DIR:-$CPA_ROOT/logs}
CPA_BACKUP_DIR=${CPA_BACKUP_DIR:-$CPA_ROOT/backup}
CPA_PACKAGE_DIR=${CPA_PACKAGE_DIR:-$CPA_ROOT/package}
CPA_AUTH_DIR=${CPA_AUTH_DIR:-$CPA_DATA_DIR/auth}
CPA_PID_FILE=${CPA_PID_FILE:-/var/run/cpa.pid}
CPA_LOG_FILE=${CPA_LOG_FILE:-$CPA_LOG_DIR/cpa.log}
CPA_PORT_DEFAULT=${CPA_PORT_DEFAULT:-3210}
CPA_BINARY_NAME=${CPA_BINARY_NAME:-cli-proxy-api}
CPA_BUNDLE_ARCHIVE=${CPA_BUNDLE_ARCHIVE:-$CPA_PACKAGE_DIR/CLIProxyAPI.tar.gz}
CPA_CONFIG_TEMPLATE=${CPA_CONFIG_TEMPLATE:-$CPA_APP_DIR/config.example.yaml}
CPA_CONFIG_FILE=${CPA_CONFIG_FILE:-$CPA_DATA_DIR/config.yaml}
CPA_START_WAIT_SECONDS=${CPA_START_WAIT_SECONDS:-30}

ensure_runtime_dirs() {
  mkdir -p "$CPA_APP_DIR" "$CPA_WEB_DIR" "$CPA_DATA_DIR" "$CPA_LOG_DIR" "$CPA_BACKUP_DIR" "$CPA_PACKAGE_DIR"
}

read_pid() {
  if [ -f "$CPA_PID_FILE" ]; then
    pid=$(tr -d '[:space:]' < "$CPA_PID_FILE")
    case "$pid" in
      ''|*[!0-9]*)
        return 0
        ;;
      *)
        printf '%s\n' "$pid"
        ;;
    esac
  fi
  return 0
}

is_pid_running() {
  pid="$1"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

clear_pid_file() {
  rm -f "$CPA_PID_FILE"
}

clear_stale_pid_file() {
  pid=$(read_pid)
  if [ -n "$pid" ] && ! is_pid_running "$pid"; then
    clear_pid_file
  fi
}

get_cpa_binary() {
  binary="$CPA_APP_DIR/$CPA_BINARY_NAME"
  [ -f "$binary" ] || return 1
  printf '%s\n' "$binary"
}

get_cpa_config_template() {
  [ -f "$CPA_CONFIG_TEMPLATE" ] || return 1
  printf '%s\n' "$CPA_CONFIG_TEMPLATE"
}

get_cpa_config_file() {
  printf '%s\n' "$CPA_CONFIG_FILE"
}

extract_bundled_runtime() {
  [ -f "$CPA_BUNDLE_ARCHIVE" ] || {
    echo "missing bundled archive: $CPA_BUNDLE_ARCHIVE" >&2
    return 1
  }

  tar -tzf "$CPA_BUNDLE_ARCHIVE" >/dev/null 2>&1 || {
    echo "invalid bundled archive: $CPA_BUNDLE_ARCHIVE" >&2
    return 1
  }

  rm -rf "$CPA_APP_DIR"
  mkdir -p "$CPA_APP_DIR"
  tar -xzf "$CPA_BUNDLE_ARCHIVE" -C "$CPA_APP_DIR" || return 1

  binary="$CPA_APP_DIR/$CPA_BINARY_NAME"
  template="$CPA_APP_DIR/config.example.yaml"
  [ -f "$binary" ] || {
    echo "missing binary after extract: $binary" >&2
    return 1
  }
  [ -x "$binary" ] || chmod +x "$binary" || {
    echo "binary not executable after extract: $binary" >&2
    return 1
  }
  [ -f "$template" ] || {
    echo "missing config template after extract: $template" >&2
    return 1
  }
}

ensure_bundled_runtime_ready() {
  binary="$CPA_APP_DIR/$CPA_BINARY_NAME"
  template="$CPA_APP_DIR/config.example.yaml"

  if [ -f "$binary" ] && [ -f "$template" ]; then
    return 0
  fi

  extract_bundled_runtime
}

dbus_get_or_empty() {
  dbus get "$1" 2>/dev/null || true
}

read_management_key() {
  key=$(dbus_get_or_empty cpa_management_key)
  [ -n "$key" ] || return 1
  printf '%s\n' "$key"
}

write_cpa_config() {
  port="$1"
  template=$(get_cpa_config_template) || {
    echo "missing config template: $CPA_CONFIG_TEMPLATE" >&2
    return 1
  }
  config_file=$(get_cpa_config_file)
  tmp_file="$config_file.tmp"
  management_key=$(read_management_key 2>/dev/null || printf '%s' cpa-merlin)
  auth_dir="$CPA_AUTH_DIR"

  awk -v port="$port" -v management_key="$management_key" -v auth_dir="$auth_dir" '
    /^port:[[:space:]]*[0-9]+[[:space:]]*$/ && !port_done {
      print "port: " port
      port_done=1
      next
    }
    /^[[:space:]]*allow-remote:[[:space:]]*(true|false)[[:space:]]*$/ && !allow_remote_done {
      print "  allow-remote: true"
      allow_remote_done=1
      next
    }
    /^[[:space:]]*secret-key:[[:space:]]*".*"[[:space:]]*$/ && !secret_key_done {
      print "  secret-key: \"" management_key "\""
      secret_key_done=1
      next
    }
    /^auth-dir:[[:space:]]*".*"[[:space:]]*$/ && !auth_dir_done {
      print "auth-dir: \"" auth_dir "\""
      auth_dir_done=1
      next
    }
    { print }
    END {
      if (!port_done) {
        print "port: " port
      }
      if (!auth_dir_done) {
        print "auth-dir: \"" auth_dir "\""
      }
    }
  ' "$template" > "$tmp_file" || return 1

  mv "$tmp_file" "$config_file"
}

ensure_cpa_config() {
  port="$1"
  config_file=$(get_cpa_config_file)

  if [ -f "$config_file" ]; then
    return 0
  fi

  [ -n "$port" ] || port="$CPA_PORT_DEFAULT"
  write_cpa_config "$port"
}

read_configured_port() {
  config_file=$(get_cpa_config_file)
  [ -f "$config_file" ] || return 0

  port=$(awk -F: '/^port:[[:space:]]*[0-9]+[[:space:]]*$/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' "$config_file")
  case "$port" in
    ''|*[!0-9]*)
      return 0
      ;;
    *)
      printf '%s\n' "$port"
      ;;
  esac
}

port_to_hex() {
  port="$1"
  [ -n "$port" ] || return 1
  printf '%04X\n' "$port"
}

is_port_listening_in_procfs() {
  table_file="$1"
  port_hex="$2"
  [ -r "$table_file" ] || return 1

  awk -v port_hex="$port_hex" '
    NR > 1 {
      split($2, local_address, ":")
      if (local_address[2] == port_hex && $4 == "0A") {
        found = 1
        exit 0
      }
    }
    END {
      exit(found ? 0 : 1)
    }
  ' "$table_file" >/dev/null 2>&1
}

is_port_in_use() {
  port="$1"
  [ -n "$port" ] || return 1

  port_hex=$(port_to_hex "$port") || return 1

  if is_port_listening_in_procfs /proc/net/tcp "$port_hex"; then
    return 0
  fi

  if is_port_listening_in_procfs /proc/net/tcp6 "$port_hex"; then
    return 0
  fi

  if command -v netstat >/dev/null 2>&1; then
    netstat -ln 2>/dev/null | grep -Eq "[\.:]$port([[:space:]]|$)"
    return $?
  fi

  if command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | grep -Eq "[\.:]$port([[:space:]]|$)"
    return $?
  fi

  if command -v lsof >/dev/null 2>&1; then
    lsof -i TCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
    return $?
  fi

  return 1
}

wait_for_cpa_listen() {
  pid="$1"
  port="$2"
  attempts=0
  max_attempts="$CPA_START_WAIT_SECONDS"

  while [ "$attempts" -lt "$max_attempts" ]; do
    if ! is_pid_running "$pid"; then
      return 1
    fi

    if is_port_in_use "$port"; then
      return 0
    fi

    sleep 1
    attempts=$((attempts + 1))
  done

  return 1
}

start_cpa_process() {
  requested_port="${1:-$CPA_PORT_DEFAULT}"
  clear_stale_pid_file

  existing_port=$(read_configured_port)
  if [ -n "$existing_port" ]; then
    port="$existing_port"
  else
    port="$requested_port"
  fi

  pid=$(read_pid)
  if is_pid_running "$pid"; then
    if is_port_in_use "$port"; then
      printf '%s\n' "$pid"
      return 0
    fi

    echo "process running without listening port:$port" >&2
    return 1
  fi

  ensure_bundled_runtime_ready || return 1

  binary=$(get_cpa_binary) || {
    echo "missing binary: $CPA_APP_DIR/$CPA_BINARY_NAME" >&2
    return 1
  }

  ensure_cpa_config "$port" || return 1
  chmod +x "$binary" || return 1

  (
    cd "$CPA_APP_DIR" || exit 1
    "./$CPA_BINARY_NAME" --config "$CPA_CONFIG_FILE"
  ) >>"$CPA_LOG_FILE" 2>&1 &
  pid=$!
  printf '%s\n' "$pid" > "$CPA_PID_FILE"

  if wait_for_cpa_listen "$pid" "$port"; then
    printf '%s\n' "$pid"
    return 0
  fi

  kill "$pid" 2>/dev/null || true
  clear_pid_file
  echo "failed to start: $binary" >&2
  return 1
}

stop_cpa_process() {
  pid=$(read_pid)
  if [ -z "$pid" ]; then
    clear_pid_file
    return 0
  fi

  if is_pid_running "$pid"; then
    kill "$pid" 2>/dev/null || true

    attempts=0
    while [ "$attempts" -lt 5 ] && is_pid_running "$pid"; do
      sleep 1
      attempts=$((attempts + 1))
    done

    if is_pid_running "$pid"; then
      kill -9 "$pid" 2>/dev/null || true
      sleep 1
    fi

    # 等待进程完全退出（最多再等 5 秒）
    attempts=0
    while [ "$attempts" -lt 5 ] && is_pid_running "$pid"; do
      sleep 1
      attempts=$((attempts + 1))
    done

    # 等待端口完全释放（最多再等 5 秒）
    port=$(read_configured_port)
    [ -n "$port" ] || port="$CPA_PORT_DEFAULT"
    attempts=0
    while [ "$attempts" -lt 5 ] && is_port_in_use "$port"; do
      sleep 1
      attempts=$((attempts + 1))
    done
  fi

  clear_pid_file
  return 0
}

cpa_process_status() {
  clear_stale_pid_file

  pid=$(read_pid)
  if is_pid_running "$pid"; then
    port=$(read_configured_port)
    if [ -z "$port" ] || is_port_in_use "$port"; then
      printf 'running:%s\n' "$pid"
      return 0
    fi
  fi

  printf 'stopped\n'
  return 1
}
