#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
SCRIPT_PATH="$ROOT_DIR/scripts/cpa_runtime.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_eq() {
  expected="$1"
  actual="$2"
  message="$3"
  if [ "$expected" != "$actual" ]; then
    fail "$message (expected: $expected, actual: $actual)"
  fi
}

assert_file_contains() {
  file_path="$1"
  needle="$2"
  message="$3"
  if ! grep -Fq "$needle" "$file_path"; then
    fail "$message (missing: $needle)"
  fi
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

export CPA_ROOT="$TMP_DIR/cpa"
export CPA_APP_DIR="$CPA_ROOT/app"
export CPA_WEB_DIR="$CPA_ROOT/web"
export CPA_DATA_DIR="$CPA_ROOT/data"
export CPA_LOG_DIR="$CPA_ROOT/logs"
export CPA_BACKUP_DIR="$CPA_ROOT/backup"
export CPA_PACKAGE_DIR="$CPA_ROOT/package"
export CPA_AUTH_DIR="$CPA_DATA_DIR/auth"
export CPA_PID_FILE="$TMP_DIR/cpa.pid"
export CPA_CONFIG_TEMPLATE="$CPA_APP_DIR/config.example.yaml"

mkdir -p "$CPA_APP_DIR" "$CPA_DATA_DIR"
cat > "$CPA_CONFIG_TEMPLATE" <<'EOF'
port: 3210
server:
  allow-remote: false
  secret-key: "bootstrap"
auth-dir: "/tmp/bootstrap-auth"
EOF

set --
. "$SCRIPT_PATH"

expected_config_path="$CPA_DATA_DIR/config.yaml"
actual_config_path="$(get_cpa_config_file)"
assert_eq "$expected_config_path" "$actual_config_path" "config.yaml 应位于 data 目录"

ensure_cpa_config 4321
assert_file_contains "$actual_config_path" 'port: 4321' '首次生成的配置应写入目标端口'
assert_file_contains "$actual_config_path" 'auth-dir: "'$CPA_AUTH_DIR'"' '首次生成的配置应写入 data/auth 路径'

cat > "$actual_config_path" <<'EOF'
port: 7788
server:
  allow-remote: true
  secret-key: "custom-key"
auth-dir: "/custom/auth"
custom-field: keep-me
EOF

ensure_cpa_config 9999
assert_file_contains "$actual_config_path" 'port: 7788' '已有配置不应被新的 dbus 端口覆盖'
assert_file_contains "$actual_config_path" 'custom-field: keep-me' '已有自定义配置不应被重写'

mkdir -p "$CPA_LOG_DIR"
cat > "$CPA_APP_DIR/$CPA_BINARY_NAME" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$CPA_APP_DIR/$CPA_BINARY_NAME"

waited_port=''
wait_for_cpa_listen() {
  waited_port="$2"
  return 0
}

start_cpa_process 3210 >/dev/null
assert_eq "7788" "$waited_port" "已有配置存在时应按配置文件中的端口启动"

printf 'PASS\n'
