#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="${1:-Build/Screenshots}"
DERIVED_DATA="${DERIVED_DATA:-Build/ScreenshotDerivedData}"
IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-dev.iamshift.toDo}"
SCREENSHOT_SLEEP="${SCREENSHOT_SLEEP:-5}"
INSTALL_SETTLE_SLEEP="${INSTALL_SETTLE_SLEEP:-15}"
APP_WARMUP_SLEEP="${APP_WARMUP_SLEEP:-12}"
LAUNCH_TIMEOUT="${LAUNCH_TIMEOUT:-25}"
LAUNCH_ATTEMPTS="${LAUNCH_ATTEMPTS:-3}"
SCREENSHOT_DEVICE_FILTER="${SCREENSHOT_DEVICE_FILTER:-}"
WATCH_SCREENSHOT_LABEL="Watch-Ultra-3-49mm"

FAILED_DEVICES=()
SKIPPED_DEVICES=()

mkdir -p "$OUT_DIR"

should_run_device() {
  local label="$1"

  [[ -z "$SCREENSHOT_DEVICE_FILTER" || "$label" =~ $SCREENSHOT_DEVICE_FILTER ]]
}

build_ios_app() {
  echo "Building iOS app for screenshots"
  xcodebuild build \
    -scheme "ToDo" \
    -configuration Debug \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO
}

build_watch_app() {
  echo "Building Watch app for screenshots"
  xcodebuild build \
    -scheme "ToDo Watch App" \
    -configuration Debug \
    -destination "generic/platform=watchOS Simulator" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO
}

launch_app() {
  local udid="$1"
  local bundle_id="$2"
  local screen="$3"
  local log_file="$4"
  local launch_pid
  local elapsed
  local status=0
  local attempt

  : > "$log_file"

  for attempt in $(seq 1 "$LAUNCH_ATTEMPTS"); do
    elapsed=0
    status=0
    echo "launch attempt ${attempt}/${LAUNCH_ATTEMPTS} for ${bundle_id} screen=${screen}" >> "$log_file"
    xcrun simctl launch --terminate-running-process "$udid" "$bundle_id" \
      -UITestScreenshotMode \
      -ScreenshotScreen "$screen" \
      -AppleLanguages "(en)" \
      -AppleLocale "en_US" \
      -UIPreferredContentSizeCategoryName "UICTContentSizeCategoryM" >>"$log_file" 2>&1 &
    launch_pid=$!

    while kill -0 "$launch_pid" >/dev/null 2>&1; do
      if (( elapsed >= LAUNCH_TIMEOUT )); then
        kill "$launch_pid" >/dev/null 2>&1 || true
        wait "$launch_pid" >/dev/null 2>&1 || true
        echo "warning: simctl launch timed out after ${LAUNCH_TIMEOUT}s for ${bundle_id} screen=${screen}" >> "$log_file"
        status=124
        break
      fi
      sleep 1
      elapsed=$((elapsed + 1))
    done

    if (( status == 0 )); then
      wait "$launch_pid" || status=$?
    fi

    if (( status == 0 )); then
      return 0
    fi

    echo "launch attempt ${attempt} failed with status ${status}" >> "$log_file"
    sleep 3
  done

  return 1
}

capture_screen() {
  local udid="$1"
  local bundle_id="$2"
  local screen="$3"
  local output="$4"
  local launch_log="${output%.png}.launch.log"

  if ! launch_app "$udid" "$bundle_id" "$screen" "$launch_log"; then
    return 1
  fi
  sleep "$SCREENSHOT_SLEEP"
  xcrun simctl io "$udid" screenshot "$output" >/dev/null
}

warm_up_app() {
  local udid="$1"
  local bundle_id="$2"
  local launch_log="$3"

  launch_app "$udid" "$bundle_id" "home" "$launch_log" || true
  sleep "$APP_WARMUP_SLEEP"
  xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
  sleep 2
}

record_skip() {
  local label="$1"
  local message="$2"
  local device_dir="$3"

  SKIPPED_DEVICES+=("$label")
  printf "%s\n" "$message" > "$device_dir/SKIPPED.txt"
  echo "Skipping ${label}: ${message}"
}

record_failure() {
  local label="$1"
  local message="$2"
  local device_dir="$3"

  FAILED_DEVICES+=("$label")
  printf "%s\n" "$message" > "$device_dir/FAILED.txt"
  echo "Failed ${label}: ${message}"
}

run_ios_device() {
  local label="$1"
  local device_type="$2"
  local safe_label="$label"
  local device_name="toDo Screenshots ${label}"
  local device_dir="$OUT_DIR/$safe_label"
  local udid

  if ! should_run_device "$label"; then
    return 0
  fi

  rm -rf "$device_dir"
  mkdir -p "$device_dir"

  echo "Creating iOS simulator: ${label}"
  if ! udid="$(xcrun simctl create "$device_name" "$device_type" 2>"$device_dir/create.log")"; then
    record_skip "$label" "$(cat "$device_dir/create.log")" "$device_dir"
    return 0
  fi

  if ! xcrun simctl boot "$udid" >"$device_dir/boot.log" 2>&1; then
    record_failure "$label" "$(cat "$device_dir/boot.log")" "$device_dir"
    xcrun simctl delete "$udid" >/dev/null 2>&1 || true
    return 0
  fi

  if ! xcrun simctl bootstatus "$udid" -b >"$device_dir/bootstatus.log" 2>&1; then
    record_failure "$label" "$(cat "$device_dir/bootstatus.log")" "$device_dir"
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl delete "$udid" >/dev/null 2>&1 || true
    return 0
  fi

  if ! xcrun simctl install "$udid" "$DERIVED_DATA/Build/Products/Debug-iphonesimulator/ToDo.app" >"$device_dir/install.log" 2>&1; then
    record_failure "$label" "$(cat "$device_dir/install.log")" "$device_dir"
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl delete "$udid" >/dev/null 2>&1 || true
    return 0
  fi
  sleep "$INSTALL_SETTLE_SLEEP"
  warm_up_app "$udid" "$IOS_BUNDLE_ID" "$device_dir/warmup.launch.log"

  if ! capture_screen "$udid" "$IOS_BUNDLE_ID" "home" "$device_dir/01-HomeView.png" ||
     ! capture_screen "$udid" "$IOS_BUNDLE_ID" "todos" "$device_dir/02-ToDosView.png" ||
     ! capture_screen "$udid" "$IOS_BUNDLE_ID" "create" "$device_dir/03-ToDoView-create.png" ||
     ! capture_screen "$udid" "$IOS_BUNDLE_ID" "detail" "$device_dir/04-ToDoView-view.png" ||
     ! capture_screen "$udid" "$IOS_BUNDLE_ID" "stats" "$device_dir/05-StatsView.png"; then
    record_failure "$label" "One or more screenshots failed. Re-run with SCREENSHOT_SLEEP=6 APP_WARMUP_SLEEP=16 if this simulator is slow." "$device_dir"
  fi

  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  xcrun simctl delete "$udid" >/dev/null 2>&1 || true
}

run_watch_device() {
  local label="$1"
  local device_type="$2"
  local safe_label="$label"
  local device_name="toDo Screenshots ${label}"
  local device_dir="$OUT_DIR/$safe_label"
  local watch_app="$DERIVED_DATA/Build/Products/Debug-watchsimulator/ToDo Watch.app"
  local bundle_id
  local udid

  if ! should_run_device "$label"; then
    return 0
  fi

  rm -rf "$device_dir"
  mkdir -p "$device_dir"

  bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$watch_app/Info.plist")"

  echo "Creating watchOS simulator: ${label}"
  if ! udid="$(xcrun simctl create "$device_name" "$device_type" 2>"$device_dir/create.log")"; then
    record_skip "$label" "$(cat "$device_dir/create.log")" "$device_dir"
    return 0
  fi

  if ! xcrun simctl boot "$udid" >"$device_dir/boot.log" 2>&1; then
    record_failure "$label" "$(cat "$device_dir/boot.log")" "$device_dir"
    xcrun simctl delete "$udid" >/dev/null 2>&1 || true
    return 0
  fi

  if ! xcrun simctl bootstatus "$udid" -b >"$device_dir/bootstatus.log" 2>&1; then
    record_failure "$label" "$(cat "$device_dir/bootstatus.log")" "$device_dir"
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl delete "$udid" >/dev/null 2>&1 || true
    return 0
  fi

  if ! xcrun simctl install "$udid" "$watch_app" >"$device_dir/install.log" 2>&1; then
    record_failure "$label" "$(cat "$device_dir/install.log")" "$device_dir"
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl delete "$udid" >/dev/null 2>&1 || true
    return 0
  fi
  sleep "$INSTALL_SETTLE_SLEEP"
  warm_up_app "$udid" "$bundle_id" "$device_dir/warmup.launch.log"

  if ! capture_screen "$udid" "$bundle_id" "home" "$device_dir/watch-01-HomeView.png" ||
     ! capture_screen "$udid" "$bundle_id" "todos" "$device_dir/watch-02-ToDosView.png" ||
     ! capture_screen "$udid" "$bundle_id" "create" "$device_dir/watch-03-ToDoView-create.png" ||
     ! capture_screen "$udid" "$bundle_id" "detail" "$device_dir/watch-04-ToDoView-view.png" ||
     ! capture_screen "$udid" "$bundle_id" "stats" "$device_dir/watch-05-StatsView.png"; then
    record_failure "$label" "One or more screenshots failed. Re-run with SCREENSHOT_SLEEP=6 APP_WARMUP_SLEEP=16 if this simulator is slow." "$device_dir"
  fi

  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  xcrun simctl delete "$udid" >/dev/null 2>&1 || true
}

build_ios_app

run_ios_device "iPhone-6.9-iPhone-17-Pro-Max" "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"
run_ios_device "iPhone-6.5-iPhone-11-Pro-Max" "com.apple.CoreSimulator.SimDeviceType.iPhone-11-Pro-Max"
run_ios_device "iPhone-6.3-iPhone-17-Pro" "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
run_ios_device "iPhone-6.1-iPhone-16" "com.apple.CoreSimulator.SimDeviceType.iPhone-16"
run_ios_device "iPhone-5.5-iPhone-8-Plus" "com.apple.CoreSimulator.SimDeviceType.iPhone-8-Plus"
run_ios_device "iPhone-4.7-iPhone-8" "com.apple.CoreSimulator.SimDeviceType.iPhone-8"

# Xcode 27 beta no longer lists a true 3.5-inch iPhone simulator. The closest
# available legacy compact simulator in this installation is iPhone SE 1st gen.
run_ios_device "iPhone-3.5-fallback-iPhone-SE-1st-gen" "com.apple.CoreSimulator.SimDeviceType.iPhone-SE"

run_ios_device "iPad-13-iPad-Pro-13-inch-M5" "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB"
run_ios_device "iPad-11-iPad-Pro-11-inch-M5" "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M5-12GB"
run_ios_device "iPad-12.9-iPad-Pro-12.9-6th-gen" "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-12-9-inch-6th-generation-8GB"
run_ios_device "iPad-10.5-iPad-Pro-10.5" "com.apple.CoreSimulator.SimDeviceType.iPad-Pro--10-5-inch-"
run_ios_device "iPad-9.7-iPad-Pro-9.7" "com.apple.CoreSimulator.SimDeviceType.iPad-Pro--9-7-inch-"

if should_run_device "$WATCH_SCREENSHOT_LABEL"; then
  build_watch_app
  run_watch_device "$WATCH_SCREENSHOT_LABEL" "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Ultra-3-49mm"
fi

echo "Screenshots exported under: $OUT_DIR"
if ((${#SKIPPED_DEVICES[@]})); then
  printf "Skipped unavailable devices: %s\n" "${SKIPPED_DEVICES[*]}"
fi
if ((${#FAILED_DEVICES[@]})); then
  printf "Devices with capture failures: %s\n" "${FAILED_DEVICES[*]}"
fi
