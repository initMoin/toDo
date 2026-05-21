#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/toDo.xcodeproj"
SCHEME="ToDo Watch App"
CONFIGURATION="Debug"
BUNDLE_ID="dev.iamshift.toDo.watchkitapp"
DERIVED_DATA="$ROOT_DIR/Build/WatchScreenshotDerivedData"
OUTPUT_DIR="$ROOT_DIR/Build/WatchScreenshots/$(date +%Y%m%d-%H%M%S)"
WATCH_RUNTIME="${WATCH_RUNTIME:-com.apple.CoreSimulator.SimRuntime.watchOS-26-5}"

# Override from the command line when needed:
#   WATCH_DEVICES="Apple Watch Ultra 3 (49mm)" LOCALES="en,ar,es,hi,it,ja,ms,th,ur,zh-Hans" SCREENS="todos,settings,todo" Scripts/capture_watch_app_store_screenshots.sh
WATCH_DEVICES_CSV="${WATCH_DEVICES:-Apple Watch Ultra 3 (49mm),Apple Watch Series 11 (46mm),Apple Watch Series 9 (45mm),Apple Watch Series 6 (44mm),Apple Watch Series 3 (42mm)}"
LOCALES_CSV="${LOCALES:-en,ar,es,hi,it,ja,ms,th,ur,zh-Hans}"
SCREENS_CSV="${SCREENS:-todos,settings,todo}"

locale_identifier() {
  case "$1" in
    en) echo "en_US" ;;
    it) echo "it_IT" ;;
    ja) echo "ja_JP" ;;
    ms) echo "ms_MY" ;;
    th) echo "th_TH" ;;
    es) echo "es_ES" ;;
    hi) echo "hi_IN" ;;
    zh-Hans) echo "zh_Hans_CN" ;;
    ar) echo "ar_SA" ;;
    ur) echo "ur_PK" ;;
    *) echo "$1" ;;
  esac
}

sanitize() {
  echo "$1" | tr ' /()' '----' | tr -cd '[:alnum:]_.-'
}

watch_device_type_identifier() {
  case "$1" in
    "Apple Watch Ultra 3 (49mm)") echo "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Ultra-3-49mm" ;;
    "Apple Watch Series 11 (46mm)") echo "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-11-46mm" ;;
    "Apple Watch Series 9 (45mm)") echo "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-9-45mm" ;;
    "Apple Watch Series 6 (44mm)") echo "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-6-44mm" ;;
    "Apple Watch Series 3 (42mm)") echo "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-3-42mm" ;;
    *) return 1 ;;
  esac
}

find_device_udid() {
  local name="$1"
  xcrun simctl list devices available | awk -v name="$name" 'index($0, name) > 0 && match($0, /\([A-F0-9-]+\)/) { udid = substr($0, RSTART + 1, RLENGTH - 2); print udid; exit }'
}

ensure_watch_device() {
  local name="$1"
  local udid
  udid="$(find_device_udid "$name")"
  if [[ -n "$udid" ]]; then
    echo "$udid"
    return 0
  fi

  local device_type
  if ! device_type="$(watch_device_type_identifier "$name")"; then
    echo "Unsupported or unavailable watch screenshot simulator: $name" >&2
    return 1
  fi

  xcrun simctl create "$name" "$device_type" "$WATCH_RUNTIME"
}

IFS=',' read -r -a DEVICES <<< "$WATCH_DEVICES_CSV"
IFS=',' read -r -a LOCALES <<< "$LOCALES_CSV"
IFS=',' read -r -a SCREENS <<< "$SCREENS_CSV"

mkdir -p "$OUTPUT_DIR"

echo "Output: $OUTPUT_DIR"
for DEVICE in "${DEVICES[@]}"; do
  DEVICE="$(echo "$DEVICE" | sed 's/^ *//;s/ *$//')"
  DEVICE_SAFE="$(sanitize "$DEVICE")"
  DEVICE_DIR="$OUTPUT_DIR/$DEVICE_SAFE"
  mkdir -p "$DEVICE_DIR"

  DEVICE_UDID="$(ensure_watch_device "$DEVICE")"

  echo "Booting watch simulator: $DEVICE ($DEVICE_UDID)"
  xcrun simctl boot "$DEVICE_UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$DEVICE_UDID" -b >/dev/null

  echo "Building $SCHEME for $DEVICE..."
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk watchsimulator \
    -derivedDataPath "$DERIVED_DATA" \
    -destination "platform=watchOS Simulator,id=$DEVICE_UDID" \
    build >/tmp/todo-watch-screenshot-build.log

  APP_PATH="$(find "$DERIVED_DATA/Build/Products" -path "*${CONFIGURATION}-watchsimulator/ToDo Watch App.app" -type d | head -n 1)"
  if [[ -z "$APP_PATH" ]]; then
    echo "Could not find built ToDo Watch App.app under $DERIVED_DATA/Build/Products" >&2
    echo "Build log: /tmp/todo-watch-screenshot-build.log" >&2
    exit 1
  fi

  xcrun simctl install "$DEVICE_UDID" "$APP_PATH"

  for LANG in "${LOCALES[@]}"; do
    LANG="$(echo "$LANG" | sed 's/^ *//;s/ *$//')"
    LOCALE="$(locale_identifier "$LANG")"
    for SCREEN in "${SCREENS[@]}"; do
      SCREEN="$(echo "$SCREEN" | sed 's/^ *//;s/ *$//')"
      FILE="$DEVICE_DIR/${LANG}-${SCREEN}.png"

      echo "Capturing $DEVICE / $LANG ($LOCALE) / $SCREEN"
      xcrun simctl terminate "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
      xcrun simctl launch "$DEVICE_UDID" "$BUNDLE_ID" \
        -AppleLanguages "($LANG)" \
        -AppleLocale "$LOCALE" \
        -UITestScreenshotMode YES \
        -ScreenshotScreen "$SCREEN" >/dev/null
      sleep 3
      xcrun simctl io "$DEVICE_UDID" screenshot "$FILE" >/dev/null
    done
  done

done

echo "Watch screenshots saved to: $OUTPUT_DIR"
