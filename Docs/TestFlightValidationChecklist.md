# TestFlight Validation Checklist

Use this checklist for the small family build and the wider multilingual TestFlight group. Code validation can prove strings exist and builds compile, but it cannot prove tone, grammar, or visual fit in every language.

## Localization QA

Ask testers to switch their device language and region, then verify:

- All app UI text is localized except the app title and the branded footer block.
- Dates, times, counters, and badge numbers use the expected local numbering style.
- Right-to-left layout behaves correctly for Arabic and Urdu without reversing brand marks.
- Default tags are localized, while user-created tags remain exactly as the user entered them.
- App Intents, Shortcuts, widgets, notifications, and Watch views use natural wording.
- Text is not clipped in Settings, ToDosView, ToDoView, widgets, Live Activities, and Watch views.

Languages currently shipped:

- English
- Arabic
- Spanish
- Hindi
- Italian
- Japanese
- Malay
- Thai
- Urdu
- Simplified Chinese

Feedback prompt for testers:

```text
If you use toDō in a non-English language, please report any wording that feels unnatural, too literal, clipped, untranslated, or incorrectly ordered. Include your device language, region, screenshot, and the screen where it appears.
```

## Functional QA

Validate these flows on iPhone, iPad, and Apple Watch where available:

- Create, edit, complete, archive, restore, and delete a ToDo.
- Add a due date, reminder, note, tag, NanoDo, and location reminder.
- Use widgets to view and complete ToDos.
- Start and complete a time-sensitive ToDo with Live Activity or Smart Stack behavior.
- Confirm notification delivery, notification actions, and app icon badge behavior.
- Run onboarding from a fresh install and from the Settings test trigger in Debug builds.
- Test sync modes: This Device Only, iCloud, and ToDo Sync.
- Confirm Watch actions mutate the real ToDo and sync back to iPhone.

## Stability QA

Report immediately:

- Crashes, freezes, or force quits.
- Memory warnings or process termination messages.
- Watch app hangs where scroll/tap stops responding.
- Stale widget data after completing a ToDo.
- Live Activity content disappearing or showing the wrong ToDo.
- Notifications that show no ToDo text or wrong due-time information.

Useful report details:

- Device model.
- OS version.
- App version and build.
- Language and region.
- Light or Dark Mode.
- Sync mode.
- Exact steps before the issue.
- Screenshot or screen recording.
