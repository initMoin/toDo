# Typography and Adaptive Layout QA

## Typography Contract

Use the semantic typography roles rather than direct font names in feature views.

| Role | Typeface | Intended use |
| --- | --- | --- |
| Brand | Cal Sans | The toDō wordmark only |
| Primary UI | Jura | Titles, body copy, metadata, badges, and controls |
| Display | Bebas Neue | Section labels and intentionally prominent display text |
| Long-form | Aleo Regular Italic | Notes and sustained reading |
| User entry | Aleo Medium | User-authored toDō, note, tag, and nanoDo text |

Watch and widget targets use the same semantic hierarchy at platform-appropriate sizes. The Jura variable font must be requested by the `Jura` family name with a SwiftUI weight, not a fabricated static face name.

## Adaptive Contract

- Primary Home actions stack below 360 points or at accessibility Dynamic Type sizes.
- iPad master/detail layouts activate only at 1,000 points or wider.
- Narrow iPad and Stage Manager windows use the compact single-pane flow.
- Mac ToDos uses a focused single pane below 980 points and a split pane at 980 points or wider.
- Watch Home actions share one scaled height, clamped from 50 to 62 points.
- Text labels must remain single-line only when the component has a scaling or alternate-layout strategy. User-authored content must wrap and expand its container.

## Real-device Acceptance Matrix

Run each row in light and dark modes. Repeat the primary-action and form checks at the default text size and one larger accessibility text size.

### Narrow iPhone

Test at 320, 375, and 393-point widths where hardware is available.

1. Open Home. Confirm `New toDō` and `See all toDōs` are complete, equal-height, and have at least a 44-point tap target.
2. At widths below 360 points, confirm the actions stack without truncation.
3. Open ToDos, then create, view, and edit a toDō with a long title, tags, notes, recurrence, location, and at least three nanoDos.
4. Confirm user-entered text uses Aleo, section labels use Bebas Neue, and general UI copy uses Jura.
5. Confirm the keyboard does not cover the active form control and all form sections remain scrollable.
6. Enable the largest practical Dynamic Type size and confirm controls do not overlap or clip.

### iPad Split Layouts

Test portrait and landscape at narrow split, half-width, and full-width sizes.

1. Below 1,000 points, confirm ToDos, Settings, Stats, and standalone ToDo forms use the compact single-pane composition.
2. At 1,000 points or wider, confirm ToDos and Settings present readable side-by-side panes without compressed labels.
3. Resize across the breakpoint while a detail or editor is open. Confirm the selected content remains available and no blank pane appears.
4. Confirm Stats changes from a single flow to its two-column board only when both columns remain comfortably readable.
5. Confirm rounded containers clip scrolling content at every corner.

### Apple Watch

Test the smallest supported Watch and a 49 mm Ultra.

1. Confirm Home action buttons have identical heights and complete labels.
2. Confirm Cal Sans is restricted to the wordmark; section labels use Bebas Neue; UI and metadata use Jura; user text uses Aleo.
3. Open create, view, and edit flows with a long title, due date, recurrence, tags, notes, location, and nanoDos.
4. Confirm metadata wraps instead of truncating the due date and that every action remains reachable by scrolling.
5. Confirm the Ultra does not inflate controls into excessive empty space and the smallest Watch does not clip controls.

### Mac Windows

Test approximately 700 x 620, 980 x 700, and 1,200 x 800 point windows.

1. Below 980 points, select or create a toDō and confirm the focused editor/detail replaces the list cleanly.
2. At 980 points or wider, confirm list and detail/editor coexist without squeezing either pane.
3. Resize across 980 points with an editor open. Confirm the edit state and entered content remain intact.
4. Confirm Home actions stack if their labels cannot remain complete and return to a row when space permits.
5. Confirm every custom font remains visible after a cold launch, not only after navigating or resizing.

## Failure Evidence

For any failure, capture:

- Platform, hardware model, OS build, orientation, and effective viewport width.
- Display mode and Dynamic Type size.
- The view and action that exposed the issue.
- A screenshot or short recording showing the full container boundaries.
- Console lines only when the failure is behavioral rather than visual.
