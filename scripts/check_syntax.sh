#!/bin/sh
set -e

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

sh -n "$ROOT_DIR/install.sh"
sh -n "$ROOT_DIR/uninstall.sh"

for file in "$ROOT_DIR"/scripts/*.sh "$ROOT_DIR"/webs/cpa_cgi.cgi; do
  [ -f "$file" ] || continue
  sh -n "$file"
done
