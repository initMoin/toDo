# App Store Screenshot Capture Plan

This workflow captures repeatable iPhone and iPad simulator screenshots for ToDo, including localized launches.

## Locales

Current screenshot/localization focus:

- English: `en`
- Arabic: `ar`
- Spanish: `es`
- Hindi: `hi`
- Italian: `it`
- Japanese: `ja`
- Malay: `ms`
- Thai: `th`
- Urdu: `ur`
- Simplified Chinese: `zh-Hans`

Note: “Malaysian” maps to Malay for iOS localization, using language code `ms` and locale `ms_MY`.

## Before Capturing

Do:

- Use a clean simulator state when capturing App Store screenshots.
- Seed the app with intentional demo ToDos before the final capture pass.
- Keep demo ToDos short enough to fit on iPhone and Watch surfaces.
- Verify dark mode and light mode separately if the screenshots need both.
- Keep Xcode open if you want logs, but do not interact with the simulator while the script is capturing.

Do not:

- Use personal account data, real email addresses, private calendar entries, or real location names.
- Capture screenshots while sync is actively changing content.
- Touch the simulator during script execution.
- Use screenshots from an unstable build, a debug overlay, or a logged-in personal production account.

## Run The Script

From the project root:

```sh
cd /Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo
Scripts/capture_app_store_screenshots.sh
```

The script builds the app for iOS Simulator, boots the configured simulators, installs ToDo, launches once per locale, waits briefly, then captures a screenshot.

Default iPhone/iPad devices:

- `iPhone 17 Pro Max`
- `iPhone 11 Pro Max`
- `iPhone 17 Pro`
- `iPhone 17`
- `iPhone 8 Plus`
- `iPhone 8`
- `iPhone SE (1st generation)`
- `iPad Pro 13-inch (M5)`
- `iPad Pro 11-inch (M5)`
- `iPad Pro (12.9-inch) (6th generation)`
- `iPad Pro (10.5-inch)`
- `iPad Pro (9.7-inch)`

Default locales:

- `en,ar,es,hi,it,ja,ms,th,ur,zh-Hans`

Output is written to:

```sh
Build/Screenshots/<timestamp>/
```

## Custom Device Or Locale Pass

Use comma-separated values:

```sh
DEVICES="iPhone 17 Pro" LOCALES="en,ar,es,hi,it,ja,ms,th,ur,zh-Hans" Scripts/capture_app_store_screenshots.sh
```

```sh
DEVICES="iPad Pro 13-inch (M5)" LOCALES="en,ar,es,hi,it,ja,ms,th,ur,zh-Hans" Scripts/capture_app_store_screenshots.sh
```

Watch screenshots use the separate script:

```sh
WATCH_DEVICES="Apple Watch Ultra 3 (49mm)" LOCALES="en,ar,es,hi,it,ja,ms,th,ur,zh-Hans" Scripts/capture_watch_app_store_screenshots.sh
```

## If A Device Name Fails

List available simulator names:

```sh
xcrun simctl list devices available
```

Then rerun with an exact device name:

```sh
DEVICES="Exact Simulator Name" Scripts/capture_app_store_screenshots.sh
```

## Local Device Translation

iOS does not automatically translate an app’s interface using on-device translation. App UI still needs shipped localizations through string catalogs like `Localizable.xcstrings` and `InfoPlist.xcstrings`.

Apple’s on-device translation capabilities can be useful for user-generated content later, such as translating a ToDo title or note, but they should not be treated as a replacement for App Store-quality app localization.

Recommended path:

- Ship first-party localizations for core UI and permission copy.
- Use system/device translation only as an optional user-facing feature for user-generated content, if we add that product behavior later.
- Keep screenshots based on shipped strings, not automatic translation.
