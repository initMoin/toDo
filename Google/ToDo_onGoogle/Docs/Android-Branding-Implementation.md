# toDō Android branding implementation

This document makes the shared design record an active Android engineering
reference. The source of truth is
[`toDo-Brand-UI-UX-Principles.md`](../../Docs/toDo-Brand-UI-UX-Principles.md),
which applies to Apple, Android, Wear OS, Web, and future clients.

## Implemented contract

- Customer-facing product copy uses `toDō` and `toDōs`; Kotlin identifiers may
  remain `ToDo`.
- Material 3 roles map to the shared semantic palette rather than introducing
  Android-only brand colors.
- The classic theme uses the canonical secondary blue `#006CE7` in light mode
  and `#67A9FF` in dark mode. The previous Android cyan `#00D8E7` was removed
  from the app theme and launcher mark.
- Light and dark surfaces, elevated surfaces, primary text, completion green,
  urgency/destructive red, and action colors are defined in `Color.kt`.
- Compose typography exposes named roles in `ToDoTypography`: brand, view title,
  UI, display, long-form, and user entry, backed by the licensed Cal Sans,
  Cal Sans UI, Jura, Bebas Neue, and Aleo Android font resources.
- User-authored titles and notes use the user-entry/long-form roles. UI labels,
  navigation, and controls use the UI role.
- The Home brand context uses one unified `toDō` lockup: `toD` is rendered in
  Cal Sans and the official yellow `ō` mark is used as the final character.
  The Android launcher uses the approved toDō app icon.
- The Home create `+` is a Cal Sans glyph masked with the centered crop of the
  licensed `brandPlusReference.jpg` gradient, preserving the cross-platform
  artwork while keeping the action native and clickable on Android.
- The Home hierarchy follows the Apple reference while using Android-native
  surfaces: date/brand/create header, profile-and-settings action stack,
  primary “What matters now?” action card, horizontally scrollable Up Next
  filters, a toDō preview, and Momentum metric cards with a Stats destination.
- The adaptive shell preserves the shared hierarchy while translating it into
  Android conventions: a compact top-app-bar/system-Back flow on phone widths,
  a labeled navigation rail at 600dp and above, and a readable content width on
  tablets.
- Settings preserves the Apple section hierarchy while translating rows,
  switches, pills, system-settings handoffs, and phone/tablet detail navigation
  into Material 3 controls. Product copy remains centered on `toDō`; legacy
  maker-brand names are not used as the Settings title or primary identity.

## Token reference

| Semantic role | Light | Dark |
| --- | --- | --- |
| Canvas | `#EBEBEB` | `#161316` |
| Elevated surface | `#F7F6F2` | `#1A1D21` |
| Primary text | `#393939` | `#F5F2EA` |
| Primary brand | `#E9A700` | `#FFCC36` |
| Secondary/navigation | `#006CE7` | `#67A9FF` |
| Completion/positive | `#62C400` | `#8FE35B` |
| Destructive/urgent | `#D40000` | `#FF0A12` |

## Deliberate platform translation

Android uses Material 3 components and system Back behavior instead of
reproducing SwiftUI structure. The visual and behavioral contract remains the
same: creation is the primary action, completion is distinct from opening a
toDō, status is not conveyed by color alone, and tablets gain space without
changing the domain model or sync semantics.

## Asset implementation

The licensed font files are packaged under `app/src/main/res/font` and exposed
through the semantic roles in `ToDoTypography`. The official toDō mark and app
icon are packaged under `app/src/main/res/drawable-nodpi` and use stable
Android resource names rather than Apple asset-catalog paths. Unrelated legacy
brand-logotype assets are intentionally excluded from the Android app.

Theme variants beyond the current classic semantic mapping and a
platform-neutral token manifest remain follow-up work.

## Review gate for each UI slice

Before a slice is considered complete, verify orthography, semantic color use,
role-appropriate typography, 44dp touch targets, large-text reflow, TalkBack
labels, reduced motion, compact/tablet behavior, and parity with the Apple
counterpart. New Android deviations should be recorded here or in the shared
design document with their reason.
