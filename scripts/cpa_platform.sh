#!/bin/sh

get_kernel_family() {
  uname -r | awk -F. '{print $1$2}'
}

get_machine_arch() {
  uname -m
}

map_machine_arch_to_platform() {
  case "$1" in
    aarch64)
      echo "aarch64"
      ;;
    armv7l|armv7)
      echo "armv7"
      ;;
    armv6l|arm)
      echo "arm32"
      ;;
    *)
      echo "unsupported"
      ;;
  esac
}

get_platform() {
  map_machine_arch_to_platform "$(get_machine_arch)"
}

get_release_asset_suffix() {
  case "$1" in
    aarch64) echo "linux_aarch64" ;;
    armv7) echo "linux_armv7" ;;
    arm32) echo "linux_arm32" ;;
    *) return 1 ;;
  esac
}

platform_has_bundled_asset() {
  case "$1" in
    aarch64)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_supported_platform() {
  platform_has_bundled_asset "$(get_platform)"
}

assert_supported_platform() {
  is_supported_platform
}
