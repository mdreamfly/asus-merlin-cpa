#!/bin/sh
set -e

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
VERSION_FILE=${VERSION_FILE:-/koolshare/cpa/version}
CPA_RELEASE_LATEST_PAGE=${CPA_RELEASE_LATEST_PAGE:-https://github.com/router-for-me/CLIProxyAPI/releases/latest}
CPA_RELEASE_DOWNLOAD_BASE=${CPA_RELEASE_DOWNLOAD_BASE:-https://github.com/router-for-me/CLIProxyAPI/releases/download}
CPA_BUNDLED_RUNTIME_VERSION=${CPA_BUNDLED_RUNTIME_VERSION:-6.10.9}

. "$SCRIPT_DIR/cpa_platform.sh"
. "$SCRIPT_DIR/cpa_runtime.sh"

read_plugin_version() {
  if [ -f "$VERSION_FILE" ]; then
    tr -d '\r\n' < "$VERSION_FILE"
    return 0
  fi

  printf '0.1.0\n'
}

dbus_get_or_empty() {
  dbus get "$1" 2>/dev/null || true
}

dbus_set_if_available() {
  dbus set "$1=$2" >/dev/null 2>&1 || true
}

current_timestamp() {
  date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date
}

read_runtime_version() {
  version=$(dbus_get_or_empty cpa_runtime_version)
  if [ -n "$version" ]; then
    printf '%s\n' "$version"
    return 0
  fi

  printf '%s\n' "$CPA_BUNDLED_RUNTIME_VERSION"
}

find_executable() {
  name="$1"
  shift

  for candidate in "$@"; do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  old_ifs="$IFS"
  IFS=:
  for path_dir in $PATH; do
    [ -n "$path_dir" ] || continue
    candidate="$path_dir/$name"
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      IFS="$old_ifs"
      return 0
    fi
  done
  IFS="$old_ifs"

  return 1
}

run_downloader_to_file() {
  url="$1"
  output_path="$2"

  curl_bin=$(find_executable curl /usr/sbin/curl /usr/bin/curl /bin/curl /opt/bin/curl /opt/usr/bin/curl 2>/dev/null || true)
  if [ -n "$curl_bin" ]; then
    "$curl_bin" -fsSL "$url" -o "$output_path"
    return 0
  fi

  wget_bin=$(find_executable wget /usr/sbin/wget /usr/bin/wget /bin/wget /opt/bin/wget /opt/usr/bin/wget 2>/dev/null || true)
  if [ -n "$wget_bin" ]; then
    "$wget_bin" -qO "$output_path" "$url"
    return 0
  fi

  uclient_fetch_bin=$(find_executable uclient-fetch /usr/bin/uclient-fetch /bin/uclient-fetch /sbin/uclient-fetch /usr/sbin/uclient-fetch 2>/dev/null || true)
  if [ -n "$uclient_fetch_bin" ]; then
    "$uclient_fetch_bin" -q -O "$output_path" "$url"
    return 0
  fi

  busybox_bin=$(find_executable busybox /bin/busybox /usr/bin/busybox /sbin/busybox /usr/sbin/busybox 2>/dev/null || true)
  if [ -n "$busybox_bin" ] && "$busybox_bin" wget --help >/dev/null 2>&1; then
    "$busybox_bin" wget -qO "$output_path" "$url"
    return 0
  fi

  echo "missing downloader: curl, wget, uclient-fetch, or busybox wget" >&2
  return 1
}

run_downloader_to_stdout() {
  url="$1"

  curl_bin=$(find_executable curl /usr/sbin/curl /usr/bin/curl /bin/curl /opt/bin/curl /opt/usr/bin/curl 2>/dev/null || true)
  if [ -n "$curl_bin" ]; then
    "$curl_bin" -fsSL "$url"
    return 0
  fi

  wget_bin=$(find_executable wget /usr/sbin/wget /usr/bin/wget /bin/wget /opt/bin/wget /opt/usr/bin/wget 2>/dev/null || true)
  if [ -n "$wget_bin" ]; then
    "$wget_bin" -qO- "$url"
    return 0
  fi

  uclient_fetch_bin=$(find_executable uclient-fetch /usr/bin/uclient-fetch /bin/uclient-fetch /sbin/uclient-fetch /usr/sbin/uclient-fetch 2>/dev/null || true)
  if [ -n "$uclient_fetch_bin" ]; then
    "$uclient_fetch_bin" -q -O - "$url"
    return 0
  fi

  busybox_bin=$(find_executable busybox /bin/busybox /usr/bin/busybox /sbin/busybox /usr/sbin/busybox 2>/dev/null || true)
  if [ -n "$busybox_bin" ] && "$busybox_bin" wget --help >/dev/null 2>&1; then
    "$busybox_bin" wget -qO- "$url"
    return 0
  fi

  echo "missing downloader: curl, wget, uclient-fetch, or busybox wget" >&2
  return 1
}

fetch_url_to_file() {
  url="$1"
  output_path="$2"
  run_downloader_to_file "$url" "$output_path"
}

fetch_latest_release_page_to_file() {
  output_path="$1"
  fetch_url_to_file "$CPA_RELEASE_LATEST_PAGE" "$output_path"
}

extract_latest_version_from_file() {
  page_path="$1"
  grep -o '/releases/tag/v[0-9][0-9A-Za-z._-]*' "$page_path" | sed 's#.*/v##' | head -n 1
}

build_asset_url() {
  version="$1"
  suffix="$2"
  printf '%s/v%s/CLIProxyAPI_%s_%s.tar.gz\n' "$CPA_RELEASE_DOWNLOAD_BASE" "$version" "$version" "$suffix"
}

read_release_info() {
  platform=$(get_platform)
  suffix=$(get_release_asset_suffix "$platform") || {
    echo "unsupported platform" >&2
    return 1
  }

  tmp_dir="$CPA_BACKUP_DIR/update-meta"
  page_path="$tmp_dir/releases-latest.html"
  rm -rf "$tmp_dir"
  mkdir -p "$tmp_dir"

  fetch_latest_release_page_to_file "$page_path"
  latest_version=$(extract_latest_version_from_file "$page_path")
  [ -n "$latest_version" ] || {
    echo "failed to parse latest version" >&2
    return 1
  }

  asset_url=$(build_asset_url "$latest_version" "$suffix")
  printf '%s|%s\n' "$latest_version" "$asset_url"
}

check_update() {
  release_info=$(read_release_info)
  latest_version=${release_info%%|*}
  asset_url=${release_info#*|}
  current_version=$(read_runtime_version)
  plugin_version=$(read_plugin_version)

  dbus_set_if_available cpa_plugin_version "$plugin_version"
  dbus_set_if_available cpa_runtime_version "$current_version"
  dbus_set_if_available cpa_latest_version "$latest_version"
  dbus_set_if_available cpa_update_url "$asset_url"
  dbus_set_if_available cpa_last_check_time "$(current_timestamp)"

  if [ "$latest_version" = "$current_version" ]; then
    dbus_set_if_available cpa_update_available 0
  else
    dbus_set_if_available cpa_update_available 1
  fi

  printf '%s\n' "$latest_version"
}

backup_current() {
  rm -rf "$CPA_BACKUP_DIR/current"
  mkdir -p "$CPA_BACKUP_DIR"
  cp -a "$CPA_APP_DIR" "$CPA_BACKUP_DIR/current"
}

rollback_current() {
  rm -rf "$CPA_APP_DIR"
  cp -a "$CPA_BACKUP_DIR/current" "$CPA_APP_DIR"
}

validate_archive() {
  archive_path="$1"
  [ -f "$archive_path" ] || {
    echo "missing archive: $archive_path" >&2
    return 1
  }

  tar -tzf "$archive_path" >/dev/null 2>&1 || {
    echo "invalid archive: $archive_path" >&2
    return 1
  }
}

validate_app_layout() {
  binary_path="$CPA_APP_DIR/$CPA_BINARY_NAME"
  config_template_path="$CPA_APP_DIR/config.example.yaml"

  [ -f "$binary_path" ] || {
    echo "missing binary after update: $binary_path" >&2
    return 1
  }

  [ -x "$binary_path" ] || chmod +x "$binary_path" || {
    echo "binary not executable after update: $binary_path" >&2
    return 1
  }

  [ -f "$config_template_path" ] || {
    echo "missing config template after update: $config_template_path" >&2
    return 1
  }
}

download_release() {
  release_info="$1"
  asset_url=${release_info#*|}
  tmp_dir="$CPA_BACKUP_DIR/update-tmp"
  archive_path="$tmp_dir/CLIProxyAPI.tar.gz"

  rm -rf "$tmp_dir"
  mkdir -p "$tmp_dir"
  fetch_url_to_file "$asset_url" "$archive_path"
  validate_archive "$archive_path"
  printf '%s\n' "$archive_path"
}

replace_release_files() {
  archive_path="$1"
  validate_archive "$archive_path"

  rm -rf "$CPA_APP_DIR"
  mkdir -p "$CPA_APP_DIR"
  tar -xzf "$archive_path" -C "$CPA_APP_DIR"
  validate_app_layout
}

update_release() {
  release_info=$(read_release_info)
  latest_version=${release_info%%|*}
  current_version=$(read_runtime_version)

  dbus_set_if_available cpa_latest_version "$latest_version"
  dbus_set_if_available cpa_update_url "${release_info#*|}"
  dbus_set_if_available cpa_last_check_time "$(current_timestamp)"

  if [ "$latest_version" = "$current_version" ]; then
    dbus_set_if_available cpa_update_available 0
    echo "already latest:$current_version"
    return 0
  fi

  backup_current
  archive_path=$(download_release "$release_info")
  sh "$SCRIPT_DIR/cpa_config.sh" stop >/dev/null 2>&1 || true
  replace_release_files "$archive_path"
  dbus_set_if_available cpa_runtime_version "$latest_version"

  if sh "$SCRIPT_DIR/cpa_config.sh" start >/dev/null 2>&1; then
    dbus_set_if_available cpa_latest_version "$latest_version"
    dbus_set_if_available cpa_update_available 0
    echo "updated:$latest_version"
    return 0
  fi

  rollback_current
  validate_app_layout
  dbus_set_if_available cpa_runtime_version "$current_version"
  sh "$SCRIPT_DIR/cpa_config.sh" start >/dev/null 2>&1 || true
  echo "update failed, rolled back" >&2
  return 1
}

api_response() {
  http_response_bin=$(find_executable http_response /koolshare/bin/http_response /usr/bin/http_response /bin/http_response 2>/dev/null || true)
  if [ -n "$http_response_bin" ]; then
    "$http_response_bin" "$1"
    return 0
  fi

  printf '%s\n' "$1"
}

case "$2" in
  check)
    api_response "$1"
    check_update >/dev/null 2>&1 || true
    exit 0
    ;;
  update)
    api_response "$1"
    update_release >/dev/null 2>&1 || true
    exit 0
    ;;
esac

case "$1" in
  check)
    check_update
    ;;
  update)
    update_release
    ;;
  *)
    echo "Usage: $0 {check|update}" >&2
    exit 1
    ;;
esac
