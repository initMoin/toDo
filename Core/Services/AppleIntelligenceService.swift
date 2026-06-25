import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct AppleIntelligenceSummaryInput: Sendable {
   let activeCount: Int
   let overdueCount: Int
   let dueTodayCount: Int
   let timeSensitiveCount: Int
   let completedLastSevenDaysCount: Int
   let staleCount: Int
   let focusPressureScore: Int
   let strongestDeterministicInsight: String

   var deterministicSummary: String {
      [
         strongestDeterministicInsight,
         String(format: String(localized: "%@ active."), AppLocalization.numberString(activeCount)),
         String(format: String(localized: "%@ overdue."), AppLocalization.numberString(overdueCount)),
         String(format: String(localized: "%@ due today."), AppLocalization.numberString(dueTodayCount)),
         String(format: String(localized: "%@ time-sensitive."), AppLocalization.numberString(timeSensitiveCount)),
         String(format: String(localized: "%@ completed in the last 7 days."), AppLocalization.numberString(completedLastSevenDaysCount)),
         String(format: String(localized: "%@ stale for more than 14 days."), AppLocalization.numberString(staleCount)),
         String(format: String(localized: "Focus pressure: %@/100."), AppLocalization.numberString(focusPressureScore))
      ].joined(separator: " ")
   }

   var appleIntelligencePrompt: String {
      """
      You are helping a toDō user understand their current task pressure.
      Keep the response practical, calm, and under 75 words.
      Do not invent tasks. Do not mention AI. Use the data only.

      Active: \(activeCount)
      Overdue: \(overdueCount)
      Due today: \(dueTodayCount)
      Time-sensitive: \(timeSensitiveCount)
      Completed last 7 days: \(completedLastSevenDaysCount)
      Stale over 14 days: \(staleCount)
      Focus pressure: \(focusPressureScore)/100
      Deterministic signal: \(strongestDeterministicInsight)

      Give the user one concise summary and one next move.
      """
   }
}

struct AppleIntelligenceFocusCandidate: Sendable {
   let title: String
   let dueDate: Date?
   let reminderIntent: String
   let isOverdue: Bool
}

struct AppleIntelligenceFocusInput: Sendable {
   let candidates: [AppleIntelligenceFocusCandidate]
   let activeCount: Int
   let overdueCount: Int
   let dueTodayCount: Int
   let timeSensitiveCount: Int

   var deterministicRecommendation: String {
      guard let candidate = candidates.first else {
         return String(localized: "Nothing needs the front row right now.")
      }

      if candidate.isOverdue {
         return String(format: String(localized: "Start with %@. It is overdue, so finishing or rescheduling it should come first."), candidate.title)
      }

      if candidate.reminderIntent == ToDoReminderIntent.timeSensitive.rawValue {
         return String(format: String(localized: "Start with %@. It is time-sensitive and has the clearest pressure right now."), candidate.title)
      }

      if candidate.dueDate != nil {
         return String(format: String(localized: "Start with %@. It has a due moment, so it is the best next focus."), candidate.title)
      }

      return String(format: String(localized: "Start with %@. It is the clearest next active toDō."), candidate.title)
   }

   var appleIntelligencePrompt: String {
      let candidateLines = candidates.enumerated().map { index, candidate in
         let dueText = candidate.dueDate?.formatted(date: .abbreviated, time: .shortened) ?? "No due date"
         return "\(index + 1). \(candidate.title) | due: \(dueText) | reminder: \(candidate.reminderIntent) | overdue: \(candidate.isOverdue)"
      }.joined(separator: "\n")

      return """
      You are helping a toDō user choose what to do next.
      Keep the response under 45 words.
      Do not invent tasks. Do not mention AI. Use only the candidate toDōs below.
      Choose one task and explain why in one practical sentence.

      Active: \(activeCount)
      Overdue: \(overdueCount)
      Due today: \(dueTodayCount)
      Time-sensitive: \(timeSensitiveCount)

      Candidate toDōs:
      \(candidateLines)
      """
   }
}

struct AppleIntelligenceToDoDraft: Sendable {
   let title: String
   let notes: String
   let dueDate: Date?
   let reminderIntent: ToDoReminderIntent
   let recurrenceUnit: ToDoRecurrenceUnit?
   let recurrenceInterval: Int?
   let recurrenceMode: ToDoRecurrenceMode?
   let recurrenceCount: Int?
   let recurrenceEndDate: Date?
   let tagNames: [String]
   let nanoDoTitles: [String]
   let locationLabel: String?
   let locationTrigger: ToDoLocationReminderTrigger?
}

private struct AppleIntelligenceToDoDraftPayload: Decodable {
   let title: String
   let notes: String?
   let dueDate: String?
   let reminderIntent: String?
   let recurrenceUnit: String?
   let recurrenceInterval: Int?
   let recurrenceMode: String?
   let recurrenceCount: Int?
   let recurrenceEndDate: String?
   let tagNames: [String]?
   let nanoDoTitles: [String]?
   let locationLabel: String?
   let locationTrigger: String?
}

enum AppleIntelligenceService {
   static var isFrameworkCompiledIn: Bool {
      #if canImport(FoundationModels)
      true
      #else
      false
      #endif
   }

   static var isAvailable: Bool {
      #if canImport(FoundationModels)
      #if !os(watchOS)
      if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
         let onDeviceModel = SystemLanguageModel.default
         return onDeviceModel.isAvailable && onDeviceModel.supportsLocale()
      }
      #endif
      #endif

      return false
   }

   static func summarize(_ input: AppleIntelligenceSummaryInput, isEnabled: Bool) async -> String {
      guard isEnabled else { return input.deterministicSummary }

      #if canImport(FoundationModels)
      #if !os(watchOS)
      if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
         let onDeviceModel = SystemLanguageModel.default
         if onDeviceModel.isAvailable, onDeviceModel.supportsLocale() {
            return await summarize(input, using: onDeviceModel)
         }
      }
      #endif
      #endif

      return input.deterministicSummary
   }

   static func recommendNextFocus(_ input: AppleIntelligenceFocusInput, isEnabled: Bool) async -> String {
      guard isEnabled else { return input.deterministicRecommendation }

      #if canImport(FoundationModels)
      #if !os(watchOS)
      if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
         let onDeviceModel = SystemLanguageModel.default
         if onDeviceModel.isAvailable, onDeviceModel.supportsLocale() {
            return await recommendNextFocus(input, using: onDeviceModel)
         }
      }
      #endif
      #endif

      return input.deterministicRecommendation
   }

   static func parseSpokenToDo(_ spokenRequest: String, isEnabled: Bool) async -> AppleIntelligenceToDoDraft? {
      let trimmedRequest = spokenRequest.trimmingCharacters(in: .whitespacesAndNewlines)
      guard isEnabled, !trimmedRequest.isEmpty else { return nil }

      #if canImport(FoundationModels)
      #if !os(watchOS)
      if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
         let onDeviceModel = SystemLanguageModel.default
         if onDeviceModel.isAvailable, onDeviceModel.supportsLocale() {
            return await withTaskGroup(of: AppleIntelligenceToDoDraft?.self) { group in
               group.addTask {
                  await parseSpokenToDo(trimmedRequest, using: onDeviceModel)
               }
               group.addTask {
                  try? await Task.sleep(for: .seconds(20))
                  guard !Task.isCancelled else { return nil }
                  await MainActor.run {
                     AppLog.error("Apple Intelligence voice parsing timed out after 20 seconds.", logger: AppLog.app)
                  }
                  return nil
               }

               let result = await group.next() ?? nil
               group.cancelAll()
               return result
            }
         }
      }
      #endif
      #endif

      return nil
   }

   #if canImport(FoundationModels)
   @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
   @available(watchOS, unavailable)
   private static func summarize(_ input: AppleIntelligenceSummaryInput, using model: SystemLanguageModel) async -> String {
      do {
         let session = LanguageModelSession(
            model: model,
            instructions: "You write clear, concise productivity summaries for toDō. Be specific, useful, and privacy-respectful."
         )
         let response = try await session.respond(
            to: input.appleIntelligencePrompt,
            options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 140)
         )
         let summary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
         return summary.isEmpty ? input.deterministicSummary : summary
      } catch {
         AppLog.error("Apple Intelligence summary failed: \(error)", logger: AppLog.app)
         return input.deterministicSummary
      }
   }

   @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
   @available(watchOS, unavailable)
   private static func recommendNextFocus(_ input: AppleIntelligenceFocusInput, using model: SystemLanguageModel) async -> String {
      do {
         let session = LanguageModelSession(
            model: model,
            instructions: "You make concise, practical focus recommendations for toDō. Pick one task, explain why, and avoid generic productivity advice."
         )
         let response = try await session.respond(
            to: input.appleIntelligencePrompt,
            options: GenerationOptions(temperature: 0.15, maximumResponseTokens: 90)
         )
         let recommendation = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
         return recommendation.isEmpty ? input.deterministicRecommendation : recommendation
      } catch {
         AppLog.error("Apple Intelligence focus recommendation failed: \(error)", logger: AppLog.app)
         return input.deterministicRecommendation
      }
   }

   @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
   @available(watchOS, unavailable)
   private static func parseSpokenToDo(
      _ spokenRequest: String,
      using model: SystemLanguageModel
   ) async -> AppleIntelligenceToDoDraft? {
      let now = Date.now
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

      let prompt = """
      Convert the user's spoken request into one toDō draft.
      Return only one valid JSON object with exactly these keys:
      title, notes, dueDate, reminderIntent, recurrenceUnit, recurrenceInterval,
      recurrenceMode, recurrenceCount, recurrenceEndDate, tagNames, nanoDoTitles,
      locationLabel, locationTrigger.

      Rules:
      - Resolve relative dates using the supplied current date, calendar, locale, and time zone.
      - The next occurrence of a named weekday is intended unless the user supplies
        an explicit date or says otherwise.
      - dueDate and recurrenceEndDate must be ISO-8601 strings or null.
      - reminderIntent must be "soft", "due", or "timeSensitive".
      - Use "soft" when no alert is requested. Use "due" for a normal alert. Use
        "timeSensitive" only when the user explicitly asks for time-sensitive or
        Focus-breaking behavior.
      - recurrenceUnit must be seconds, minutes, hours, days, weeks, months, years, or null.
      - recurrenceMode must be finite, continuous, or null.
      - recurrenceInterval and recurrenceCount must be positive integers or null.
      - Set every recurrence field to null unless the user explicitly says repeat,
        recurring, every day/week/month/year, daily, weekly, monthly, yearly, or
        otherwise clearly requests recurrence.
      - tagNames and nanoDoTitles must be JSON arrays. Do not invent either.
      - locationTrigger must be arriving, leaving, or null. Preserve a requested place
        as locationLabel, but do not invent a place.
      - Keep the title concise. Put supporting context in notes.
      - Notes must contain only content explicitly introduced as a note or notes.
        Never repeat tag instructions or step instructions inside notes.
      - "steps", "subtasks", "sub tasks", "child tasks", and "NanoDos" all mean
        nanoDoTitles. Content introduced by any of those terms belongs only in
        nanoDoTitles, one action per array item, and never in notes.
      - A requested count such as "3 subtasks" is not enough to invent tasks.
        Only include subtask titles the user actually states.
      - Do not add facts the user did not say.

      Current ISO date: \(formatter.string(from: now))
      Calendar: \(Calendar.current.identifier)
      Locale: \(Locale.current.identifier)
      Time zone: \(TimeZone.current.identifier)

      Spoken request:
      \(spokenRequest)
      """

      do {
         let session = LanguageModelSession(
            model: model,
            instructions: "You extract structured toDō details from natural language. Return strict JSON and never invent details."
         )
         let response = try await session.respond(
            to: prompt,
            options: GenerationOptions(temperature: 0, maximumResponseTokens: 600)
         )
         return decodeToDoDraft(from: response.content, spokenRequest: spokenRequest)
      } catch {
         AppLog.error("Apple Intelligence voice parsing failed: \(error)", logger: AppLog.app)
         return nil
      }
   }
   #endif

   static func decodeToDoDraft(
      from response: String,
      spokenRequest: String
   ) -> AppleIntelligenceToDoDraft? {
      guard let jsonData = jsonObjectData(from: response),
            let payload = try? JSONDecoder().decode(AppleIntelligenceToDoDraftPayload.self, from: jsonData)
      else {
         AppLog.error("Apple Intelligence returned an invalid toDō draft.", logger: AppLog.app)
         return nil
      }

      let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !title.isEmpty else { return nil }

      return VoiceToDoIntentResolver.resolve(
         spokenRequest: spokenRequest,
         modelDraft: VoiceToDoIntentModelDraft(
            title: title,
            notes: payload.notes,
            dueDate: parseISO8601Date(payload.dueDate),
            reminderIntent: payload.reminderIntent,
            recurrenceUnit: payload.recurrenceUnit,
            recurrenceInterval: payload.recurrenceInterval,
            recurrenceMode: payload.recurrenceMode,
            recurrenceCount: payload.recurrenceCount,
            recurrenceEndDate: parseISO8601Date(payload.recurrenceEndDate),
            tagNames: payload.tagNames ?? [],
            nanoDoTitles: payload.nanoDoTitles ?? [],
            locationLabel: payload.locationLabel,
            locationTrigger: payload.locationTrigger
         )
      )
   }

   private static func jsonObjectData(from response: String) -> Data? {
      guard let start = response.firstIndex(of: "{"),
            let end = response.lastIndex(of: "}"),
            start <= end
      else { return nil }
      return String(response[start...end]).data(using: .utf8)
   }

   private static func parseISO8601Date(_ value: String?) -> Date? {
      guard let value = nonempty(value) else { return nil }
      let fractionalFormatter = ISO8601DateFormatter()
      fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      if let date = fractionalFormatter.date(from: value) {
         return date
      }
      return ISO8601DateFormatter().date(from: value)
   }

   static func containsExplicitTime(in value: String) -> Bool {
      VoiceToDoIntentResolver.containsExplicitTime(in: value)
   }

   private static func nonempty(_ value: String?) -> String? {
      guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmed.isEmpty
      else { return nil }
      return trimmed
   }
}
