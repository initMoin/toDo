# Step 07: Accessibility and Localization QA

## Objective

Verify the customer-facing app across all shipped languages and supported
accessibility settings. Source catalogs and successful builds prove coverage;
only real UI testing proves readability, order, meaning, and operability.

## Required Surface Matrix

Test at minimum:

- HomeView
- ToDosView
- ToDoView create, view, and edit
- Settings and every submenu
- Behavior
- Notifications and custom-sound help
- Account and My Profile
- Collab list, invitation, and User profile
- Membership and restoration
- Stats and Insights
- Archives, Trash, and Tags
- Guided onboarding
- Widgets
- Live Activities
- Watch Home, ToDos, ToDo, Stats, Settings, and Done list
- macOS main window, split layouts, Settings, Stats, and menu-bar popover

## Localization Languages

Test all ten shipped languages:

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

## Localization Procedure

For each language:

1. Change device language and region.
2. Force-quit and relaunch toDō.
3. Verify app UI text is localized except intentional brand marks and user-entered
   content.
4. Verify dates, times, counters, plural forms, and numbers follow locale rules.
5. Verify default tags are localized while user-created tags remain unchanged.
6. Create data containing long strings and mixed scripts.
7. Inspect narrow iPhone, iPad split layout, Watch, widgets, Live Activities, and
   Mac narrow window.
8. Test notification, Shortcut, Siri, widget, and Watch text.
9. Record unnatural, literal, clipped, untranslated, or incorrectly ordered text.

For Arabic and Urdu, verify right-to-left order without mirroring brand marks or
placing directional icons incorrectly.

## VoiceOver

1. Enable VoiceOver.
2. Navigate each required surface using swipes only.
3. Confirm every control has a concise role and accessible name.
4. Confirm custom icon buttons announce their action, not the SF Symbol filename.
5. Confirm status is conveyed without relying only on color.
6. Confirm reading order follows visual and task order.
7. Confirm decorative images are hidden.
8. Confirm editable fields announce label, value, and validation error.
9. Confirm modal/sheet focus moves inside on presentation and returns to the
   presenting control on dismissal.
10. Confirm completion, deletion, restoration, purchase, and sync results are
    announced.

## Voice Control

1. Enable Voice Control.
2. Say “Show names” and inspect visible control names.
3. Operate create, save, close, edit, complete, archive, delete, restore, filter,
   Settings, Stats, purchase, and profile controls by name.
4. Confirm duplicate names do not make the intended target ambiguous.
5. Confirm full button hit areas are interactive, not only icon glyphs.

## Larger Text and Dynamic Type

Test the largest accessibility text sizes:

- Text must wrap rather than clip.
- ToDo text containers must expand vertically.
- Buttons must retain readable labels and usable hit areas.
- Horizontal arrangements may adapt vertically when necessary.
- Content must remain scrollable and reachable above the keyboard.
- Watch layouts must retain critical actions.
- No customer-facing text may be truncated merely to preserve decoration.

## Reduce Motion

Enable Reduce Motion and test:

- Home to ToDos, Settings, and Stats transitions.
- Settings submenu transitions in both iPhone and iPad split layouts.
- Completion strike/fade/reordering effects.
- Archive, delete, restore, and toast presentation.
- Guided onboarding transitions.
- Stats Insights unlock celebration.
- Mac navigation, menu-bar completion, and split-panel changes.

Expected: motion-heavy sliding, zooming, parallax, or celebration behavior is
replaced by restrained opacity or immediate state changes while preserving clear
feedback. System transitions that the OS controls may remain system-defined.

## Differentiate Without Color Alone

Enable Differentiate Without Color and confirm non-color indicators appear across,
not only on HomeView:

- active, due-soon, overdue, Time-Sensitive, complete, archived, and deleted states;
- sync success/error and notification authorization;
- selected filters and segmented options;
- Collab role and invitation state;
- membership and entitlement state;
- destructive versus restorative actions.

Indicators may include icon, stroke, pattern, label, shape, or text. A red/green
color swap alone is insufficient.

## Contrast and Appearance

Test Light and Dark Mode with Increase Contrast enabled where available:

- Text and icons remain legible against brand yellow, blue, red, green, and glass.
- Light-mode brand-yellow controls use the approved foreground treatment.
- Dark-mode controls use the approved dark foreground treatment.
- Disabled controls are distinguishable but readable.
- Sheet backdrops prevent underlying text from visually bleeding into content.
- Overdue rows preserve Time-Sensitive badge contrast.

## Platform-Specific Checks

### Watch

- Controls meet practical tap targets.
- Digital Crown scrolling reaches all content.
- VoiceOver order is concise.
- Information density remains usable on small and Ultra sizes.

### Mac

- Full Keyboard Access reaches every command.
- Tab order is predictable.
- Space/Return activate focused buttons.
- Escape dismisses transient surfaces when expected.
- Menu commands and menu-bar controls have accessible labels.

## Pass Criteria

- [ ] All ten languages have no unintended English pockets.
- [ ] Arabic and Urdu layout correctly right-to-left.
- [ ] VoiceOver and Voice Control complete core workflows.
- [ ] Largest Dynamic Type remains usable.
- [ ] Reduce Motion affects all custom motion-heavy interactions.
- [ ] Differentiate Without Color applies throughout status surfaces.
- [ ] Light/Dark and contrast modes remain legible.
- [ ] Watch and Mac platform-specific accessibility passes.
- [ ] Every defect has device, language, setting, screenshot, and reproduction steps.

