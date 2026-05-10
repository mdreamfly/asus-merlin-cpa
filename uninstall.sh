#!/bin/sh
set -e

if [ -f /koolshare/scripts/base.sh ]; then
  . /koolshare/scripts/base.sh 2>/dev/null || true
fi

stop_installed_service() {
  if [ -f /koolshare/scripts/cpa_config.sh ]; then
    sh /koolshare/scripts/cpa_config.sh stop >/dev/null 2>&1 || true
  fi
}

remove_plugin_files() {
  rm -f /koolshare/scripts/cpa_*.sh
  rm -f /koolshare/webs/Module_cpa.asp
  rm -f /koolshare/webs/cpa_cgi.cgi
  rm -f /koolshare/res/icon-cpa.png
  rm -f /koolshare/res/cpa-menu.js
  rm -rf /koolshare/cpa
  rm -rf /tmp/cpa-install.*
}

remove_dbus_keys() {
  if ! command -v dbus >/dev/null 2>&1; then
    return 0
  fi

  keys=$(dbus list cpa_ 2>/dev/null | cut -d= -f1 || true)
  for key in $keys; do
    dbus remove "$key" >/dev/null 2>&1 || true
  done

  for key in \
    softcenter_module_cpa_install \
    softcenter_module_cpa_version \
    softcenter_module_cpa_title \
    softcenter_module_cpa_description
  do
    dbus remove "$key" >/dev/null 2>&1 || true
  done
}

main() {
  stop_installed_service
  remove_plugin_files
  remove_dbus_keys
}

main "$@"
