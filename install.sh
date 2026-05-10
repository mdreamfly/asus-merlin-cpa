#!/bin/sh
set -e

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
MODULE=cpa
CLI_PROXY_API_BIN=cli-proxy-api
KS_ROOT=/koolshare
KS_SCRIPTS_DIR=$KS_ROOT/scripts
KS_WEBS_DIR=$KS_ROOT/webs
KS_RES_DIR=$KS_ROOT/res
KS_INITD_DIR=$KS_ROOT/init.d
CPA_ROOT=$KS_ROOT/$MODULE
VERSION_FILE=$SCRIPT_DIR/version
CPA_BUNDLED_RUNTIME_VERSION=6.10.9
INSTALL_WORKDIR=
INSTALL_COMMITTED=0

if [ -f /koolshare/scripts/base.sh ]; then
  . /koolshare/scripts/base.sh 2>/dev/null || true
fi

. "$SCRIPT_DIR/scripts/cpa_platform.sh"

fail() {
  echo "install.sh: $*" >&2
  exit 1
}

ensure_softcenter_env() {
  [ -d "$KS_ROOT" ] || fail "缺少 $KS_ROOT，当前环境不是受支持的 softcenter/asuswrt-merlin 环境"
  [ -x /koolshare/bin/httpdb ] || fail "缺少可执行文件 /koolshare/bin/httpdb，softcenter 环境不完整"
  [ -x /usr/bin/skipd ] || fail "缺少可执行文件 /usr/bin/skipd，softcenter 环境不完整"
}

ensure_supported_platform() {
  if ! assert_supported_platform; then
    fail "当前阶段仅支持 aarch64：machine_arch=$(get_machine_arch), platform=$(get_platform), kernel_family=$(get_kernel_family)"
  fi
}

prepare_target_dirs() {
  mkdir -p "$KS_SCRIPTS_DIR" "$KS_WEBS_DIR" "$KS_RES_DIR" "$KS_INITD_DIR"
  mkdir -p "$CPA_ROOT" "$CPA_ROOT/web" "$CPA_ROOT/data" "$CPA_ROOT/logs" "$CPA_ROOT/backup"
}

get_asset_archive_path() {
  platform="$1"
  printf '%s\n' "$SCRIPT_DIR/assets/$platform/CLIProxyAPI.tar.gz"
}

read_version() {
  tr -d '\r\n' < "$VERSION_FILE"
}

dbus_get_or_empty() {
  dbus get "$1" 2>/dev/null || true
}

dbus_set_value() {
  dbus set "$1=$2" >/dev/null 2>&1 || true
}

dbus_set_default() {
  key="$1"
  value="$2"
  current_value=$(dbus_get_or_empty "$key")

  if [ -z "$current_value" ]; then
    dbus_set_value "$key" "$value"
  fi
}

generate_management_key() {
  if [ -r /proc/sys/kernel/random/uuid ]; then
    tr -d '\r\n' < /proc/sys/kernel/random/uuid
    return 0
  fi

  if [ -r /dev/urandom ] && command -v od >/dev/null 2>&1; then
    od -An -N16 -tx1 /dev/urandom | tr -d ' \n'
    return 0
  fi

  printf 'cpa-%s\n' "$(date +%s)"
}

create_install_workspace() {
  if command -v mktemp >/dev/null 2>&1; then
    INSTALL_WORKDIR=$(mktemp -d /tmp/cpa-install.XXXXXX)
    return 0
  fi

  INSTALL_WORKDIR="/tmp/cpa-install.$$"
  rm -rf "$INSTALL_WORKDIR"
  mkdir -p "$INSTALL_WORKDIR"
}

require_file() {
  path="$1"
  [ -f "$path" ] || fail "安装包缺少必需文件：$path"
}

stage_script_files() {
  stage_scripts_dir="$1/scripts"
  mkdir -p "$stage_scripts_dir"

  found=0
  for src in "$SCRIPT_DIR"/scripts/*.sh; do
    [ -f "$src" ] || continue
    cp -f "$src" "$stage_scripts_dir/"
    found=1
  done

  [ "$found" -eq 1 ] || fail "安装包缺少 scripts/*.sh"
}

resolve_package_file() {
  for candidate in "$@"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

stage_static_files() {
  stage_root="$1"
  module_asp=$(resolve_package_file "$SCRIPT_DIR/Module_cpa.asp" "$SCRIPT_DIR/webs/Module_cpa.asp") || fail "安装包缺少 Module_cpa.asp"
  cgi_file=$(resolve_package_file "$SCRIPT_DIR/cpa_cgi.cgi" "$SCRIPT_DIR/webs/cpa_cgi.cgi") || fail "安装包缺少 cpa_cgi.cgi"
  icon_file=$(resolve_package_file "$SCRIPT_DIR/icon-cpa.png" "$SCRIPT_DIR/res/icon-cpa.png") || fail "安装包缺少 icon-cpa.png"
  menu_file=$(resolve_package_file "$SCRIPT_DIR/cpa-menu.js" "$SCRIPT_DIR/res/cpa-menu.js") || fail "安装包缺少 cpa-menu.js"

  require_file "$VERSION_FILE"
  require_file "$SCRIPT_DIR/.valid"

  mkdir -p "$stage_root/webs" "$stage_root/res"
  cp -f "$module_asp" "$stage_root/webs/Module_cpa.asp"
  cp -f "$cgi_file" "$stage_root/webs/cpa_cgi.cgi"
  cp -f "$icon_file" "$stage_root/res/icon-cpa.png"
  cp -f "$menu_file" "$stage_root/res/cpa-menu.js"
  cp -f "$VERSION_FILE" "$stage_root/"
  cp -f "$SCRIPT_DIR/.valid" "$stage_root/"
}

stage_runtime_payload() {
  stage_package_dir="$1/cpa/package"
  platform="$(get_platform)"
  archive_path="$(get_asset_archive_path "$platform")"

  [ "$platform" != "unsupported" ] || fail "当前平台缺少内置资产目录映射：machine_arch=$(get_machine_arch)"
  [ -f "$archive_path" ] || fail "缺少平台资产包：$archive_path"

  tar -tzf "$archive_path" >/dev/null 2>&1 || fail "平台资产包无法读取：$archive_path"
  tar -tzf "$archive_path" | grep -Eq '(^|/)cli-proxy-api$' || fail "平台资产包缺少 cli-proxy-api"
  tar -tzf "$archive_path" | grep -Eq '(^|/)config\.example\.yaml$' || fail "平台资产包缺少 config.example.yaml"

  mkdir -p "$stage_package_dir"
  cp -f "$archive_path" "$stage_package_dir/CLIProxyAPI.tar.gz"
}

stage_plugin_payload() {
  stage_root="$INSTALL_WORKDIR/stage"
  mkdir -p "$stage_root/cpa/app" "$stage_root/cpa/package" "$stage_root/cpa/web" "$stage_root/cpa/data" "$stage_root/cpa/logs" "$stage_root/cpa/backup"
  stage_script_files "$stage_root"
  stage_static_files "$stage_root"
  stage_runtime_payload "$stage_root"
}

backup_existing_state() {
  backup_root="$INSTALL_WORKDIR/backup"
  mkdir -p "$backup_root"

  if [ -e "$CPA_ROOT" ]; then
    mkdir -p "$backup_root/cpa-root"
    cp -a "$CPA_ROOT/." "$backup_root/cpa-root/"
  fi

  for target in \
    "$KS_WEBS_DIR/Module_cpa.asp" \
    "$KS_WEBS_DIR/cpa_cgi.cgi" \
    "$KS_RES_DIR/icon-cpa.png"
  do
    if [ -e "$target" ]; then
      mkdir -p "$backup_root$(dirname "$target")"
      cp -a "$target" "$backup_root$target"
    fi
  done

  if [ -d "$KS_SCRIPTS_DIR" ]; then
    mkdir -p "$backup_root$KS_SCRIPTS_DIR"
    for target in "$KS_SCRIPTS_DIR"/cpa_*.sh; do
      [ -e "$target" ] || continue
      cp -a "$target" "$backup_root$target"
    done
  fi
}

restore_existing_state() {
  backup_root="$INSTALL_WORKDIR/backup"

  rm -f "$KS_WEBS_DIR/Module_cpa.asp"
  rm -f "$KS_WEBS_DIR/cpa_cgi.cgi"
  rm -f "$KS_RES_DIR/icon-cpa.png"
  rm -f "$KS_SCRIPTS_DIR"/cpa_*.sh
  rm -rf "$CPA_ROOT"

  if [ -d "$backup_root/cpa-root" ]; then
    mkdir -p "$CPA_ROOT"
    cp -a "$backup_root/cpa-root/." "$CPA_ROOT/"
  fi

  for target in \
    "$KS_WEBS_DIR/Module_cpa.asp" \
    "$KS_WEBS_DIR/cpa_cgi.cgi" \
    "$KS_RES_DIR/icon-cpa.png"
  do
    if [ -e "$backup_root$target" ]; then
      mkdir -p "$(dirname "$target")"
      cp -a "$backup_root$target" "$target"
    fi
  done

  if [ -d "$backup_root$KS_SCRIPTS_DIR" ]; then
    for target in "$backup_root$KS_SCRIPTS_DIR"/cpa_*.sh; do
      [ -e "$target" ] || continue
      cp -a "$target" "$KS_SCRIPTS_DIR/"
    done
  fi
}

install_staged_payload() {
  stage_root="$INSTALL_WORKDIR/stage"
  prepare_target_dirs

  cp -f "$stage_root/scripts/"*.sh "$KS_SCRIPTS_DIR/"
  cp -f "$SCRIPT_DIR/install.sh" "$KS_SCRIPTS_DIR/cpa_install.sh"
  cp -f "$SCRIPT_DIR/uninstall.sh" "$KS_SCRIPTS_DIR/uninstall_cpa.sh"
  cp -f "$stage_root/webs/Module_cpa.asp" "$KS_WEBS_DIR/"
  cp -f "$stage_root/webs/cpa_cgi.cgi" "$KS_WEBS_DIR/"
  cp -f "$stage_root/res/icon-cpa.png" "$KS_RES_DIR/"
  cp -f "$stage_root/res/cpa-menu.js" "$KS_RES_DIR/"

  chmod 755 "$KS_SCRIPTS_DIR"/cpa_*.sh 2>/dev/null || true
  chmod 755 "$KS_SCRIPTS_DIR/cpa_install.sh" "$KS_SCRIPTS_DIR/uninstall_cpa.sh" 2>/dev/null || true
  chmod 755 "$KS_WEBS_DIR/cpa_cgi.cgi" 2>/dev/null || true

  rm -rf "$CPA_ROOT/app" "$CPA_ROOT/package"
  mkdir -p "$CPA_ROOT/app" "$CPA_ROOT/package"
  cp -a "$stage_root/cpa/package/." "$CPA_ROOT/package/"
  cp -f "$stage_root/version" "$CPA_ROOT/version"
  mkdir -p "$CPA_ROOT/web" "$CPA_ROOT/data" "$CPA_ROOT/logs" "$CPA_ROOT/backup"

  # 皮肤适配
  ui_type=$(nvram get sc_skin 2>/dev/null || echo "")
  if [ "$ui_type" = "rog" ]; then
    sed -i 's/asuswrt.css/rog.css/g' "$KS_WEBS_DIR/Module_cpa.asp" 2>/dev/null || true
  elif [ "$ui_type" = "tuf" ]; then
    sed -i 's/asuswrt.css/tuf.css/g' "$KS_WEBS_DIR/Module_cpa.asp" 2>/dev/null || true
  fi
}

init_dbus_defaults() {
  version=$(read_version)

  dbus_set_default cpa_enable 0
  dbus_set_default cpa_port 3210
  dbus_set_default cpa_status stopped
  dbus_set_default cpa_management_key "$(generate_management_key)"
  dbus_set_default cpa_runtime_version "$CPA_BUNDLED_RUNTIME_VERSION"
  dbus_set_default cpa_latest_version "$CPA_BUNDLED_RUNTIME_VERSION"
  dbus_set_default cpa_update_available 0
  dbus_set_default cpa_last_check_time -
  dbus_set_value softcenter_module_cpa_install 1
  dbus_set_value softcenter_module_cpa_version "$version"
  dbus_set_value softcenter_module_cpa_title CLIProxyAPI
  dbus_set_value softcenter_module_cpa_description "CLIProxyAPI for Asus Merlin"
}

cleanup_install() {
  status=$?

  if [ "$status" -ne 0 ] && [ -n "$INSTALL_WORKDIR" ] && [ "$INSTALL_COMMITTED" -ne 1 ]; then
    restore_existing_state >/dev/null 2>&1 || true
  fi

  if [ -n "$INSTALL_WORKDIR" ] && [ -d "$INSTALL_WORKDIR" ]; then
    rm -rf "$INSTALL_WORKDIR"
  fi

  exit "$status"
}

main() {
  trap cleanup_install EXIT HUP INT TERM
  ensure_softcenter_env
  ensure_supported_platform
  create_install_workspace
  stage_plugin_payload
  backup_existing_state
  install_staged_payload
  init_dbus_defaults
  INSTALL_COMMITTED=1
  echo "install ok"
}

main "$@"
