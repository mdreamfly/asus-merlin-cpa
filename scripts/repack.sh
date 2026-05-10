#!/bin/sh
set -e

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
TMP_DIR="$ROOT_DIR/.tmp/repack"
VERSION="$(tr -d '\r\n' < "$ROOT_DIR/version")"
PKG_BASENAME="asus-merlin-cpa-${VERSION}-repack1"
PKG_ROOT="$TMP_DIR/$PKG_BASENAME/cpa"
PKG_FILE="$DIST_DIR/${PKG_BASENAME}.tar.gz"

fail() {
  echo "repack.sh: $*" >&2
  exit 1
}

require_file() {
  [ -f "$1" ] || fail "missing required file: $1"
}

mkdir -p "$DIST_DIR"
rm -rf "$TMP_DIR"
mkdir -p "$PKG_ROOT/scripts" "$PKG_ROOT/webs" "$PKG_ROOT/res" "$PKG_ROOT/assets/aarch64"

sh "$ROOT_DIR/scripts/check_layout.sh"
sh "$ROOT_DIR/scripts/check_syntax.sh"

tar -tzf "$ROOT_DIR/assets/aarch64/CLIProxyAPI.tar.gz" >/dev/null 2>&1 || fail "invalid runtime archive"
tar -tzf "$ROOT_DIR/assets/aarch64/CLIProxyAPI.tar.gz" | grep -Eq '(^|/)cli-proxy-api$' || fail "runtime archive missing cli-proxy-api"

require_file "$ROOT_DIR/install.sh"
require_file "$ROOT_DIR/uninstall.sh"
require_file "$ROOT_DIR/version"
require_file "$ROOT_DIR/.valid"
require_file "$ROOT_DIR/res/icon-cpa.png"
require_file "$ROOT_DIR/res/cpa-menu.js"
require_file "$ROOT_DIR/webs/Module_cpa.asp"
require_file "$ROOT_DIR/webs/cpa_cgi.cgi"

cp -f "$ROOT_DIR/install.sh" "$PKG_ROOT/"
cp -f "$ROOT_DIR/uninstall.sh" "$PKG_ROOT/"
cp -f "$ROOT_DIR/version" "$PKG_ROOT/"
cp -f "$ROOT_DIR/.valid" "$PKG_ROOT/"
cp -f "$ROOT_DIR/res/icon-cpa.png" "$PKG_ROOT/res/"
cp -f "$ROOT_DIR/res/cpa-menu.js" "$PKG_ROOT/res/"
cp -f "$ROOT_DIR/webs/Module_cpa.asp" "$PKG_ROOT/webs/"
cp -f "$ROOT_DIR/webs/cpa_cgi.cgi" "$PKG_ROOT/webs/"
cp -f "$ROOT_DIR/assets/aarch64/CLIProxyAPI.tar.gz" "$PKG_ROOT/assets/aarch64/"
cp -f "$ROOT_DIR/scripts/"*.sh "$PKG_ROOT/scripts/"

rm -f "$PKG_FILE"
(
  cd "$TMP_DIR/$PKG_BASENAME" &&
  tar -czf "$PKG_FILE" cpa
)

tar -tzf "$PKG_FILE" >/dev/null 2>&1 || fail "generated package is unreadable"
tar -tzf "$PKG_FILE" | grep -q '^cpa/res/icon-cpa.png$' || fail "generated package missing icon"
tar -tzf "$PKG_FILE" | grep -q '^cpa/assets/aarch64/CLIProxyAPI.tar.gz$' || fail "generated package missing bundled runtime"
if tar -tzf "$PKG_FILE" | grep -q '^cpa/bin64/'; then
  fail "generated package contains legacy bin64 directory"
fi

printf '%s\n' "$PKG_FILE"
