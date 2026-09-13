#!/bin/sh
set -eu

HERE=$(dirname "$(readlink -f "$0")")
export LD_LIBRARY_PATH="$HERE/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$HERE"

# Ensure WebKit can find a working bubblewrap sandbox and dbus proxy.
# If bubblewrap is unavailable, non-functional (e.g. unprivileged user namespaces
# disabled in kernel or container), or xdg-dbus-proxy is missing, gracefully disable
# the WebKit sandbox so looking up words does not abort with SIGTRAP.
if [ -z "${WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS:-}" ]; then
  BWRAP_BIN=""
  if [ -x "/usr/bin/bwrap" ]; then
    BWRAP_BIN="/usr/bin/bwrap"
  elif [ -x "/usr/sbin/bwrap" ]; then
    BWRAP_BIN="/usr/sbin/bwrap"
  elif command -v bwrap >/dev/null 2>&1; then
    BWRAP_BIN="$(command -v bwrap)"
  fi

  HAS_DBUS_PROXY=0
  if [ -x "/usr/bin/xdg-dbus-proxy" ] || [ -x "/usr/sbin/xdg-dbus-proxy" ] || command -v xdg-dbus-proxy >/dev/null 2>&1; then
    HAS_DBUS_PROXY=1
  fi

  NEEDS_SBIN_BWRAP=0
  if [ -f "$HERE/lib/libWPEWebKit-2.0.so.1" ]; then
    if grep -Fq "/usr/sbin/bwrap" "$HERE/lib/libWPEWebKit-2.0.so.1" 2>/dev/null; then
      NEEDS_SBIN_BWRAP=1
    fi
  fi

  if [ -z "$BWRAP_BIN" ] || [ "$HAS_DBUS_PROXY" -ne 1 ] || ! "$BWRAP_BIN" --ro-bind / / true >/dev/null 2>&1 || { [ "$NEEDS_SBIN_BWRAP" -eq 1 ] && [ ! -x "/usr/sbin/bwrap" ]; }; then
    export WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1
  fi
fi

exec "$HERE/ciyue.bin" "$@"
