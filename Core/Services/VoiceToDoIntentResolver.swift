import Foundation

struct VoiceToDoIntentModelDraft: Sendable {
   let title: String
   let notes: String?
   let dueDate: Date?
   let reminderIntent: String?
   let recurrenceUnit: String?
   let recurrenceInterval: Int?
   let recurrenceMode: String?
   let recurrenceCount: Int?
   let recurrenceEndDate: Date?
   let tagNames: [String]
   let nanoDoTitles: [String]
   let locationLabel: String?
   let locationTrigger: String?
}

enum VoiceToDoIntentResolver {
   static func resolve(spokenRequest: String, modelDraft: VoiceToDoIntentModelDraft) -> AppleIntelligenceToDoDraft? {
      let trimmedRequest = spokenRequest.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedRequest.isEmpty else { return nil }

      let dueDate = detectedDueDate(in: trimmedRequest) ?? modelDraft.dueDate
      let title = resolvedTitle(from: modelDraft.title, spokenRequest: trimmedRequest)
      guard !title.isEmpty else { return nil }

      let reminderIntent = ToDoReminderIntent(rawValue: modelDraft.reminderIntent ?? "")
         ?? (dueDate == nil ? .soft : .due)
      let recurrenceUnit = modelDraft.recurrenceUnit.flatMap(ToDoRecurrenceUnit.init(rawValue:))
      let recurrenceMode = modelDraft.recurrenceMode.flatMap(ToDoRecurrenceMode.init(rawValue:))
      let recurrenceInterval = positive(modelDraft.recurrenceInterval)
      let recurrenceCount = positive(modelDraft.recurrenceCount)
      let hasExplicitRecurrence = containsExplicitRecurrence(in: trimmedRequest)
      let hasValidRecurrence = hasExplicitRecurrence
         && dueDate != nil
         && recurrenceUnit != nil
         && recurrenceInterval != nil
         && recurrenceMode != nil
      let explicitNanoDos = explicitNanoDoTitles(in: trimmedRequest)
      let resolvedNanoDos = explicitNanoDos.isEmpty
         ? normalizedUniqueStrings(modelDraft.nanoDoTitles, limit: 12)
         : explicitNanoDos

      return AppleIntelligenceToDoDraft(
         title: title,
         // Model-generated notes are not trusted without an explicit note
         // directive because models may misclassify tags or subtasks as notes.
         notes: explicitNotes(in: trimmedRequest) ?? "",
         dueDate: dueDate,
         reminderIntent: reminderIntent,
         recurrenceUnit: hasValidRecurrence ? recurrenceUnit : nil,
         recurrenceInterval: hasValidRecurrence ? recurrenceInterval : nil,
         recurrenceMode: hasValidRecurrence ? recurrenceMode : nil,
         recurrenceCount: hasValidRecurrence && recurrenceMode == .finite ? recurrenceCount : nil,
         recurrenceEndDate: hasValidRecurrence ? modelDraft.recurrenceEndDate : nil,
         tagNames: normalizedUniqueStrings(modelDraft.tagNames, limit: ToDo.maxTagSelection),
         nanoDoTitles: resolvedNanoDos,
         locationLabel: nonempty(modelDraft.locationLabel),
         locationTrigger: modelDraft.locationTrigger.flatMap(ToDoLocationReminderTrigger.init(rawValue:))
      )
   }

   static func containsExplicitTime(in value: String) -> Bool {
      let patterns = [
         #"\b(?:at|by)\s+\d{1,2}(?::\d{2})?\s*(?:a\.?m\.?|p\.?m\.?)\b"#,
         #"\b\d{1,2}:\d{2}\b"#,
         #"\b(?:noon|midnight)\b"#
      ]
      return patterns.contains { pattern in
         containsPhrase(pattern, in: value)
      }
   }

   private static func resolvedTitle(from modelTitle: String, spokenRequest: String) -> String {
      let trimmedModelTitle = modelTitle.trimmingCharacters(in: .whitespacesAndNewlines)
      let source = trimmedModelTitle.isEmpty ? spokenRequest : trimmedModelTitle
      let cleaned = duePhrasePatterns.reduce(source) { current, pattern in
         replacingMatches(pattern, in: current, with: " ")
      }
      return cleaned
         .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
         .trimmingCharacters(in: CharacterSet(charactersIn: " .,!?:;-"))
   }

   private static func detectedDueDate(in spokenRequest: String) -> Date? {
      let sanitized = replacingVersionNumbers(in: spokenRequest)
      if let relativeDate = detectedRelativeDueDate(in: sanitized) {
         return relativeDate
      }

      guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
         return nil
      }

      let range = NSRange(sanitized.startIndex..., in: sanitized)
      return detector.matches(in: sanitized, range: range)
         .compactMap(\.date)
         .first
   }

   private static var duePhrasePatterns: [String] {
      [
         #"(?i)\b(?:by|before|due)\s+next\s+week\b"#,
         #"(?i)\b(?:by|before|due)\s+next\s+month\b"#,
         #"(?i)\b(?:by|before|due)\s+tomorrow\b"#,
         #"(?i)\b(?:by|before|due)\s+today\b"#
      ]
   }

   private static func detectedRelativeDueDate(in value: String, now: Date = .now) -> Date? {
      let normalized = value.folding(
         options: [.caseInsensitive, .diacriticInsensitive],
         locale: .current
      )
      let calendar = Calendar.current

      let relativeDeadlines: [(pattern: String, component: Calendar.Component, value: Int)] = [
         (#"\b(?:by|before|due)\s+next\s+week\b"#, .day, 7),
         (#"\b(?:by|before|due)\s+next\s+month\b"#, .month, 1),
         (#"\b(?:by|before|due)\s+tomorrow\b"#, .day, 1)
      ]

      for deadline in relativeDeadlines where containsPhrase(deadline.pattern, in: normalized) {
         return calendar.date(byAdding: deadline.component, value: deadline.value, to: now)
      }

      if containsPhrase(#"\b(?:by|before|due)\s+today\b"#, in: normalized) {
         return now
      }

      return nil
   }

   private static func replacingVersionNumbers(in value: String) -> String {
      replacingMatches(#"(?i)\b(?:version|v)?\s*\d+(?:\.\d+)+\b"#, in: value, with: " ")
   }

   private static func containsExplicitRecurrence(in value: String) -> Bool {
      let normalized = value.folding(
         options: [.caseInsensitive, .diacriticInsensitive],
         locale: .current
      )
      let recurrenceTerms = [
         "repeat", "recurring", "recur", "every day", "every week", "every month",
         "every year", "daily", "weekly", "monthly", "yearly",
         "repetir", "recurrente", "diario", "semanal", "mensual", "anual",
         "ripeti", "ricorrente", "giornaliero", "settimanale", "mensile", "annuale",
         "كرر", "متكرر", "يوميا", "اسبوعيا", "شهريا", "سنويا",
         "繰り返", "毎日", "毎週", "毎月", "毎年",
         "重复", "每天", "每周", "每月", "每年"
      ]
      if recurrenceTerms.contains(where: { normalized.contains($0) }) {
         return true
      }

      return containsPhrase(#"\bevery\s+(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|weekday|weekend)\b"#, in: normalized)
   }

   private static func explicitNotes(in value: String) -> String? {
      let patterns = [
         #"(?i)\bnote\s+that\s+(.+?)(?=,\s*(?:and\s+)?(?:add|tag|repeat|remind)\b|[.!?](?:\s|$)|$)"#,
         #"(?i)\bnotes?\s*:\s*(.+?)(?=,\s*(?:and\s+)?(?:add|tag|repeat|remind)\b|[.!?](?:\s|$)|$)"#
      ]

      for pattern in patterns {
         guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
         let range = NSRange(value.startIndex..., in: value)
         guard let match = expression.firstMatch(in: value, range: range),
               match.numberOfRanges > 1,
               let contentRange = Range(match.range(at: 1), in: value)
         else { continue }

         let notes = value[contentRange].trimmingCharacters(in: .whitespacesAndNewlines)
         if !notes.isEmpty {
            return notes
         }
      }

      return nil
   }

   private static func explicitNanoDoTitles(in value: String) -> [String] {
      let patterns = [
         #"(?i)\b(?:add|include|create|with|having)\s+(?:\d+\s+)?(?:sub\s*tasks?|subtasks?|steps?|nanodos?|child\s+tasks?)\s*(?:to\s+be\s+completed)?\s*(?:of|:|-)?\s*(.+)$"#,
         #"(?i)\b(?:sub\s*tasks?|subtasks?|steps?|nanodos?|child\s+tasks?)\s*(?:to\s+be\s+completed)?\s*(?:are|include|of|:|-)\s*(.+)$"#,
         #"(?i)\badd\s+(.+?)\s+as\s+(?:sub\s*tasks?|subtasks?|steps?|nanodos?|child\s+tasks?)\b"#
      ]

      for pattern in patterns {
         guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
         let range = NSRange(value.startIndex..., in: value)
         guard let match = expression.firstMatch(in: value, range: range),
               match.numberOfRanges > 1,
               let contentRange = Range(match.range(at: 1), in: value)
         else { continue }

         let content = String(value[contentRange])
            .trimmingCharacters(in: CharacterSet(charactersIn: " .!?"))
         guard !content.isEmpty, !isCountOnlySubtaskDescription(content) else {
            return []
         }

         return splitNanoDoTitles(content)
      }

      return []
   }

   private static func splitNanoDoTitles(_ content: String) -> [String] {
      let normalized = content
         .replacingOccurrences(of: #"\s*,\s*(?:and|then)\s+"#, with: ",", options: .regularExpression)
         .replacingOccurrences(of: #"\s*;\s*"#, with: ",", options: .regularExpression)
         .replacingOccurrences(of: #"\s+(?:and then|then)\s+"#, with: ",", options: .regularExpression)

      var parts = normalized
         .split(separator: ",")
         .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
         .filter { !$0.isEmpty }

      if parts.count == 1 {
         parts = normalized
            .components(separatedBy: " and ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
      }

      return normalizedUniqueStrings(parts, limit: 12)
   }

   private static func isCountOnlySubtaskDescription(_ content: String) -> Bool {
      containsPhrase(#"^(?:\d+|one|two|three|four|five|six|seven|eight|nine|ten)(?:\s+(?:sub\s*tasks?|subtasks?|steps?|nanodos?|child\s+tasks?))?(?:\s+to\s+be\s+completed)?$"#, in: content.trimmingCharacters(in: .whitespacesAndNewlines))
   }

   private static func normalizedUniqueStrings(_ values: [String], limit: Int) -> [String] {
      var seen = Set<String>()
      return values.compactMap { value in
         let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
         guard !trimmed.isEmpty else { return nil }
         let key = trimmed.localizedLowercase
         guard seen.insert(key).inserted else { return nil }
         return trimmed
      }
      .prefix(limit)
      .map(\.self)
   }

   private static func positive(_ value: Int?) -> Int? {
      guard let value, value > 0 else { return nil }
      return value
   }

   private static func nonempty(_ value: String?) -> String? {
      guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmed.isEmpty
      else { return nil }
      return trimmed
   }

   private static func containsPhrase(_ pattern: String, in value: String) -> Bool {
      guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
         return false
      }
      let range = NSRange(value.startIndex..., in: value)
      return expression.firstMatch(in: value, range: range) != nil
   }

   private static func replacingMatches(_ pattern: String, in value: String, with template: String) -> String {
      guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
         return value
      }
      let range = NSRange(value.startIndex..., in: value)
      return expression.stringByReplacingMatches(in: value, range: range, withTemplate: template)
   }
}
