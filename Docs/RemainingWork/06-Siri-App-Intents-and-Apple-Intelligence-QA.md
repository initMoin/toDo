# Step 06: Siri, App Intents, and Apple Intelligence QA

## Objective

Verify that App Intents are discoverable, route to toDō instead of Reminders or
another app, use Foundation Models only when available and enabled, ask one focused
follow-up question when needed, show the complete structured result for confirmation,
and persist the full toDō only after approval.

## Required Environment

- Physical Apple Intelligence-capable device.
- Supported OS version for the implemented Foundation Models APIs.
- Apple Intelligence downloaded, enabled, and available for the selected language.
- Siri enabled.
- toDō installed as the candidate build and launched at least once.
- The in-app Apple Intelligence toggle enabled for intelligence scenarios.
- Notifications, location, and Calendar permissions configured only when the
  scenario needs them.

## Confirm Shortcuts Discovery First

Before using voice:

1. Launch toDō and keep it open briefly so App Shortcuts can register.
2. Open Apple's Shortcuts app.
3. Search Apps for toDō.
4. Confirm these actions are visible:
   - Create a toDō
   - Create with Apple Intelligence
   - Complete a toDō
   - Open a toDō
5. Open each action and confirm its parameters render without missing labels.
6. If an action is absent, restart the device once, relaunch toDō, and inspect
   App Intent registration logs. Do not judge Siri phrasing before discovery works.

## Approved Intelligence Phrases

Test the currently implemented phrases exactly before testing natural variants:

- “Use Apple Intelligence in toDō”
- “Plan with toDō”
- “Capture my plan with toDō”

Record Siri's transcription. A failure caused by misrecognition is different from
an App Intent that receives the correct phrase but routes incorrectly.

## Structured Creation Scenario

Speak a request containing all major fields, for example:

```text
Submit toDō 3.1 Friday at 4 PM. Make it time-sensitive, tag it development,
note that TestFlight must be verified, add screenshots and release notes as
steps, and repeat only if I explicitly say it should repeat.
```

Verify the confirmation contains:

- Clean toDō title without date fragments.
- Correct absolute due date and local time.
- Time-Sensitive reminder intent.
- `development` tag.
- Note content only in notes.
- Screenshots and release notes as separate NanoDos.
- No recurrence unless explicitly requested.
- No fabricated location.

Confirm the toDō, then verify persistence, notification scheduling, widget refresh,
Live Activity eligibility, Calendar mirroring, and sync side effects.

## Clarification Scenario

Give an intentionally incomplete but actionable phrase:

```text
Prepare the release by next week and make it time-sensitive.
```

Expected behavior:

1. The model identifies that “next week” lacks a precise date/time required for a
   Time-Sensitive reminder.
2. It asks one focused follow-up question rather than inventing a date.
3. The answer updates the structured object.
4. The complete result is shown for confirmation.
5. Nothing is persisted before confirmation.

Reject the result and confirm no toDō, notification, widget entry, Live Activity,
Calendar event, or sync mutation is created.

## Field-Specific Scenarios

Run separate tests for:

- Date only, using the configured default reminder time.
- Date and explicit time.
- Explicit recurrence and recurrence end.
- “Subtasks,” “steps,” and “NanoDos” phrasing.
- Multiple tags.
- Long notes.
- Location intent with permission granted.
- Location intent with permission denied.
- Quiet reminder versus Time-Sensitive reminder.
- No due date.
- Edit before confirmation.

## Unavailable and Disabled States

### Apple Intelligence unavailable

Disable Apple Intelligence or use an unsupported device. Confirm:

- No crash or endless loading state.
- The app explains that Apple Intelligence is unavailable.
- The support action with `arrow.right` opens
  `https://support.apple.com/en-us/121115`.
- Manual creation remains fully available.

### User-disabled preference

Turn off the in-app feature using `apple.intelligence.badge.xmark`. Confirm:

- Intelligence parsing is not invoked.
- Speech/manual creation still follows the non-intelligence path.
- The preference persists for that account/device according to the implementation.

## Siri Routing Failures

If Reminders, Todoist, or another app opens:

1. Capture exactly what Siri displayed as recognized speech.
2. Confirm the toDō App Shortcut is visible in Shortcuts.
3. Run the action by tapping it. If tapping fails, this is an App Intent issue.
4. If tapping succeeds but Siri routes elsewhere, record the phrase-routing issue
   separately.
5. Do not add increasingly unnatural phrases as a substitute for a broken action.

## Privacy Checks

- Speech transcripts and model prompts must not be logged with personal data.
- Foundation Models processing must use the implemented on-device privacy boundary.
- A confirmation must precede persistence.
- Unrelated toDōs must not be exposed to an intent unless the action requires and
  authorizes them.

## Pass Criteria

- [ ] All four actions are discoverable in Shortcuts.
- [ ] Approved Siri phrases route to toDō.
- [ ] Complete voice input becomes an accurate structured object.
- [ ] Ambiguity produces one useful follow-up instead of invented data.
- [ ] Recurrence is never invented.
- [ ] Confirmation controls persistence and side effects.
- [ ] Disabled and unavailable states are clear and safe.
- [ ] Manual creation remains available.
- [ ] No private transcript or model content appears in logs.

