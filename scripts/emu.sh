#!/usr/bin/env bash
# Runs the Pleos Connect emulator outside Android Studio.
set -euo pipefail

SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
AVD="${PLEOS_AVD:-pleos_connect}"
EMULATOR="$SDK/emulator/emulator"
ADB="$SDK/platform-tools/adb"
LOG="${TMPDIR:-/tmp}/pleos-emulator.log"
CONSOLE_PORT="${PLEOS_CONSOLE_PORT:-8282}"

case "${1:-}" in
  start)
    if "$ADB" devices | grep -q '^emulator-'; then
      echo "Emulator already running."; exit 0
    fi
    # -no-snapshot: always cold boot (required for VHAL) and never write a RAM snapshot to disk
    nohup "$EMULATOR" -avd "$AVD" -no-snapshot -no-boot-anim -gpu host >"$LOG" 2>&1 &
    echo "Started $AVD (pid $!). Log: $LOG"
    ;;
  wait)
    "$ADB" wait-for-device
    until [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
    echo "Boot completed."
    ;;
  stop)
    "$ADB" emu kill 2>/dev/null || echo "No emulator running."
    ;;
  status)
    "$ADB" devices -l
    ;;
  console)
    # The Virtual Console listens on 8088 inside the guest; only the host side is configurable.
    "$ADB" forward "tcp:$CONSOLE_PORT" tcp:8088 >/dev/null
    echo "Virtual Console: http://127.0.0.1:$CONSOLE_PORT"
    open "http://127.0.0.1:$CONSOLE_PORT"
    ;;
  *)
    echo "usage: $0 {start|wait|stop|status|console}"; exit 1
    ;;
esac
