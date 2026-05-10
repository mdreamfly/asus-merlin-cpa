#!/bin/sh
set -e

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

for path in \
  install.sh \
  uninstall.sh \
  version \
  .valid \
  scripts/cpa_platform.sh \
  scripts/cpa_runtime.sh \
  scripts/cpa_config.sh \
  scripts/cpa_api.sh \
  scripts/cpa_update.sh \
  scripts/repack.sh \
  scripts/check_syntax.sh \
  scripts/check_layout.sh \
  webs/Module_cpa.asp \
  webs/cpa_cgi.cgi \
  res/icon-cpa.png \
  assets/aarch64/CLIProxyAPI.tar.gz
 do
  test -e "$ROOT_DIR/$path"
 done
