#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/toDo.xcodeproj"
SCHEME="ToDo"
CONFIGURATION="Debug"
BUNDLE_ID="dev.iamshift.toDo"
DERIVED_DATA="$ROOT_DIR/Build/ScreenshotDerivedData"
OUTPUT_DIR="$ROOT_DIR/Build/Screenshots/$(date +%Y%m%d-%H%M%S)"
IOS_RUNTIME="${IOS_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-5}"

# Override from the command line when needed:
#   DEVICES="iPhone 17 Pro Max,iPhone 17" LOCALES="en,ar,es,hi,it,ja,ms,th,ur,zh-Hans" SCREENS="todos,settings,todo" Scripts/capture_app_store_screenshots.sh
# Note: this Xcode install does not include a 3.5-inch iPhone simulator type.
DEVICES_CSV="${DEVICES:-iPhone 17 Pro Max,iPhone 11 Pro Max,iPhone 17 Pro,iPhone 17,iPhone 8 Plus,iPhone 8,iPhone SE (1st generation),iPad Pro 13-inch (M5),iPad Pro 11-inch (M5),iPad Pro (12.9-inch) (6th generation),iPad Pro (10.5-inch),iPad Pro (9.7-inch)}"
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

device_type_identifier() {
  case "$1" in
    "iPhone 17 Pro Max") echo "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max" ;;
    "iPhone 11 Pro Max") echo "com.apple.CoreSimulator.SimDeviceType.iPhone-11-Pro-Max" ;;
    "iPhone XS Max"|"iPhone Xs Max") echo "com.apple.CoreSimulator.SimDeviceType.iPhone-XS-Max" ;;
    "iPhone 17 Pro") echo "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro" ;;
    "iPhone 17") echo "com.apple.CoreSimulator.SimDeviceType.iPhone-17" ;;
    "iPhone 8 Plus") echo "com.apple.CoreSimulator.SimDeviceType.iPhone-8-Plus" ;;
    "iPhone 8") echo "com.apple.CoreSimulator.SimDeviceType.iPhone-8" ;;
    "iPhone SE (1st generation)") echo "com.apple.CoreSimulator.SimDeviceType.iPhone-SE" ;;
    "iPad Pro 13-inch (M5)") echo "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB" ;;
    "iPad Pro 11-inch (M5)") echo "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M5-12GB" ;;
    "iPad Pro (12.9-inch) (6th generation)") echo "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-12-9-inch-6th-generation-8GB" ;;
    "iPad Pro (10.5-inch)") echo "com.apple.CoreSimulator.SimDeviceType.iPad-Pro--10-5-inch-" ;;
    "iPad Pro (9.7-inch)") echo "com.apple.CoreSimulator.SimDeviceType.iPad-Pro--9-7-inch-" ;;
    *) return 1 ;;
  esac
}

find_device_udid() {
  local name="$1"
  xcrun simctl list devices available | awk -v name="$name" 'index($0, name) > 0 && match($0, /\([A-F0-9-]+\)/) { udid = substr($0, RSTART + 1, RLENGTH - 2); print udid; exit }'
}

ensure_device() {
  local name="$1"
  local udid
  udid="$(find_device_udid "$name")"
  if [[ -n "$udid" ]]; then
    echo "$udid"
    return 0
  fi

  local device_type
  if ! device_type="$(device_type_identifier "$name")"; then
    echo "Unsupported or unavailable screenshot simulator: $name" >&2
    return 1
  fi

  xcrun simctl create "$name" "$device_type" "$IOS_RUNTIME"
}

IFS=',' read -r -a DEVICES <<< "$DEVICES_CSV"
IFS=',' read -r -a LOCALES <<< "$LOCALES_CSV"
IFS=',' read -r -a SCREENS <<< "$SCREENS_CSV"

mkdir -p "$OUTPUT_DIR"

echo "Output: $OUTPUT_DIR"
for DEVICE in "${DEVICES[@]}"; do
  DEVICE="$(echo "$DEVICE" | sed 's/^ *//;s/ *$//')"
  DEVICE_SAFE="$(sanitize "$DEVICE")"
  DEVICE_DIR="$OUTPUT_DIR/$DEVICE_SAFE"
  mkdir -p "$DEVICE_DIR"

  DEVICE_UDID="$(ensure_device "$DEVICE")"

  echo "Booting simulator: $DEVICE ($DEVICE_UDID)"
  xcrun simctl boot "$DEVICE_UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$DEVICE_UDID" -b >/dev/null

  echo "Building $SCHEME for $DEVICE..."
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk iphonesimulator \
    -derivedDataPath "$DERIVED_DATA" \
    -destination "platform=iOS Simulator,id=$DEVICE_UDID" \
    build >/tmp/todo-screenshot-build.log

  APP_PATH="$(find "$DERIVED_DATA/Build/Products" -path "*${CONFIGURATION}-iphonesimulator/ToDo.app" -type d | head -n 1)"
  if [[ -z "$APP_PATH" ]]; then
    echo "Could not find built ToDo.app under $DERIVED_DATA/Build/Products" >&2
    echo "Build log: /tmp/todo-screenshot-build.log" >&2
    exit 1
  fi

  # Screenshot capture only needs the iOS app. Stripping the generated Watch
  # payload avoids simulator install failures caused by Watch-only metadata.
  if [[ -d "$APP_PATH/Watch" ]]; then
    rm -rf "$APP_PATH/Watch"
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
      sleep 4
      xcrun simctl io "$DEVICE_UDID" screenshot "$FILE" >/dev/null
    done
  done

done

echo "Screenshots saved to: $OUTPUT_DIR"
