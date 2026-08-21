# toDō Brand, UI, and UX Principles

**Application name:** **toDō**. This is the exact customer-facing name and casing. Use `toDō` in product UI, documentation, notifications, screenshots, and marketing. `ToDo` is reserved for existing code identifiers, package names, database names, and other technical constraints.

**Status:** Product and design system guidance

**Applies to:** iPhone, iPad, Mac, Apple Watch, Android phone/tablet, Wear OS, Web, widgets, notifications, Live Activities, and future clients

**Reference implementation:** Current Apple targets at the repository root.

**Purpose:** Preserve recognition and behavioral familiarity as toDō moves across Apple, Android, and Web while allowing each platform to remain native.

---

## 1. Executive standard

The product standard is:

> **Familiar to a toDō user. Native to the platform.**

Familiarity does not mean copying SwiftUI, Apple-only controls, or a single layout at every size. It means that a person who understands toDō on one device can predict:

- what a task means;
- where the next useful action is;
- how completion, overdue state, reminders, tags, NanoDos, notes, and recurrence behave;
- which colors and icons communicate urgency or progress;
- what will sync to another device;
- how to recover from an error or interrupted workflow;
- how to return to the prior place in the product.

Each platform may use its own navigation, typography fallback, menus, gestures, sheets, dialogs, windowing, and system surfaces. The domain language, semantic status, content hierarchy, action priority, and emotional tone must remain shared.

### Non-negotiable principles

1. **Home-first orientation.** The product begins with what matters now, not an empty settings or database screen.
2. **Reduce cognitive pressure.** Show the next useful choice before exposing every possible option.
3. **Capture first, organize second.** A user can quickly create a toDō, then refine due dates, reminders, tags, notes, NanoDos, recurrence, or location.
4. **User-authored content is primary.** Titles, notes, tags, and NanoDos receive generous space, wrapping, and readable type.
5. **Status is semantic.** Color, icon, label, and behavior express the same state on every client.
6. **Platform-native expression.** Translate platform-specific patterns instead of simulating them everywhere.
7. **Accessible by default.** Color is never the only status signal; motion, text scale, contrast, keyboard, screen reader, and RTL behavior are part of the design.
8. **No silent data loss.** Completion, archive, trash, restore, permanent deletion, sync conflicts, and account switching are explicit and recoverable.
9. **Calm but not bland.** The neutral canvas creates focus; yellow, blue, green, and red provide decisive action and state cues.
10. **One product, many renderers.** Apple, Android, and Web are different presentations of the same product concepts and synchronized records.

---

## 2. Source-of-truth hierarchy

When design decisions conflict, use this order:

1. Approved product decisions from the current Codex/ChatGPT work and decision records.
2. The current Apple build and its semantic theme system.
3. Shared domain and sync contracts: toDō, NanoDo, Tag, lifecycle, recurrence, reminder intent, account, and sync identity.
4. Platform human-interface guidance for the client being implemented.
5. Existing screenshots and visual references.
6. Local implementation details that have not been promoted into a product decision.

The current Apple build is the reference for the product’s full behavior and visual vocabulary. Existing Android and Web implementations are valuable translation starting points, but current token drift must not become a second brand system.

The written source material audited for this document includes:

- `Docs/Typography-Adaptive-QA.md`
- `Docs/FeatureParity-v3.1.md`
- `Docs/v3.1-FeatureList.md`
- `Docs/AccountArchitectureAndMigration.md`
- `Docs/WebLocalDevelopment.md`
- `Docs/WebProductionSetup.md`
- `Web/docs/WebFoundationDecisions.md`
- `Google/ToDo_onGoogle/Docs/Android-Watch-Plan.md`
- `Google/ToDo_onGoogle/Docs/SyncProviderSetup.md`

The repository root is the shared product monorepo. This document is stored
under `Docs/` so the same brand contract can guide every client without
creating platform-specific copies.

---

## 3. Brand identity

### 3.1 Product name and orthography

The customer-facing product name is **toDō**.

- Lowercase `to`.
- Uppercase `D`.
- Final `ō` uses a macron and is a distinct character.
- Plural customer-facing form: **toDōs**.
- Child task form: **NanoDo**; plural: **NanoDos**.
- Code identifiers may continue to use `ToDo` where platform or language conventions require it, but customer-facing text should use `toDō`.
- Do not silently replace the brand with `todo`, `ToDo`, `To Do`, or `toDo` in visible UI, marketing, app chrome, screenshots, notifications, or legal/product copy.

### 3.2 Brand character

toDō should feel:

- focused rather than frantic;
- warm rather than overly cheerful;
- direct rather than corporate;
- expressive rather than decorative;
- confident rather than judgmental;
- useful rather than feature-demonstrative;
- private and trustworthy rather than surveillant.

The product can celebrate progress, especially in Stats and completion moments, but it must not shame the user for overdue or stale work. Pressure signals should help a person decide what deserves attention next.

### 3.3 Voice and copy

Use short, plain-language, action-oriented copy.

Good examples:

- “What matters now?”
- “New toDō”
- “See all toDōs”
- “Due soon”
- “Time-sensitive”
- “Recent”
- “Select a toDō”
- “Your toDō”
- “Continue offline”
- “Saved data unavailable”

Avoid:

- unnecessary taglines or subtitles in navigation headers;
- guilt-oriented wording such as “You failed to finish”;
- generic productivity clichés;
- ambiguous destructive labels such as “Do it” or “Remove” without context;
- unexplained technical language such as “tombstone,” “provider,” or “entitlement” in ordinary user flows.

Use sentence case for ordinary copy. Display typography may visually uppercase a section label such as `UP NEXT` or `MOMENTUM`, but the underlying localized string must remain localizable and must not depend on English capitalization.

### 3.4 Brand hierarchy

The brand is recognized through a combination of:

1. `toDō` wordmark and macron.
2. Yellow primary action.
3. Blue navigation/secondary action.
4. Green completion/success.
5. Red urgency/destructive action.
6. Neutral light/dark canvas with rounded elevated surfaces.
7. Cal Sans/Jura/Bebas Neue/Aleo semantic type hierarchy.
8. A home-first information architecture centered on “What matters now?”

No single color, font, icon, or image is sufficient by itself. A platform may need a different font fallback or system icon set while preserving the complete combination.

---

## 4. Color system

### 4.1 Canonical semantic tokens

The following values are the current Apple classic theme expressed as approximate sRGB hex values. The asset catalogs remain the exact implementation source. Android and Web should consume these semantic roles through their own token systems rather than hard-coding component-specific colors.

| Token | Light value | Dark value | Meaning |
| --- | --- | --- | --- |
| `surface` | `#EBEBEB` | `#161316` | Main app canvas |
| `surface-elevated` | `#F7F6F2` | `#1A1D21` | Cards, panels, sheets, detail surfaces |
| `surface-muted` | Charcoal at low opacity | Near-white at low opacity | Quiet fills, chips, inactive controls |
| `text-primary` | `#393939` | `#F5F2EA` | Main readable content |
| `text-secondary` | Charcoal at about 62% | Near-white at about 68% | Metadata, helper text, secondary labels |
| `brand-main` | `#E9A700` | `#FFCC36` | Primary create/action accent |
| `brand-secondary` | `#006CE7` | `#67A9FF` | Navigation, links, focus, information |
| `brand-tertiary` | `#62C400` | `#8FE35B` | Completion, success, positive progress |
| `destructive` | `#D40000` | `#FF0A12` | Overdue, urgent, delete, irreversible action |
| `action-primary` | `#393939` | `#EEEBE2` | Neutral/high-contrast action surface |
| `on-action` | `#EBEBEB` | `#111316` | Foreground on filled action surfaces |
| `border` | Charcoal at about 22% | Near-white at about 18% | Boundaries, focus alternatives, dividers |
| `shadow` | Charcoal at about 18% | Black at about 55% | Elevation only, never status |

The Apple source assets are:

- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/appBrandMain.colorset/Contents.json`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/appBrandSecondary.colorset/Contents.json`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/appBrandTertiary.colorset/Contents.json`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/appBrandDestructive.colorset/Contents.json`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/appActionPrimary.colorset/Contents.json`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/appOnAction.colorset/Contents.json`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/appSurface.colorset/Contents.json`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/appSurfaceElevated.colorset/Contents.json`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/appSurfaceMuted.colorset/Contents.json`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/appTextPrimary.colorset/Contents.json`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/appTextSecondary.colorset/Contents.json`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/appBorder.colorset/Contents.json`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/appShadow.colorset/Contents.json`

### 4.2 Theme variants

The Apple build supports `classic`, `coastal`, `ember`, `orchard`, `midnight`, and `shift` themes. Theme selection changes accents, not product semantics.

The `shift` theme is a deliberate brand variant built around:

- deep red: approximately `#B50000`;
- near-black ink: approximately `#22181C` in light mode;
- electric lime: approximately `#C6F91F`;
- near-white action foreground: approximately `#FCFCFC`.

Every theme must preserve the meaning of the semantic roles. For example, `brand-tertiary` remains positive completion even if its hue changes, and `destructive` remains reserved for urgency and irreversible actions.

Android and Web should not expose a different uncontrolled list of themes. If themes are implemented, the theme identifiers, role meanings, light/dark behavior, and contrast checks must be shared with Apple.

### 4.3 Contrast and foreground rules

- Never use color alone to communicate done, overdue, time-sensitive, archived, or trashed state.
- Pair every colored state with an icon, label, border, shape, or behavior.
- Filled blue, red, green, and dark action controls use the `on-action` role.
- Yellow filled controls use the highest-contrast foreground for the current color scheme; the current Apple design uses a light foreground in light mode and dark foreground in dark mode.
- For light mode, `Done` and `Trash` controls use light text/icons on saturated filled action surfaces.
- For dark mode, the same controls use dark text/icons when that is the accessible contrast choice.
- If a platform’s contrast engine selects a different foreground, preserve semantic contrast rather than forcing a literal color.
- Focus indicators must remain visible against both the surface and the control fill.

### 4.4 State color rules

| State | Base treatment | Required non-color signal |
| --- | --- | --- |
| Active | Neutral elevated row/card | Open circle, normal label |
| Due soon | Yellow accent or due metadata | Calendar/clock icon and due label |
| Time-sensitive | Red accent chip or flame/clock icon | “Time-sensitive” label |
| Overdue | Red row background or red border | “Overdue”/“Late” label and warning icon |
| Overdue + time-sensitive | Red overdue row; time-sensitive chip inverts to light background with red foreground | Text, inverted chip, clock/flame icon |
| Done | Green accent, checkmark, or completion treatment | “Done” state and checked control |
| Archived | Muted surface and archive icon | “Archived” label/action |
| Trashed | Destructive context and trash icon | Restore/permanent-delete affordance |

An overdue item must not be mistaken for a normal due-soon item. “Due soon” excludes overdue records and is limited to records due in the product’s upcoming horizon. “Time-sensitive” shows only records with time-sensitive reminder intent. “Recent” is sorted newest-created first within the intended recent window.

### 4.5 UI color scheme and interaction states

Use semantic state tokens rather than choosing a new literal color for each component. The same roles must exist in Apple asset catalogs, Android Compose/Material tokens, and Web CSS variables.

#### Base surfaces

| UI element | Default role | Light behavior | Dark behavior |
| --- | --- | --- | --- |
| App/window background | `surface` | `#EBEBEB` | `#161316` |
| Elevated card/panel/sheet | `surface-elevated` | `#F7F6F2` | `#1A1D21` |
| Quiet/inactive fill | `surface-muted` | Low-opacity charcoal over the surface | Low-opacity near-white over the surface |
| Input background | `surface-elevated` | Warm near-white field | Dark elevated field |
| Divider/border | `border` | About 22% charcoal | About 18% near-white |
| Modal scrim | `overlay` | Black at approximately 8–20% | Black at approximately 20–40% |
| Elevation shadow | `shadow` | Soft charcoal shadow | Soft black shadow |

Cards, inputs, chips, and buttons should be distinguishable by hierarchy and contrast, not by adding a new hue to every surface. Use a semantic accent tint at low opacity only when it reinforces the meaning of the component.

#### Text and icon colors

| Content | Default role | Light behavior | Dark behavior |
| --- | --- | --- | --- |
| Primary text | `text-primary` | `#393939` | `#F5F2EA` |
| Secondary text/metadata | `text-secondary` | Charcoal at about 62% | Near-white at about 68% |
| Placeholder text | `text-placeholder` | `text-secondary` at about 72% | `text-secondary` at about 72% |
| Disabled text/icon | `text-disabled` | `text-secondary` at about 52% | `text-secondary` at about 52% |
| Link text | `link` | `brand-secondary` | Dark-mode `brand-secondary` |
| Success text/icon | `success` | `brand-tertiary` | Dark-mode `brand-tertiary` |
| Warning/overdue text/icon | `destructive` | `#D40000` | `#FF0A12` |
| Text/icon on filled actions | `on-action` | `#EBEBEB` | `#111316` |
| System glyph on quiet controls | `icon-accent` | Theme `iconAccent` role | Theme `iconAccent` role |

Text color must follow the surface it is placed on. Do not place `text-secondary` on a low-contrast tinted fill if the result becomes unreadable. Icons that communicate action or state must use the same foreground role as the accompanying label.

#### Links

| Link state | Color treatment | Additional treatment |
| --- | --- | --- |
| Default | `link` / `brand-secondary` | Underline on Web and long-form content; platform-native link styling elsewhere |
| Hover | `link` remains brand-secondary | Optional underline or subtle surface tint; never rely on hover alone |
| Focused | `link` | Visible `focus-ring` around the link/control |
| Pressed/activated | `link-pressed` | Slightly stronger contrast or 8–12% secondary tint; no layout jump |
| Visited | Same brand-secondary family | Do not introduce browser purple as the product default |
| Disabled | `text-disabled` | Remove pointer action and communicate why when necessary |

Web links must remain recognizable to keyboard and screen-reader users. On touch platforms, replace hover with pressed/focus feedback; do not invent a hover-only action.

#### Button states

The state names below are the cross-platform contract. A platform may express them with native elevation, ripple, material, glass, hover, or haptic behavior, but the semantic color relationship must remain stable.

| Button role | Default | Hover/pointer | Pressed/tapped | Focused | Disabled |
| --- | --- | --- | --- | --- | --- |
| Primary create (`New toDō`) | `brand-main` + `on-action` | Same hue, approximately 8% stronger contrast | Same hue, approximately 12–18% stronger/darker treatment; optional 0.95–0.98 scale | Default fill + `focus-ring` | `surface-muted` + `text-disabled`; retain disabled shape |
| Secondary/navigation (`See all toDōs`) | `brand-secondary` + `on-action` | Same hue, approximately 8% stronger contrast | Same hue, approximately 12–18% stronger/darker treatment; optional 0.95–0.98 scale | Default fill + `focus-ring` | `surface-muted` + `text-disabled` |
| Success/proceed (`Done`, `Stats`) | `brand-tertiary` + accessible `on-action` | Same hue, slightly stronger contrast | Success hue at about 74–85% effective opacity or darker success tone | Default fill + `focus-ring` | `surface-muted` + `text-disabled` |
| Neutral | `surface-muted` + `text-primary` | `surface-elevated`/muted with secondary border | `surface-muted` with `action-secondary` or 8–14% secondary tint | Default fill + `focus-ring` | `surface-muted` at about 45% + `text-disabled` |
| Destructive (`Trash`, permanent delete) | `destructive` + `on-action` | Stronger destructive contrast | Darker/stronger destructive treatment; confirmation remains required for irreversible deletion | Default fill + destructive/secondary focus ring with sufficient contrast | `surface-muted` + `text-disabled`; never hide the destructive meaning by using success green |
| Toggle/segmented selected | `brand-secondary` + `on-action` | Same selected treatment | Secondary fill with a pressed scale/ripple | Secondary fill + focus ring | Muted fill + disabled text |
| Toggle/segmented inactive | `icon-accent` or `surface-muted` + `text-primary` | Secondary border or low-opacity secondary tint | Muted fill with low-opacity secondary tint | Muted fill + focus ring | Muted fill at about 40–50% + disabled text |
| Icon-only action | Theme `icon-accent`/semantic fill + `on-action` | Optional stronger tint on pointer platforms | 0.93–0.96 scale and pressed tint; never remove the icon | Visible circular/rounded focus ring | Icon fill at about 28–30% + `text-disabled` |

The current Apple implementation uses the following concrete patterns that should be preserved conceptually:

- `New toDō`: yellow `brand-main` fill, `on-action` label/icon, Bebas Neue button label.
- `See all toDōs`: blue `brand-secondary` fill, `on-action` label/icon.
- `Stats`: green `brand-tertiary` fill, accessible action foreground.
- Neutral semantic text button: `surface-muted` fill with `text-primary`.
- Proceed semantic text button: `brand-tertiary` fill with an action foreground.
- Cancel/destructive semantic text button: `destructive` fill with an action foreground.
- Tapped circular/icon actions: visible scale reduction around 0.94–0.95; Reduce Motion removes the animated scale while retaining a direct pressed-state color/opacity change.

The current Apple `AppActionIntent` mapping also provides a useful pressed-state reference: neutral and proceed semantic text buttons use the secondary action color while pressed, while cancel remains destructive. If this color change is retained on another platform, it must be paired with a clear pressed animation/ripple and must not make the action’s meaning ambiguous. For circular action buttons, the current Apple implementation primarily communicates the tap through scale rather than a hue change; platform clients may add a low-opacity pressed tint only when it improves feedback without causing a flash of unrelated color.

Do not use opacity as the only disabled signal when the control remains important. Combine muted color, disabled interaction, and a clear accessibility state. Do not make a disabled primary button look like a destructive or successful action.

#### Inputs, selection, and validation

| State | Background | Text | Border/focus |
| --- | --- | --- | --- |
| Empty/default input | `surface-elevated` | `text-placeholder` placeholder | `border` |
| Filled input | `surface-elevated` | `text-primary` | `border` |
| Focused input | `surface-elevated` | `text-primary` | `brand-secondary` border plus visible `focus-ring` |
| Selected text/caret | `surface-elevated` | `text-primary` | Platform selection highlight derived from `brand-secondary` |
| Invalid input | `surface-elevated` | `text-primary` | `destructive` border plus adjacent error text/icon |
| Disabled input | `surface-muted` | `text-disabled` | `border` at reduced contrast; no focus action |
| Saved/successful input | `surface-elevated` | `text-primary` | Brief `brand-tertiary` confirmation, then return to normal |

#### Rows, chips, and status surfaces

| Component state | Background | Foreground/border |
| --- | --- | --- |
| Normal toDō row/card | `surface-elevated` | `text-primary`, metadata in `text-secondary` |
| Pointer hover | `surface-elevated` with low-opacity secondary tint | `brand-secondary` border or arrow |
| Pressed/opening | `surface-muted` or low-opacity secondary tint | `text-primary` |
| Selected row | Low-opacity `brand-secondary` tint | `brand-secondary` border/focus ring |
| Completed row | Muted/elevated surface with completion treatment | `brand-tertiary` checkmark; text may strike through |
| Inactive filter/chip | `surface-muted` | `text-secondary` or `text-primary` |
| Selected filter/chip | `brand-main` or product-selected accent | `on-action` |
| Due metadata | Low-opacity `brand-main` tint | `text-primary`/brand-main icon |
| Time-sensitive chip | Low-opacity `destructive` tint | `destructive` text/icon |
| Overdue row | Destructive fill or strong destructive border | `on-action` plus explicit “Overdue”/“Late” label |
| Overdue + time-sensitive chip | Light/near-white fill on the red row | `destructive` text and clock/flame icon |
| Sync conflict | Low-opacity `brand-secondary` tint | `brand-secondary` icon and explicit review label |

The same semantic color scheme applies to widgets, notifications, Live Activities, Watch cards, Android surfaces, and Web cards, subject to each system surface’s contrast and material rules.

#### Focus ring contract

Define a shared `focus-ring` role using `brand-secondary` or the platform’s accessible focus color. It must be:

- visible in both light and dark modes;
- at least 2px on Web/desktop-equivalent surfaces or the platform’s accessible equivalent;
- offset from the control boundary when possible;
- present for keyboard, switch, Voice Control, and screen-reader navigation;
- not represented only by a color change inside the control.

Touch-only platforms may use a pressed state instead of a persistent focus ring, but external keyboards, Switch Control, Voice Control, and accessibility navigation must still receive a visible/announced focus state.

---

## 5. Typography system

### 5.1 Semantic roles

| Role | Typeface | Use | Do not use for |
| --- | --- | --- | --- |
| Brand | Cal Sans | `toDō` wordmark and brand marks | Body copy, forms, metadata |
| View title | Cal Sans UI | Large platform view headers when supported | User-authored content |
| Primary UI | Jura | Navigation, titles, labels, controls, metadata, badges | Long notes when a reading face is more appropriate |
| Display | Bebas Neue | Section labels, large numbers, intentionally prominent button moments | Paragraphs, form help, user text |
| Long-form | Aleo Italic | Sustained notes or editorial/insight copy where an italic reading treatment is intentional | Small utility labels |
| User entry | Aleo Medium | User-authored toDō titles, notes, tags, NanoDos | Navigation and system labels |

### 5.2 Typeface weights and where they are used

The weight is part of the design role. Do not select a typeface and then use the platform’s default weight everywhere. Use the following nominal weights across Apple, Android, and Web:

| Semantic role | Typeface | Weight | Use it for | Avoid it for |
| --- | --- | ---: | --- | --- |
| Brand wordmark | Cal Sans | Regular / 400 | `toDō` wordmark and brand lockups | Body copy, buttons, metadata |
| Large view title | Cal Sans UI | Bold / 700 | Top-level view headers such as `Stats`, Settings section titles, major `Your toDō`/`New toDō` headers | User-authored titles, paragraphs |
| UI display/section label | Bebas Neue | Regular / 400 face | `UP NEXT`, `MOMENTUM`, `DETAILS`, section labels | Body copy, long labels, small error text |
| Button label | Bebas Neue | Regular / 400 face | `New toDō`, `See all toDōs`, prominent compact actions | Explanatory button help, long sentences |
| Stat number | Bebas Neue | Regular / 400 face | Counts, percentages, prominent metric values | Dense paragraphs or metadata |
| UI page/title emphasis | Jura | Bold / 700 | Product UI titles and headings that are not display-label moments | User-authored content |
| UI headline | Jura | Semibold / 600 | ToDō detail headings, card headings, strong action labels, emphasized UI copy | Long notes, decorative display moments |
| UI body | Jura | Regular / 400 | Explanatory copy, helper text, ordinary labels, metadata when quiet | Primary user-authored task content |
| UI accent/subtitle | Jura | Medium / 500 | Filter labels, selected/informational metadata, short subtitles, accent labels | Large headings or paragraphs |
| Badge/status label | Jura | Bold / 700 | `Overdue`, `Done`, `Time-sensitive`, compact count/status badges | Long sentences |
| User-entered task text | Aleo | Medium / 500 | ToDō titles, NanoDo titles, tags, user-authored short text | Navigation, system labels |
| User-authored long form | Aleo Italic | Regular / 400 italic | Notes, sustained insight copy, long-form reading moments | Tiny controls, badges |
| Emphasized user-authored text | Aleo | Semibold / 600 only when supported | Occasional emphasis inside a longer note or insight | Default title weight; do not make every task bold |
| System/icon glyph | Platform system icon font | Bold / 700 or Black / 900 as needed | SF Symbols, Material Symbols, Web SVG stroke/fill weight | Customer-facing prose |
| Technical/code value | Platform monospace | Regular / 400 | Developer-facing release/version/debug values only | Customer-facing product copy |

#### Weight implementation rules

- Cal Sans Regular and Bebas Neue are supplied as regular faces. Do not synthesize a fake bold version for the wordmark or display labels.
- Cal Sans UI view titles use Bold/700, matching the Apple implementation’s `.weight(.bold)` role.
- Jura uses four everyday weights: Regular/400, Medium/500, Semibold/600, and Bold/700. This is the normal toDō UI scale.
- Jura Heavy/800 is not a default product role. It may remain in existing compact Mac identity/status modules where the current Apple build already uses it, but new screens should use Bold/700 unless a platform-specific readability test proves Heavy is needed.
- Aleo uses Regular/400 Italic for long-form content and Medium/500 for user entry. Semibold/600 is reserved for limited emphasis, not the default task title.
- Bebas Neue’s visual authority comes from its condensed design, not a bold weight. Keep it at the supplied regular face.
- System symbols may use Bold/700 or Black/900 independently of text weights because glyph legibility and optical stroke are different concerns.
- Weight must not replace size hierarchy. If a title is too weak, first correct its semantic size/face/contrast before increasing weight.
- Custom font weight mapping must be validated after loading on every platform. If a font lacks a requested weight, use the nearest supported weight within the same role; do not replace the role with an unrelated face.

#### Component weight matrix

| Component | Typeface/weight |
| --- | --- |
| App wordmark | Cal Sans 400 |
| View header title | Cal Sans UI 700 |
| Main Home question | Jura 600 or 700, depending on size and available width |
| Section heading | Bebas Neue 400 |
| Primary/secondary button | Bebas Neue 400 |
| ToDō row title | Aleo 500 |
| ToDō row metadata | Jura 400; Jura 500 when the metadata is actionable/selected |
| ToDō detail title | Aleo 500; use Jura 600 only for system-generated headings |
| Detail card label | Bebas Neue 400 for display labels or Jura 700 for compact labels; choose one treatment per surface |
| Detail card value | Jura 400 for system metadata; Aleo 500 for user-authored value |
| NanoDo text | Aleo 500 |
| Notes | Aleo 400 italic for long-form presentation; Aleo 500 for editable note entry if upright text is more legible |
| Tag text | Jura 500 or Aleo 500 when the tag is user-authored and editable |
| Stats number | Bebas Neue 400 |
| Stats metric title | Jura 500 or 600; use the same choice throughout the Stats surface |
| Status badge | Jura 700 |
| Helper/error copy | Jura 400; Jura 600 for the short error title |
| Icon-only control glyph | System icon 700–900; never Cal Sans/Bebas/Aleo |

The current Apple font files are:

- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Fonts/CalSans-Regular.ttf` — Cal Sans brand font, TrueType (`.ttf`).
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Fonts/CalSansUI.wght.GEOM.ttf` — Cal Sans UI view-title font, TrueType (`.ttf`).
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Fonts/Jura-Variable.ttf` — Jura primary UI font, TrueType variable font (`.ttf`).
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Fonts/bebas-neue.ttf` — Bebas Neue display font, TrueType (`.ttf`).
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Fonts/Aleo-VariableFont_wght.ttf` — Aleo user-entry/long-form font, TrueType variable font (`.ttf`).
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Fonts/Aleo-Italic-VariableFont_wght.ttf` — Aleo italic long-form font, TrueType variable font (`.ttf`).
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Fonts/OFL-Aleo.txt` — Aleo license text, plain text (`.txt`).

### 5.3 Typography rules

- Keep Cal Sans restricted to the brand/logo role. Overusing it destroys its recognition value.
- Use Jura as the default UI face even when a platform has its own system font. System fonts remain valid fallbacks when the custom font cannot load.
- Use Bebas Neue sparingly. It is a display accent, not a general UI font.
- Use Aleo for user-authored content so user text feels distinct from system instructions.
- User-authored content must wrap, grow, and remain editable. Never truncate it merely to protect a fixed card height.
- Numeric statistics use Bebas Neue; metric labels use Jura. This assignment must be identical on iOS, iPadOS, macOS, Watch, Android, and Web.
- Section labels can use Bebas Neue with visual uppercase styling, but localization must be handled before display.
- Keep text size, weight, line height, and letter spacing as a semantic role rather than a per-screen guess.
- Prefer font scaling tied to the platform’s accessibility setting. Do not lock large titles to a fixed size that cannot shrink or reflow.
- Avoid artificially wide tracking in user-authored text. Bebas Neue may use display spacing; Aleo content should read naturally.

### 5.4 Platform font translation

#### Apple

Use the existing `AppTypography` semantic API. Do not reference font names directly from feature views unless adding a new semantic role.

#### Android

Create a `ToDoTypography` semantic layer in Compose with `FontFamily` mappings. Use `sp`, `FontWeight`, and `LocalDensity`/accessibility scaling. If the custom font files are not yet packaged in Android, use a platform sans fallback for Jura and a readable serif fallback for Aleo while preserving the role distinction.

#### Web

Use `@font-face` only after confirming redistribution rights for each font. The current Web foundation uses Geist and Georgia in places; that is acceptable for the first technical slice, but final product parity should move to the toDō semantic roles or a documented platform-approved fallback mapping. CSS variable names should be semantic, for example `--font-ui`, `--font-display`, and `--font-user-entry`.

Never use Georgia, Roboto, Inter, or a platform default as an unreviewed replacement for the full hierarchy. The fallback must preserve the functional distinction between UI, display, and user-authored text.

---

## 6. Layout, shape, and elevation

### 6.1 Spacing scale

Use a 4-point base scale with the following common values:

| Token | Value | Typical use |
| --- | ---: | --- |
| `space-1` | 4 | Icon/text separation, tiny label gaps |
| `space-2` | 8 | Chip internals, compact metadata |
| `space-3` | 12 | Card internals, row metadata, form groups |
| `space-4` | 16 | Standard screen padding, section separation |
| `space-5` | 20 | Card content, primary control gaps |
| `space-6` | 24 | Major section separation |
| `space-7` | 28 | Larger panel padding |
| `space-8` | 32 | Large surface and section separation |
| `space-9` | 40+ | Hero/empty-state breathing room |

Platform units are not identical: use points on Apple, dp on Android, and CSS pixels/rem on Web. Preserve relative hierarchy and touch target size rather than copying raw numbers blindly.

### 6.2 Corner radius

The visual language is rounded and continuous, not bubbly or ornamental.

| Token | Value | Typical use |
| --- | ---: | --- |
| `radius-small` | 12–14 | Inputs, small state cards |
| `radius-control` | 16–18 | Buttons, compact tiles |
| `radius-medium` | 20–22 | ToDō rows, detail cards, toolbars |
| `radius-large` | 30–32 | Hero panels, large sheets, auth/state cards |
| `radius-pill` | 999 | Tags, filters, compact status chips |

Do not mix unrelated radii on the same surface. A parent panel and its major child surfaces should feel like one family.

### 6.3 Surfaces and elevation

- The main canvas is quiet and slightly darker/lower contrast than elevated cards.
- Elevated surfaces are warm/near-white in light mode and slightly lighter than the dark canvas in dark mode.
- Shadows are soft, broad, and subordinate to content.
- Use borders where shadows are insufficient or when “Differentiate Without Color” is enabled.
- Elevation communicates containment and focus, never urgency or completion.
- A card can use a subtle tint derived from its semantic accent, but the underlying content must remain readable.
- Avoid stacking gradients, shadows, borders, and glass effects until the surface becomes visually noisy.

### 6.4 Touch and pointer targets

- Primary actions: minimum 44 × 44 pt/dp/CSS px-equivalent reachable area.
- Secondary icon actions: minimum 44 × 44 even when the visible glyph is smaller.
- Watch actions should preserve the same reachable target principle within the smaller viewport.
- Web buttons may look visually compact, but the interactive area must remain keyboard-visible and touch-friendly.
- Do not make a whole row both a completion action and a detail-navigation action without a clear separation.

### 6.5 Iconography

Use platform-native icon sets with shared semantic names:

- Apple: SF Symbols or custom vector assets where no symbol is suitable.
- Android: Material Symbols/icons or a documented custom icon set.
- Web: accessible inline SVG or a documented icon library.

Icon geometry may differ by platform, but the meaning and emphasis must match. Filled circles, checkmarks, calendars, clocks, flame/urgent symbols, tags, archive, trash, location, notes, and repeat must have consistent labels and state semantics.

Do not use an icon without an accessible label when it is the only visible control. Do not rely on emoji for system state; emoji may remain in user-authored content.

---

## 7. Core information architecture

### 7.1 Home

Home is the orientation surface and should answer: **What matters now?**

Recommended hierarchy:

1. Date/time context when useful.
2. toDō wordmark and a clear settings/account access point.
3. “What matters now?” panel.
4. Primary action: “New toDō.”
5. Secondary action: “See all toDōs,” with count when useful.
6. “Up Next” filters: “Due soon,” “Time-sensitive,” “Recent.”
7. “Momentum” summary with actionable Stats entry point.

The order may compress on Watch or adapt into a responsive Web layout, but the user should encounter orientation, capture, next work, and progress in that order.

### 7.2 Up Next semantics

The filters are product concepts, not merely visual tabs:

- **Due soon:** upcoming due items in a short, useful horizon. Exclude overdue items.
- **Time-sensitive:** only items whose reminder intent is time-sensitive.
- **Recent:** newest-created items first within the current recent window.

When there are no matching records, say what the filter means and offer the next useful action. Do not silently show a different category.

### 7.3 All toDōs

The list is the operational surface for scanning and triage.

- Completion control is visually distinct from opening the detail.
- Title is the dominant content.
- Due date/time, NanoDo progress, reminder intent, recurrence, tags, and collaboration context appear as compact metadata.
- User text wraps; rows grow as needed.
- Overdue rows receive a strong red treatment with an additional label/icon.
- Time-sensitive metadata remains legible on an overdue red row through the inverted chip rule.
- Sorting and filters are explicit and persistent according to the existing preferences.
- Search must include the fields the product promises to search, and search state must not leak across accounts.

### 7.4 ToDō detail and editor

The detail surface should make the task understandable before asking the user to edit it.

Canonical content order:

1. Close/back and edit actions.
2. User-authored title.
3. Status and late/overdue state.
4. Due date/time in one readable row.
5. Reminder intent.
6. Recurrence, when present.
7. Location/arrival information, with a map or platform-appropriate location presentation when present.
8. Tags.
9. NanoDos.
10. Notes.
11. Lifecycle actions: snooze, done/reopen, archive/trash according to preference.

Existing detail views must not present the due date as an unnecessarily cramped column when a single row is clearer. NanoDos must appear whenever present. The full editor should retain entered content through rotation, resize, navigation, permission changes, and interrupted sync.

### 7.5 NanoDos

NanoDos are actionable child steps, not decorative subtasks.

- Completion is independently interactive.
- Parent completion behavior must follow the shared domain contract.
- NanoDo text uses the user-entry type role and wraps.
- Empty NanoDo state should explain how to add the first step without competing with the title.
- On Watch, NanoDos remain useful but may be shown as a compact scrollable list.

### 7.6 Tags

Tags support recognition and filtering.

- Render tags as compact pills with readable text.
- Do not use tag color as the only identity unless color is explicitly user-configurable and paired with text.
- Preserve canonical tag names and ownership across sync.
- Keep tag editing separate from the fast capture path.

### 7.7 Stats

Stats are for reflection and the next decision, not competition or shame.

Canonical sections include active, done, overdue, due today, time-sensitive, scheduled, recurring, completion rate, NanoDo completion, workload shape, organization, completion trends, planning accuracy, and pressure signals.

Typography and layout rules:

- Display numbers use Bebas Neue.
- Metric titles use Jura.
- Section labels use Bebas Neue where a display moment is appropriate.
- Focus tiles use a consistent two-line content model rather than mixing title-above-value and value-above-title arrangements.
- The activity graph communicates completion history; it is not a generic edit counter.
- “Differentiate Without Color” adds visible cell borders or other non-color differentiation.
- Insights are opt-in and privacy-forward. Copy must not expose raw markdown markers such as `**bold**`.
- Unlocking insights may use a whole-viewport celebratory treatment, but it must be brief, interruptible, and removed for Reduce Motion.

---

## 8. Workflow principles

### 8.1 Fast capture

The shortest successful path is:

```text
Tap New toDō
    ↓
Write or speak a task
    ↓
Review the draft
    ↓
Save explicitly
```

Voice capture is an input method, not an automatic persistence path. The user reviews and explicitly saves the proposed toDō.

Permission requests should appear at the moment the user chooses the capability, with plain-language rationale. If a permission fails, preserve the draft and offer a text-entry fallback.

### 8.2 Guided onboarding

Guided onboarding is a stateful workflow that follows the user across views. It must not be implemented as a static overlay that disappears when navigation changes.

Required behavior:

- The first real toDō is created through a guided flow.
- During the “write the toDō” step, allow approximately 4–6 seconds of quiet writing time after input begins before advancing, with a longer pause when the user is still actively editing.
- After opening the created toDō, show only the next relevant instruction for that view.
- Keep “make changes when needed” inside ToDoView, with a clear next step or a highlighted close/back action after an appropriate delay.
- When the flow moves to Settings, show the instruction in Settings and provide a visible way to return to the onboarding line.
- Resume after interruption, dismissal, app backgrounding, or a permission prompt.
- Never abandon the user in a new view without saying what to do next or how to return.
- Provide a replay entry in Settings for testing and user education.

The same workflow semantics apply to Android and Web, even if the visual teaching mechanism becomes a Compose coach mark, Material dialog, browser callout, or inline instruction.

### 8.3 Navigation and return paths

Every destination must have a predictable return path:

- Apple: native back swipe, back button, sheet dismissal, or close action as appropriate.
- Android: system back, top app-bar navigation, or bottom-sheet dismissal; do not intercept back without a user-understandable reason.
- Web: semantic route links, browser Back/Forward, and deep-linkable detail routes.
- Watch: explicit close/back controls plus crown/scroll navigation where native.

Navigation transitions should communicate direction and continuity. Use slide plus opacity for view changes. Avoid transitions that look like unexplained zooming or only fade between unrelated surfaces.

### 8.4 Utility tray

The utility tray is the compact access point for secondary list actions such as search, filter, sorting, selection, bulk tagging, sync review, and settings. It should be present where the list workflow expects it, including macOS parity where appropriate.

The tray must:

- keep primary task completion visible;
- group secondary actions by purpose;
- avoid hiding essential actions behind an ambiguous icon;
- support keyboard, VoiceOver, TalkBack, and browser focus;
- collapse or become a toolbar/overflow menu on platforms where a persistent tray would be unnatural.

---

## 9. Platform translation rules

### 9.1 Shared invariant versus native expression

| Shared invariant | Apple | Android | Web |
| --- | --- | --- | --- |
| Home-first product model | SwiftUI HomeView | Compose Home screen | Responsive workspace landing route |
| Open detail | Sheet, navigation, or split panel | Navigation route or Material bottom sheet | `/todos/:id` route and browser history |
| List completion | Native control and haptic | Compose control and optional haptic | Button with keyboard/focus state |
| Secondary row actions | Swipe/context menu where discoverable | Explicit action menu or swipe with visible alternative | Labeled action menu; avoid relying on hover |
| Settings | Native settings navigation | Material list/settings screens | Route-based settings with browser navigation |
| Expanded layout | iPad/Mac split panels | 600dp+ navigation rail/side panel | CSS grid, max-width columns, optional master/detail |
| Motion | SwiftUI transitions and Reduce Motion | Compose animation scale and system setting | CSS transitions and `prefers-reduced-motion` |
| Icons | SF Symbols/custom assets | Material Symbols/custom assets | Accessible SVG/icon library |
| System quick access | Widgets, Live Activities, notifications | Widgets, notifications, future tiles | PWA/browser notifications only where legitimate |

### 9.2 Apple

Apple is the full reference implementation.

- Preserve the Home → ToDos → ToDo detail/editor mental model.
- Use sheets and native navigation where they make the task feel focused.
- Use iOS/iPadOS Liquid Glass only as an Apple expression of an already-defined surface; do not make glass the cross-platform brand requirement.
- iPad uses a split layout only when both panes remain readable.
- Mac is a native SwiftUI window target, not a Catalyst approximation. The menu-bar popover is a quick completion surface and entry point, not a duplicate editor.
- Widgets and Live Activities expose concise, high-value status; they do not become a second product UI.
- Watch is compact and scrollable, with core create/view/edit/completion flows; detailed commerce, profile administration, and collaboration management remain on larger screens.

### 9.3 Android phone and tablet

Android should use Material 3 and Compose conventions while retaining toDō semantics.

- Use Material 3 top app bars, navigation bars/rails, dialogs, and bottom sheets where appropriate.
- Preserve toDō’s rounded elevated cards, semantic colors, and typography hierarchy; do not imitate SwiftUI navigation bars or Apple sheet chrome.
- Use the Android system Back behavior as a first-class return path.
- Expand navigation at approximately 600dp available width, consistent with the current Android adaptive contract.
- Use a side panel or navigation rail on tablets only when labels remain complete and content is not compressed.
- Keep Room/local state, sync outbox, and stable Supabase UUID identity behind the UI. A visually successful Android surface is not parity if it creates a second object identity or loses offline edits.
- Android token values currently use `BrandPrimary = #E9A700`, `BrandSecondary = #00D8E7`, `BrandTertiary = #62C400`, and neutral surfaces. `BrandSecondary` should be reconciled to the current Apple canonical secondary blue or explicitly recorded as an approved Android-only accessibility adjustment; it must not drift accidentally.

Android source references:

- `/Users/shift/Development/Mobile/2026/Feb/ToDo/Google/ToDo_onGoogle/app/src/main/java/dev/iamshift/todo/android/ui/theme/Color.kt`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/Google/ToDo_onGoogle/app/src/main/java/dev/iamshift/todo/android/ui/theme/Theme.kt`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/Google/ToDo_onGoogle/app/src/main/java/dev/iamshift/todo/android/ui/AdaptiveLayout.kt`

### 9.4 Wear OS

Wear OS is a compact, high-value client rather than a shrunken phone.

- Home/Up Next overview, active list, completion/reopen, core create/edit, sync status, and account recovery are the priority.
- Keep detailed collaboration administration, map selection, commerce management, and long-form editing on phone/tablet/Web.
- Use Wear Compose patterns, scrollable sections, crown/rotary input, and system back behavior.
- Preserve the same IDs, lifecycle states, recurrence, reminder intent, tags, NanoDos, and sync semantics.
- Avoid a permanent Realtime connection merely because the Watch can connect. Use active-surface refresh and durable outbox behavior as defined by the Android Watch plan.

### 9.5 Web

Web must be recognizable as toDō without pretending to be an iPhone.

- Keep the Apple mental model: focused list, compact metadata, completion control, and detail with notes, due information, tags, and NanoDos.
- Use semantic links and routes, including `/todos/:id`, so browser Back/Forward works.
- Translate sheet presentation into a responsive detail route or desktop master/detail layout.
- Translate swipe/context actions into visible buttons, labeled menus, or keyboard-accessible action menus.
- Do not imitate Dynamic Island, Apple widgets, iOS sheets, or other Apple-only surfaces.
- Use CSS tokens, responsive max-widths, and readable desktop density.
- Support signed-out, setup, loading, empty, error, entitlement, read-only grace, paused, and offline states explicitly.
- Never put service credentials in browser code. Account switching clears account-specific caches.
- Web layout must remain usable at 320px minimum width, keyboard-only navigation, zoom, reduced motion, and high-contrast/browser settings.

Web source references:

- `/Users/shift/Development/Mobile/2026/Feb/ToDo/Web/docs/WebFoundationDecisions.md`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/Web/app/globals.css`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/Web/components/AppFrame.tsx`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/Web/features/todos/ToDoWorkspace.tsx`
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/Web/features/todos/ToDoDetail.tsx`

The current Web CSS uses approximate yellow/blue/green/red tokens and currently maps user-authored titles to Georgia. Those are acceptable implementation details only while the Web foundation is being built. Final parity should adopt the semantic toDō roles and a documented font fallback strategy.

---

## 10. Responsive and adaptive behavior

### 10.1 Logical layout classes

Use available viewport width, not device names, to select layout.

| Class | Intent | Typical behavior |
| --- | --- | --- |
| Compact | Phone, narrow window, Watch | One primary flow, stacked actions, scrollable content |
| Standard | Large phone, narrow tablet/window | One main pane with more breathing room |
| Expanded | Tablet, desktop, wide browser | Navigation rail/sidebar, larger content width |
| Split | Wide iPad/Mac/Web | List and detail/editor coexist when both remain readable |

Current reference thresholds:

- Apple Home primary actions stack below approximately 360pt.
- Apple iPad master/detail activates at approximately 1,000pt or wider.
- Current QA guidance describes the Mac split layout at approximately 980pt or wider; the implementation contains a 1,000pt side-by-side constant. This 980/1,000 difference is a known reconciliation item and should be resolved once in the shared adaptive contract.
- Android expanded navigation begins at approximately 600dp.
- Web should use content-driven CSS breakpoints; a useful starting point is compact below 720px and expanded layout above 1,000px, but no breakpoint may create clipped labels or unusable columns.

### 10.2 Resize behavior

When a viewport crosses a breakpoint:

- preserve the selected toDō;
- preserve draft text and editing state;
- preserve scroll position where practical;
- do not create a blank detail pane;
- do not duplicate an editor;
- do not reset filters or search without a product reason;
- animate only when the platform and accessibility settings permit it.

### 10.3 Text and data density

- Reduce decorative density before reducing legibility.
- Remove secondary metadata before truncating the title.
- Stack buttons before shrinking them below accessible targets.
- Move low-priority settings into a route/sheet/menu before making the primary workflow unreadable.
- Never use an ellipsis to hide the only way to understand a task’s due state or urgency.

---

## 11. Motion, haptics, sound, and feedback

### 11.1 Motion

Motion should answer one of three questions:

1. Where did this surface come from?
2. What changed because of my action?
3. What deserves attention now?

Reference motion values from Apple:

- Fast interaction: approximately 0.20s.
- Standard transition: approximately 0.24–0.28s.
- Section transition: approximately 0.28s.
- Tag transition: spring with a calm response around 0.42s.

Use slide plus opacity for navigation/view changes. Use scale plus opacity only for a focused overlay or celebration where the relationship is obvious. Do not make every surface zoom or pulse.

Reduce Motion must:

- remove or substantially shorten custom transitions;
- suppress full-viewport celebration particles;
- stop slow decorative image panning;
- keep state changes understandable through direct visual updates;
- preserve focus and completion feedback through color, text, icon, and layout.

Web must honor `prefers-reduced-motion`; Android must honor system animator scale/accessibility settings; Apple must honor Reduce Motion.

### 11.2 Haptics

Haptics are confirmation, not decoration.

- Light selection for changing a filter or paging Stats.
- Success/completion feedback for finishing a toDō or NanoDo.
- Warning/error feedback for destructive or failed actions only when it helps.
- Do not trigger repeated haptics for every row during a bulk operation.
- Web should use visual and focus feedback; haptics are optional and never required.

Reference implementation:

- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Core/Services/HapticFeedbackService.swift`

### 11.3 Notification sounds

Sound intent is shared even when a platform cannot use the same file:

- soft chime: quiet reminder;
- bright ping: due reminder;
- urgent double: time-sensitive/urgent reminder.

Canonical Apple sound media paths:

- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Sounds/todo-soft-chime.wav` — WAV audio (`.wav`).
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Sounds/todo-bright-ping.wav` — WAV audio (`.wav`).
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Sounds/todo-urgent-double.wav` — WAV audio (`.wav`).

Android and Web may use platform notification channels or browser rules, but the intent names and user control should remain familiar.

---

## 12. Accessibility, localization, and inclusion

### 12.1 Accessibility baseline

Every client must support:

- screen reader names and hints;
- keyboard/focus navigation where applicable;
- large text or browser zoom;
- Reduce Motion;
- Differentiate Without Color or equivalent high-contrast behavior;
- readable contrast in light and dark modes;
- content reflow without hidden actions;
- accessible labels for icon-only controls;
- error messages adjacent to the failed field/action;
- state changes announced without stealing focus.

The visible label and the accessible label should describe the same action. A compact icon may say “Complete ‘Submit TPS reports’,” not merely “circle.”

### 12.2 Dynamic type and zoom

- Scale semantic roles, not isolated font sizes.
- Let title/note/NanoDo containers grow vertically.
- At large text sizes, stack Home actions and Stats tiles.
- Do not hide due date, reminder intent, or delete/restore actions solely because text is large.
- Test long titles, long localized labels, and RTL text at one larger accessibility size in every primary workflow.

### 12.3 Localization

The Apple build supports Arabic, Urdu, Spanish, Hindi, Italian, Japanese, Malay, Thai, and Simplified Chinese in addition to English coverage.

- Never build user-facing strings by concatenating localized fragments in a way that prevents reordering.
- Use plural-aware strings for counts.
- Format dates/times with the active locale and configured time zone.
- Preserve the user’s chosen time source and location-time-zone behavior where the product supports it.
- Support RTL mirroring for layout, icons that have direction, navigation transitions, and alignment.
- Keep brand orthography stable; localize surrounding copy, not the spelling of `toDō`.
- Do not use English-only abbreviations such as “PM” or “wk” in the domain model.
- Localized user-authored text is content, not UI chrome; allow it to wrap and preserve it exactly.

### 12.4 Differentiate Without Color

When enabled:

- add visible borders to activity cells;
- use labels and icon changes for status;
- preserve the overdue border/background and add “Overdue”/“Late” text;
- use shape or checkmark changes for completion;
- never reduce a state to a subtle hue change.

---

## 13. Data, account, and sync experience

Visual parity is incomplete if account or sync behavior differs.

### 13.1 Account identity

The cross-platform account model is:

```text
Username identifies the toDō account
            ↓
Apple or Google proves account ownership
            ↓
Supabase auth.users.id owns the data
```

The username is the public identity shown across platforms. The immutable Supabase UUID remains the owner of toDōs, NanoDos, tags, Collabs, purchases, entitlements, and connected identities.

Customer-facing account UI must:

- show `@username` consistently;
- make the current account obvious before sync begins;
- prevent a provider mismatch from looking like lost data;
- clear account-specific cached data on sign-out or account switch;
- avoid exposing provider emails or private profile fields to collaborators.

### 13.2 Sync status

Sync feedback should be small, clear, and temporary unless action is required.

States to support:

- synced;
- syncing;
- offline/local-only;
- retrying;
- conflict needs review;
- account unresolved;
- saved data unavailable/temporary offline store.

Do not show a success toast for an operation that is only queued locally unless the copy says what actually happened. Do not hide a conflict or silently overwrite user-authored content.

### 13.3 Lifecycle and deletion

The shared lifecycle includes active, done, archived, and trashed states. Archive and trash are different user intentions.

- Done means the work is complete and can be reopened.
- Archive means remove from active workflow without treating it as deleted.
- Trash means the record is pending or eligible for deletion according to product settings.
- Permanent delete requires clear confirmation and should not be the default accidental gesture.
- Restore returns the record to the appropriate prior lifecycle state.

All clients must use the same tombstone and deletion semantics so a deleted record cannot reappear after sync.

---

## 14. Component guidance

### 14.1 Header and app chrome

- Keep headers visually calm and short.
- Use the wordmark where brand recognition matters; do not repeat it in every nested surface.
- Hide unnecessary subtitles/taglines.
- Keep title alignment and control placement stable within a platform.
- Use the platform’s native status bar, title bar, window controls, and safe areas.
- On Web, keep the wordmark as a home link and preserve browser navigation.

### 14.2 Primary actions

Primary actions should be obvious by position, color, label, and size.

- “New toDō” uses the yellow primary action role.
- “See all toDōs” uses the blue secondary/navigation role.
- “Stats” uses a positive/green or product-defined highlight without competing with creation.
- Destructive actions are red and require text/icon clarity.
- Do not assign the same prominence to New, Settings, Sync, and Delete.

### 14.3 ToDō row

Minimum row content:

- completion control;
- user-authored title;
- due metadata when present;
- urgency/reminder state when present;
- tags/collaboration/NanoDo summary only when useful;
- distinct detail affordance or whole-row link separate from completion.

Rows may grow. A 92px Web reference minimum is not a universal fixed height.

### 14.4 Detail cards

Detail cards are useful when they make an attribute scannable: due, reminder, location, recurrence, or sync state.

- One primary attribute per card.
- Label in a small UI/display role; value in readable UI or user-entry role.
- Icon sits in a high-contrast semantic circle or shape.
- Due date/time should remain a readable single row on narrow surfaces.
- A map/location preview belongs where the platform can make it useful; do not show an empty map placeholder.

### 14.5 Chips, tags, and filters

- Use pill shapes for compact, removable, or filterable tokens.
- Keep chip text short and localized.
- Selected filter is visually clear by fill and text/icon, not color alone.
- Metadata chips are lower prominence than the title.
- Do not overload a row with every possible chip; move detail into the detail surface.

### 14.6 Forms and editors

- Use an explicit label or strong contextual placeholder for every field.
- Keep the title field visually dominant but not so large that it consumes the form.
- Use Aleo for entered text, Jura for labels/help, and Bebas only for intentional section moments.
- Preserve the keyboard-safe scroll position.
- Save explicitly at the end of a create/edit workflow unless the product has a clearly communicated draft autosave model.
- Disable duplicate submits while saving, but show progress or saved state.

### 14.7 Empty, loading, error, and offline states

Every feature needs explicit states:

- **Loading:** explain what is loading; use restrained shimmer/skeleton only when helpful.
- **Empty:** explain what the user can do next; include a primary action.
- **Error:** state what failed, whether data is safe, and how to retry.
- **Offline:** distinguish saved local data from unsaved/queued changes.
- **No entitlement/access:** explain the capability boundary without implying data loss.

The Web foundation’s explicit state cards are a good cross-platform model, not a requirement to copy its exact CSS.

---

## 15. Media and asset reference register

This register is intentionally explicit. All media references in this document use absolute local filesystem paths that include the filename and file type. The stable asset ID is the portable reference to use in future Android/Web asset manifests.

### 15.1 Visual screenshot references

| Stable asset ID | Local filesystem path | Type | Role |
| --- | --- | --- | --- |
| `screenshot.home.light` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/Screenshots/homeview.png` | PNG (`.png`) | iPhone Home visual reference |
| `screenshot.todos.light` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/Screenshots/todosview.png` | PNG (`.png`) | iPhone ToDos list visual reference |
| `screenshot.todo-detail.light` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/Screenshots/todo-detail.png` | PNG (`.png`) | iPhone detail visual reference |
| `screenshot.stats.light` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/Screenshots/stats.png` | PNG (`.png`) | iPhone Stats visual reference |
| `screenshot.watch.home` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/Screenshots/watch.png` | PNG (`.png`) | Apple Watch Home visual reference |
| `screenshot.framed.home` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/Screenshots/Framed/homeview.png` | PNG (`.png`) | Framed/store-presentation Home reference |
| `screenshot.framed.todos` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/Screenshots/Framed/todosview.png` | PNG (`.png`) | Framed/store-presentation ToDos reference |
| `screenshot.framed.todo-detail` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/Screenshots/Framed/todo-detail.png` | PNG (`.png`) | Framed/store-presentation detail reference |
| `screenshot.framed.stats` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/Screenshots/Framed/stats.png` | PNG (`.png`) | Framed/store-presentation Stats reference |
| `screenshot.framed.watch` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/Screenshots/Framed/watch.png` | PNG (`.png`) | Framed/store-presentation Watch reference |

These screenshots are visual references, not production UI assets. Do not ship them inside the product or use them as a substitute for real responsive layouts.

### 15.2 Brand and logo references

| Stable asset ID | Local filesystem path | Type | Role |
| --- | --- | --- | --- |
| `brand.logomark.orange` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/brand-logomark.imageset/logo-orange.png` | PNG (`.png`) | Orange/yellow brand mark |
| `brand.logotype.light` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/brand-logotype.imageset/logotype-lightmode.png` | PNG (`.png`) | Light-mode logotype |
| `brand.logotype.dark` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/brand-logotype.imageset/logotype-darkmode.png` | PNG (`.png`) | Dark-mode logotype |
| `brand.plus.reference` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/brandPlusReference.imageset/brandPlusReference.jpg` | JPEG (`.jpg`) | Animated/masked plus reference artwork |
| `brand.banner.reference` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/brandBannerReference.imageset/brandBannerReference.jpeg` | JPEG (`.jpeg`) | Recognition/banner reference artwork |
| `brand.checkit` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/checkit.imageset/checkmark.png` | PNG (`.png`) | Checkmark visual reference |
| `brand.today.logo` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/todo-today-logo.imageset/todo-logo.png` | PNG (`.png`) | toDō Today/logo reference |
| `brand.watch.app-icon` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/ToDo Watch App/Assets.xcassets/AppIcon.appiconset/AppIcon-watchOS-Default-1024x1024@1x.png` | PNG (`.png`) | watchOS app icon |
| `brand.apple.app-icon.default` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-iOS-Default-1024x1024@1x.png` | PNG (`.png`) | Default iOS app icon |
| `brand.apple.app-icon.clear-light` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-iOS-ClearLight-1024x1024@1x.png` | PNG (`.png`) | Clear-light iOS app icon |
| `brand.apple.app-icon.dark` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-iOS-Dark-1024x1024@1x.png` | PNG (`.png`) | Dark iOS app icon |
| `brand.app-icon.legacy-reference` | `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/Resources/AppIcon.icon/Assets/logo 2.png` | PNG (`.png`) | App icon package reference |

The Watch target includes platform-local copies of the brand reference artwork. Keep their stable IDs the same while preserving the platform asset bundle:

- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/ToDo Watch App/Assets.xcassets/brand-logomark.imageset/logo-orange.png` — PNG (`.png`).
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/ToDo Watch App/Assets.xcassets/brandPlusReference.imageset/brandPlusReference.jpg` — JPEG (`.jpg`).
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/ToDo Watch App/Assets.xcassets/brandBannerReference.imageset/brandBannerReference.jpeg` — JPEG (`.jpeg`).
- `/Users/shift/Development/Mobile/2026/Feb/ToDo/ToDo/ToDo Watch App/Assets.xcassets/todo-today-logo.imageset/todo-logo.png` — PNG (`.png`).

### 15.3 Asset usage rules

- Prefer vector or text-rendered brand marks when the platform can preserve the wordmark accurately.
- Use the supplied raster assets for the reference artwork, app icons, and masked plus/banner treatments where the Apple build already does so.
- Do not crop, recolor, stretch, skew, or add effects to the wordmark without a deliberate brand decision.
- Preserve clear space around the wordmark equal to at least the height of the lowercase `o` in the rendered mark.
- The plus reference may have slow ambient motion on active Apple surfaces, but must be static when Reduce Motion is enabled or the app is inactive.
- The banner reference may use a dark readability tint; the tint must not erase the visual grid/color character.
- Android and Web should use stable asset IDs rather than absolute machine paths in production manifests. The absolute paths above are source references for the shared design record.

---

## 16. Quality gates and acceptance checklist

### 16.1 Brand gate

- [ ] Visible product copy uses `toDō` and `toDōs` correctly.
- [ ] Wordmark uses the correct macron character and casing.
- [ ] Cal Sans is restricted to brand/logo roles.
- [ ] Theme colors preserve semantic meaning and contrast.
- [ ] No platform has introduced a second unrelated primary accent.

### 16.2 UI gate

- [ ] Home leads with “What matters now?” or a faithful platform-native equivalent.
- [ ] New toDō is the highest-priority capture action.
- [ ] All toDōs list, detail, editor, Stats, Settings, and sync states exist where the platform scope promises them.
- [ ] Titles, notes, tags, and NanoDos wrap and remain readable.
- [ ] Rows separate completion from opening detail.
- [ ] Overdue plus time-sensitive inversion is implemented everywhere.
- [ ] Done and Trash foreground colors are readable in both modes.
- [ ] Utility tray/toolbar/overflow equivalent exists for list secondary actions.

### 16.3 UX gate

- [ ] Creation supports text first and voice where supported.
- [ ] Voice/AI proposals require review and explicit save.
- [ ] Guided onboarding follows the user across navigation and does not abandon them.
- [ ] Due soon excludes overdue.
- [ ] Time-sensitive means the reminder intent, not merely “has a date.”
- [ ] Recent is newest-created first within the defined recent window.
- [ ] Archive, trash, restore, permanent delete, and conflict review are explicit.
- [ ] Account switching clears stale account-specific UI/data.

### 16.4 Accessibility gate

- [ ] All icon-only controls have accessible labels.
- [ ] Status is still clear without color.
- [ ] Reduce Motion removes decorative/celebratory motion.
- [ ] Dynamic Type/large text/zoom does not clip controls or hide primary actions.
- [ ] Keyboard focus is visible and ordered.
- [ ] Screen reader users can understand title, due state, urgency, completion, and available actions.
- [ ] RTL layout and localized date/time formatting are verified.

### 16.5 Cross-platform parity gate

For each major field and lifecycle action, verify:

1. Create on Apple; verify Android and Web.
2. Create on Android; verify Apple and Web.
3. Create on Web; verify Apple and Android.
4. Update title, notes, due date/time, reminder, recurrence, tags, NanoDos, and location where supported.
5. Complete and reopen.
6. Archive, restore, trash, and permanently delete according to policy.
7. Test offline creation/editing and process termination.
8. Test account switch/sign-out and stale cache clearing.
9. Test long localized content and accessibility settings.
10. Confirm the UI looks native to each platform while the user can still predict the behavior.

---

## 17. Open reconciliation items

These items should be resolved once in the shared design/token contract rather than independently per platform:

1. **Secondary blue drift:** Android currently uses `#00D8E7` while Apple’s current classic theme uses approximately `#006CE7` and Web uses approximately `#0878E6`. Choose the canonical secondary role and record any accessibility-driven platform adjustment.
2. **Mac split breakpoint:** QA guidance uses approximately 980pt while the shared side-by-side constant is 1,000pt. Pick one logical contract or define a Mac-specific exception with evidence.
3. **Web typography:** The current Web foundation uses Geist and Georgia. Promote the final semantic fallback mapping before Web becomes a full product surface.
4. **Shared tokens:** Create a platform-neutral token manifest that can generate/validate Apple asset catalogs, Android Compose colors/typography, and Web CSS variables.
5. **Asset distribution:** Confirm font licensing and package approved brand assets into Android/Web bundles using stable IDs rather than developer-machine paths.
6. **Native system surfaces:** Define which cross-platform concepts have Apple widgets/Live Activities, Android widgets/notifications/tiles, Wear complications, and Web/PWA equivalents. Do not force a fake equivalent where the platform does not support the same surface.

---

## 18. Final design principle

toDō should be recognizable before a user reads every label: the wordmark, neutral canvas, bright purposeful accents, rounded surfaces, distinctive type roles, and home-first hierarchy should create immediate continuity.

It should remain understandable after the visual details change: the same task states, same urgency rules, same completion behavior, same account identity, same sync expectations, same return paths, and same respect for user-authored content must be present everywhere.

That is the durable brand system: **a consistent way of helping a person decide what matters now, expressed honestly in the language of each device.**
