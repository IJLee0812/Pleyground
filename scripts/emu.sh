#!/usr/bin/env bash
# Pleos Connect emulator from the terminal (macOS / Linux).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
case "$(uname -s)" in
  Darwin) DEFAULT_SDK="$HOME/Library/Android/sdk" ;;
  *) DEFAULT_SDK="$HOME/Android/Sdk" ;;
esac
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$DEFAULT_SDK}}"
EMULATOR="$SDK/emulator/emulator"
ADB="$SDK/platform-tools/adb"
LOG="${TMPDIR:-/tmp}/pleos-emulator.log"
AVD="${PLEOS_AVD:-}"
GPU="${PLEOS_GPU:-host}"
CONSOLE_PORT="${PLEOS_CONSOLE_PORT:-8282}"
# Package to launch: PLEOS_APP, or the applicationId in app/build.gradle.kts.
APP="${PLEOS_APP:-$(sed -n 's/^ *applicationId *= *"\(.*\)".*/\1/p' "$ROOT/app/build.gradle.kts")}"
# Area the app gets on the 2560x1440 display (left, top, width, height), outside the system bars.
CROP="854 93 1678 1206"

find_avd() {
  [ -n "$AVD" ] || AVD="$("$EMULATOR" -list-avds | grep -i pleos | head -n 1 || true)"
  [ -n "$AVD" ] || { echo "No AVD with 'pleos' in its name. Set PLEOS_AVD."; exit 1; }
}

browse() {
  if command -v open >/dev/null; then open "$1"; elif command -v xdg-open >/dev/null; then xdg-open "$1"; fi
}

on_top() {
  "$ADB" shell dumpsys activity activities | grep topResumedActivity | grep -q "$APP/"
}

case "${1:-}" in
  start)
    if "$ADB" devices | grep -q '^emulator-'; then
      echo "Emulator already running."; exit 0
    fi
    find_avd
    # -no-snapshot: always cold boot (required for VHAL) and never write a RAM snapshot to disk
    nohup "$EMULATOR" -avd "$AVD" -no-snapshot -no-boot-anim -gpu "$GPU" >"$LOG" 2>&1 &
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
    browse "http://127.0.0.1:$CONSOLE_PORT"
    ;;
  launch)
    "$ADB" shell am start -n "$APP/.MainActivity"
    ;;
  run)
    (cd "$ROOT" && ./gradlew -q installDebug)
    "$ADB" shell am force-stop "$APP"
    # System apps may grab the screen after boot or a theme change; retry a few times.
    for _ in 1 2 3 4 5; do
      "$ADB" shell am start -n "$APP/.MainActivity" >/dev/null 2>&1
      sleep 3
      if on_top; then echo "$APP is in front."; exit 0; fi
    done
    echo "$APP did not stay in front. Run 'launch' to retry."; exit 1
    ;;
  theme)
    case "${2:-}" in
      day|night|sensor) "$ADB" shell cmd car_service day-night-mode "$2" ;;
      *) echo "usage: $0 theme {day|night|sensor}"; exit 1 ;;
    esac
    ;;
  anim)
    factor="${2:-1}"
    for key in animator_duration_scale transition_animation_scale window_animation_scale; do
      "$ADB" shell settings put global "$key" "$factor"
    done
    echo "Animations x$factor (1 = normal)."
    ;;
  shot)
    file="${2:-shot.png}"
    "$ADB" exec-out screencap -p >"$file"
    read -r left top width height <<<"$CROP"
    if command -v sips >/dev/null; then
      sips -c "$height" "$width" --cropOffset "$top" "$left" "$file" >/dev/null
    elif command -v magick >/dev/null; then
      magick "$file" -crop "${width}x${height}+${left}+${top}" +repage "$file"
    else
      echo "sips or ImageMagick needed to crop; saved the whole display."
    fi
    echo "Saved $file"
    ;;
  *)
    echo "usage: $0 {start|wait|stop|status|console|launch|run|theme|anim|shot}"; exit 1
    ;;
esac
