import AppIntents
import Foundation
import MapKit

struct ToDoAppEntity: AppEntity, Identifiable {
   static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "toDō")
   static let defaultQuery = ToDoEntityQuery()

   let id: String

   @Property(title: "Title")
   var title: String

   @Property(title: "Due Date")
   var dueDate: Date?

   var displayRepresentation: DisplayRepresentation {
      if let dueDate {
         DisplayRepresentation(
            title: "\(title)",
            subtitle: "Due \(dueDate.formatted(date: .abbreviated, time: .shortened))"
         )
      } else {
         DisplayRepresentation(title: "\(title)")
      }
   }
}

struct ToDoEntityQuery: EntityStringQuery {
   @Dependency private var repository: ToDoIntentRepository

   @MainActor
   func entities(for identifiers: [ToDoAppEntity.ID]) async throws -> [ToDoAppEntity] {
      try repository.toDos(identifiedBy: Set(identifiers)).map(ToDoAppEntity.init(snapshot:))
   }

   @MainActor
   func entities(matching string: String) async throws -> [ToDoAppEntity] {
      try repository.allToDos(matching: string).map(ToDoAppEntity.init(snapshot:))
   }

   @MainActor
   func suggestedEntities() async throws -> [ToDoAppEntity] {
      try repository.activeToDos().map(ToDoAppEntity.init(snapshot:))
   }
}

private extension ToDoAppEntity {
   init(snapshot: ToDoIntentSnapshot) {
      id = snapshot.identifier
      title = snapshot.title
      dueDate = snapshot.dueDate
   }
}

struct CreateToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "Create toDō"
   static let description = IntentDescription("Create a new toDō with an optional due date and reminder priority.")

   @Dependency private var repository: ToDoIntentRepository

   @Parameter(title: "Title", description: "What needs to be done?")
   var title: String

   @Parameter(title: "Due Date")
   var dueDate: Date?

   @Parameter(title: "Time-Sensitive", default: false)
   var isTimeSensitive: Bool

   @Parameter(title: "Notes", default: "")
   var notes: String

   @Parameter(title: "Reminder")
   var reminder: ToDoReminderOption?

   @Parameter(title: "Tags")
   var tags: [String]

   @Parameter(title: "NanoDos")
   var nanoDos: [String]

   @Parameter(title: "Repeat every")
   var recurrenceUnit: ToDoRecurrenceUnitOption?

   @Parameter(title: "Repeat interval", default: 1)
   var recurrenceInterval: Int

   @Parameter(title: "Repeat mode")
   var recurrenceMode: ToDoRecurrenceModeOption?

   @Parameter(title: "Repeat count")
   var recurrenceCount: Int?

   @Parameter(title: "Location")
   var locationName: String?

   @Parameter(title: "Location trigger")
   var locationTrigger: ToDoLocationTriggerOption?

   static var parameterSummary: some ParameterSummary {
      Summary("Create \(\.$title)") {
         \.$dueDate
         \.$isTimeSensitive
      }
   }

   init() {
      title = ""
      dueDate = nil
      isTimeSensitive = false
      notes = ""
      reminder = nil
      tags = []
      nanoDos = []
      recurrenceUnit = nil
      recurrenceInterval = 1
      recurrenceMode = nil
      recurrenceCount = nil
      locationName = nil
      locationTrigger = nil
   }

   init(
      title: String,
      dueDate: Date? = nil,
      isTimeSensitive: Bool = false,
      notes: String = "",
      reminder: ToDoReminderOption? = nil,
      tags: [String] = [],
      nanoDos: [String] = [],
      recurrenceUnit: ToDoRecurrenceUnitOption? = nil,
      recurrenceInterval: Int = 1,
      recurrenceMode: ToDoRecurrenceModeOption? = nil,
      recurrenceCount: Int? = nil,
      locationName: String? = nil,
      locationTrigger: ToDoLocationTriggerOption? = nil
   ) {
      self.title = title
      self.dueDate = dueDate
      self.isTimeSensitive = isTimeSensitive
      self.notes = notes
      self.reminder = reminder
      self.tags = tags
      self.nanoDos = nanoDos
      self.recurrenceUnit = recurrenceUnit
      self.recurrenceInterval = recurrenceInterval
      self.recurrenceMode = recurrenceMode
      self.recurrenceCount = recurrenceCount
      self.locationName = locationName
      self.locationTrigger = locationTrigger
   }

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
      let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedTitle.isEmpty else {
         throw $title.needsValueError("What should this toDō be called?")
      }

      let resolvedLocation = try await resolveLocation()
      let created = try await repository.create(
         title: trimmedTitle,
         dueDate: dueDate,
         isTimeSensitive: isTimeSensitive,
         notes: notes,
         reminderIntent: reminder?.intentValue,
         tagNames: tags,
         nanoDoTitles: nanoDos,
         recurrenceUnit: recurrenceUnit?.intentValue,
         recurrenceInterval: recurrenceUnit == nil ? nil : recurrenceInterval,
         recurrenceMode: recurrenceMode?.intentValue,
         recurrenceCount: recurrenceCount,
         location: resolvedLocation
      )
      let dialog = String(format: String(localized: "Created %@."), created.title)
      return .result(value: created.title, dialog: IntentDialog(stringLiteral: dialog))
   }

   @MainActor
   private func resolveLocation() async throws -> ToDoIntentLocation? {
      guard let locationName = locationName?.trimmingCharacters(in: .whitespacesAndNewlines),
            !locationName.isEmpty
      else { return nil }

      let request = MKLocalSearch.Request()
      request.naturalLanguageQuery = locationName
      request.resultTypes = [.address, .pointOfInterest]
      let response = try await MKLocalSearch(request: request).start()
      guard let item = response.mapItems.first else {
         throw $locationName.needsValueError("I couldn’t find that location. Which place should I use?")
      }
      return ToDoIntentLocation(
         latitude: item.location.coordinate.latitude,
         longitude: item.location.coordinate.longitude,
         label: item.name ?? locationName,
         trigger: locationTrigger?.intentValue ?? .arriving
      )
   }
}

struct CreateToDoWithAppleIntelligenceIntent: AppIntent {
   static let title: LocalizedStringResource = "Create with Apple Intelligence"
   static let description = IntentDescription(
      "Describe a complete toDō naturally. The app organizes its details and asks a short follow-up only when needed."
   )

   @Dependency private var repository: ToDoIntentRepository

   @Parameter(
      title: "Request",
      description: "Describe the toDō, including any due date, reminder, recurrence, tags, NanoDos, notes, or location."
   )
   var request: String

   @Parameter(title: "Clarification")
   var clarification: String?

   @Parameter(title: "Location")
   var locationName: String?

   static var parameterSummary: some ParameterSummary {
      Summary("Organize \(\.$request) in toDō")
   }

   init() {
      request = ""
      clarification = nil
      locationName = nil
   }

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
      let trimmedRequest = request.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedRequest.isEmpty else {
         throw $request.needsValueError("What would you like to get done?")
      }

      guard UserDefaults.standard.bool(forKey: AppPreferences.Keys.appleIntelligenceEnabled) else {
         return .result(
            value: "",
            dialog: "Turn on Apple Intelligence in toDō before using this action."
         )
      }
      guard AppleIntelligenceService.isAvailable else {
         return .result(
            value: "",
            dialog: "Apple Intelligence is not available on this device, language, or region yet."
         )
      }

      var completeRequest = trimmedRequest
      guard var draft = await AppleIntelligenceService.parseSpokenToDo(
         completeRequest,
         isEnabled: true
      ) else {
         return .result(
            value: "",
            dialog: "I couldn’t organize that into a toDō. Nothing was saved."
         )
      }

      if let question = draft.clarificationQuestion {
         let answer = try await $clarification.requestValue(IntentDialog(stringLiteral: question))
         let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
         guard !trimmedAnswer.isEmpty else {
            return .result(value: "", dialog: "Nothing was saved.")
         }

         completeRequest += "\nClarification: \(trimmedAnswer)"
         guard let clarifiedDraft = await AppleIntelligenceService.parseSpokenToDo(
            completeRequest,
            isEnabled: true
         ) else {
            return .result(
               value: "",
               dialog: "I couldn’t apply that answer. Nothing was saved."
            )
         }
         draft = clarifiedDraft

         if let unresolvedQuestion = draft.clarificationQuestion {
            return .result(
               value: "",
               dialog: IntentDialog(stringLiteral: unresolvedClarificationMessage(for: unresolvedQuestion))
            )
         }
      }

      draft = draft.applyingDefaultDueTime(for: completeRequest)
      let resolvedLocation = try await resolveLocation(for: draft)
      try await requestConfirmation(
         conditions: [],
         actionName: .continue,
         dialog: IntentDialog(stringLiteral: confirmationSummary(for: draft))
      )

      let created = try await repository.create(draft: draft, location: resolvedLocation)
      let dialog = String(format: String(localized: "Created %@."), created.title)
      return .result(value: created.title, dialog: IntentDialog(stringLiteral: dialog))
   }

   @MainActor
   private func resolveLocation(for draft: AppleIntelligenceToDoDraft) async throws -> ToDoIntentLocation? {
      guard let requestedLabel = draft.locationLabel else { return nil }

      let resolvedName: String
      if let locationName = nonempty(locationName) {
         resolvedName = locationName
      } else {
         resolvedName = try await $locationName.requestValue(
            IntentDialog(stringLiteral: "Which location should I use for \(requestedLabel)?")
         )
      }
      guard let place = try await resolvePlace(named: resolvedName) else {
         throw $locationName.needsValueError(
            IntentDialog(stringLiteral: "I couldn’t find that location. Which place should I use?")
         )
      }

      return ToDoIntentLocation(
         latitude: place.coordinate.latitude,
         longitude: place.coordinate.longitude,
         label: place.label,
         trigger: draft.locationTrigger ?? .arriving
      )
   }

   @MainActor
   private func resolvePlace(named name: String) async throws -> (label: String, coordinate: CLLocationCoordinate2D)? {
      let query = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !query.isEmpty else { return nil }

      let request = MKLocalSearch.Request()
      request.naturalLanguageQuery = query
      request.resultTypes = [.address, .pointOfInterest]
      let response = try await MKLocalSearch(request: request).start()
      guard let item = response.mapItems.first else { return nil }
      return (item.name ?? query, item.location.coordinate)
   }

   private func nonempty(_ value: String?) -> String? {
      guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
      else { return nil }
      return value
   }

   private func confirmationSummary(for draft: AppleIntelligenceToDoDraft) -> String {
      var details: [String] = [draft.title]
      if let dueDate = draft.dueDate {
         details.append(
            String(
               format: String(localized: "due %@"),
               dueDate.formatted(date: .abbreviated, time: .shortened)
            )
         )
      }
      if !draft.nanoDoTitles.isEmpty {
         details.append(
            AppLocalization.localizedCount(
               draft.nanoDoTitles.count,
               singularKey: "%@ NanoDo",
               pluralKey: "%@ NanoDos"
            )
         )
      }
      if !draft.tagNames.isEmpty {
         details.append(
            AppLocalization.localizedCount(
               draft.tagNames.count,
               singularKey: "%@ tag",
               pluralKey: "%@ tags"
            )
         )
      }
      return String(
         format: String(localized: "Create this toDō: %@?"),
         details.joined(separator: ", ")
      )
   }

   private func unresolvedClarificationMessage(for question: String) -> String {
      String(
         format: String(localized: "I still need one detail before I can create this toDō: %@ Nothing was saved."),
         question
      )
   }
}

struct CompleteToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "Complete toDō"
   static let description = IntentDescription("Mark an active toDō as done.")

   @Dependency private var repository: ToDoIntentRepository

   @Parameter(title: "toDō")
   var toDo: ToDoAppEntity

   static var parameterSummary: some ParameterSummary {
      Summary("Complete \(\.$toDo)")
   }

   init() {}

   init(toDo: ToDoAppEntity) {
      self.toDo = toDo
   }

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog {
      guard let completed = try await repository.complete(identifier: toDo.id) else {
         return .result(dialog: "That toDō could not be found.")
      }

      let dialog = String(format: String(localized: "Completed %@."), completed.title)
      return .result(dialog: IntentDialog(stringLiteral: dialog))
   }
}

enum ToDoReminderOption: String, AppEnum, CaseIterable {
   case quiet
   case due
   case timeSensitive

   static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Reminder")
   static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .quiet: "Quiet",
      .due: "Due",
      .timeSensitive: "Time-Sensitive"
   ]

   var intentValue: ToDoReminderIntent {
      switch self {
      case .quiet: return .soft
      case .due: return .due
      case .timeSensitive: return .timeSensitive
      }
   }
}

enum ToDoRecurrenceUnitOption: String, AppEnum, CaseIterable {
   case seconds
   case minutes
   case hours
   case days
   case weeks
   case months
   case years

   static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Repeat unit")
   static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .seconds: "Seconds",
      .minutes: "Minutes",
      .hours: "Hours",
      .days: "Days",
      .weeks: "Weeks",
      .months: "Months",
      .years: "Years"
   ]

   var intentValue: ToDoRecurrenceUnit {
      ToDoRecurrenceUnit(rawValue: rawValue) ?? .days
   }
}

enum ToDoRecurrenceModeOption: String, AppEnum, CaseIterable {
   case finite
   case continuous

   static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Repeat mode")
   static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .finite: "Fixed Count",
      .continuous: "Continuous"
   ]

   var intentValue: ToDoRecurrenceMode {
      ToDoRecurrenceMode(rawValue: rawValue) ?? .continuous
   }
}

enum ToDoLocationTriggerOption: String, AppEnum, CaseIterable {
   case arriving
   case leaving

   static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Location trigger")
   static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
      .arriving: "Arriving",
      .leaving: "Leaving"
   ]

   var intentValue: ToDoLocationReminderTrigger {
      ToDoLocationReminderTrigger(rawValue: rawValue) ?? .arriving
   }
}

struct ListToDosIntent: AppIntent {
   static let title: LocalizedStringResource = "List toDōs"
   static let description = IntentDescription("Read the toDōs currently available in your list.")

   @Dependency private var repository: ToDoIntentRepository

   @Parameter(title: "Search", default: "")
   var searchText: String

   @Parameter(title: "Include completed", default: false)
   var includeCompleted: Bool

   init() {
      searchText = ""
      includeCompleted = false
   }

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog {
      let dialog = try repository.listDialog(
         searchText: searchText,
         includeCompleted: includeCompleted
      )
      return .result(dialog: IntentDialog(stringLiteral: dialog))
   }
}

struct ReadToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "Read a toDō"
   static let description = IntentDescription("Read the details of a selected toDō.")

   @Dependency private var repository: ToDoIntentRepository

   @Parameter(title: "toDō")
   var toDo: ToDoAppEntity

   init() {}

   init(toDo: ToDoAppEntity) {
      self.toDo = toDo
   }

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog {
      guard let details = try repository.details(identifier: toDo.id) else {
         return .result(dialog: "That toDō could not be found.")
      }
      return .result(dialog: IntentDialog(stringLiteral: details))
   }
}

struct UpdateToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "Update a toDō"
   static let description = IntentDescription("Update a toDō and any of its supported details.")

   @Dependency private var repository: ToDoIntentRepository

   @Parameter(title: "toDō")
   var toDo: ToDoAppEntity

   @Parameter(title: "Title")
   var title: String?

   @Parameter(title: "Notes")
   var notes: String?

   @Parameter(title: "Due Date")
   var dueDate: Date?

   @Parameter(title: "Clear due date", default: false)
   var clearDueDate: Bool

   @Parameter(title: "Reminder")
   var reminder: ToDoReminderOption?

   @Parameter(title: "Tags")
   var tags: [String]

   @Parameter(title: "Replace tags", default: false)
   var replaceTags: Bool

   @Parameter(title: "NanoDos")
   var nanoDos: [String]

   @Parameter(title: "Replace NanoDos", default: false)
   var replaceNanoDos: Bool

   @Parameter(title: "Clear repeat", default: false)
   var clearRecurrence: Bool

   @Parameter(title: "Repeat every")
   var recurrenceUnit: ToDoRecurrenceUnitOption?

   @Parameter(title: "Repeat interval")
   var recurrenceInterval: Int?

   @Parameter(title: "Repeat mode")
   var recurrenceMode: ToDoRecurrenceModeOption?

   @Parameter(title: "Repeat count")
   var recurrenceCount: Int?

   @Parameter(title: "Location")
   var locationName: String?

   @Parameter(title: "Location trigger")
   var locationTrigger: ToDoLocationTriggerOption?

   @Parameter(title: "Clear location", default: false)
   var clearLocation: Bool

   init() {
      title = nil
      notes = nil
      dueDate = nil
      clearDueDate = false
      reminder = nil
      tags = []
      replaceTags = false
      nanoDos = []
      replaceNanoDos = false
      clearRecurrence = false
      recurrenceUnit = nil
      recurrenceInterval = nil
      recurrenceMode = nil
      recurrenceCount = nil
      locationName = nil
      locationTrigger = nil
      clearLocation = false
   }

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog {
      let updatedTags: [String]? = tags.isEmpty && !replaceTags ? nil : tags

      let updatedNanoDos: [String]? = replaceNanoDos ? nanoDos : nil
      guard let updated = try await repository.update(
         identifier: toDo.id,
         title: title,
         notes: notes,
         dueDate: dueDate,
         clearDueDate: clearDueDate,
         reminderIntent: reminder?.intentValue,
         tags: updatedTags,
         replaceTags: replaceTags,
         nanoDoTitles: updatedNanoDos,
         replaceNanoDos: replaceNanoDos,
         clearRecurrence: clearRecurrence,
         recurrenceUnit: recurrenceUnit?.intentValue,
         recurrenceInterval: recurrenceInterval,
         recurrenceMode: recurrenceMode?.intentValue,
         recurrenceCount: recurrenceCount,
         location: try await resolveLocation(),
         clearLocation: clearLocation
      ) else {
         return .result(dialog: "That toDō could not be found.")
      }

      let dialog = String(format: String(localized: "Updated %@."), updated.title)
      return .result(dialog: IntentDialog(stringLiteral: dialog))
   }

   @MainActor
   private func resolveLocation() async throws -> ToDoIntentLocation? {
      guard let locationName = locationName?.trimmingCharacters(in: .whitespacesAndNewlines),
            !locationName.isEmpty
      else { return nil }

      let request = MKLocalSearch.Request()
      request.naturalLanguageQuery = locationName
      request.resultTypes = [.address, .pointOfInterest]
      let response = try await MKLocalSearch(request: request).start()
      guard let item = response.mapItems.first else {
         throw $locationName.needsValueError("I couldn’t find that location. Which place should I use?")
      }
      return ToDoIntentLocation(
         latitude: item.location.coordinate.latitude,
         longitude: item.location.coordinate.longitude,
         label: item.name ?? locationName,
         trigger: locationTrigger?.intentValue ?? .arriving
      )
   }
}

struct ArchiveToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "Archive toDō"
   static let description = IntentDescription("Move a toDō out of the active list and into Archives.")
   @Dependency private var repository: ToDoIntentRepository
   @Parameter(title: "toDō") var toDo: ToDoAppEntity

   init() {}
   init(toDo: ToDoAppEntity) { self.toDo = toDo }

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog {
      guard let archived = try await repository.archive(identifier: toDo.id) else {
         return .result(dialog: "That toDō could not be found.")
      }
      return .result(dialog: IntentDialog(stringLiteral: String(format: String(localized: "Archived %@."), archived.title)))
   }
}

struct TrashToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "Trash toDō"
   static let description = IntentDescription("Move a toDō to Trash without permanently deleting it.")
   @Dependency private var repository: ToDoIntentRepository
   @Parameter(title: "toDō") var toDo: ToDoAppEntity

   init() {}
   init(toDo: ToDoAppEntity) { self.toDo = toDo }

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog {
      guard let trashed = try await repository.trash(identifier: toDo.id) else {
         return .result(dialog: "That toDō could not be found.")
      }
      return .result(dialog: IntentDialog(stringLiteral: String(format: String(localized: "Moved %@ to Trash."), trashed.title)))
   }
}

struct RestoreToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "Restore toDō"
   static let description = IntentDescription("Restore a toDō from Archives or Trash to the active list.")
   @Dependency private var repository: ToDoIntentRepository
   @Parameter(title: "toDō") var toDo: ToDoAppEntity

   init() {}
   init(toDo: ToDoAppEntity) { self.toDo = toDo }

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog {
      guard let restored = try await repository.restore(identifier: toDo.id) else {
         return .result(dialog: "That toDō could not be found.")
      }
      return .result(dialog: IntentDialog(stringLiteral: String(format: String(localized: "Restored %@."), restored.title)))
   }
}

struct DeleteToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "Delete toDō"
   static let description = IntentDescription("Permanently delete a toDō from this account.")
   @Dependency private var repository: ToDoIntentRepository
   @Parameter(title: "toDō") var toDo: ToDoAppEntity

   init() {}
   init(toDo: ToDoAppEntity) { self.toDo = toDo }

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog {
      try await requestConfirmation(
         conditions: [],
         actionName: .continue,
         dialog: "Permanently delete this toDō?"
      )
      guard try await repository.delete(identifier: toDo.id) else {
         return .result(dialog: "That toDō could not be found.")
      }
      return .result(dialog: "toDō deleted.")
   }
}

struct OpenToDoIntent: AppIntent {
   static let title: LocalizedStringResource = "Open toDō"
   static let description = IntentDescription("Open toDō and review the full list.")
   static var supportedModes: IntentModes { .foreground(.immediate) }

   @MainActor
   func perform() async throws -> some IntentResult & ProvidesDialog {
      NavigationCoordinator.shared.listRoute = .all
      return .result(dialog: "Opening toDō.")
   }
}

struct ToDoShortcutsProvider: AppShortcutsProvider {
   static var shortcutTileColor: ShortcutTileColor { .yellow }

   static var negativePhrases: NegativeAppShortcutPhrases {
      NegativeAppShortcutPhrases(phrases: [
         "Create a to do",
         "Add a reminder",
         "Remind me"
      ])
   }

   static var appShortcuts: [AppShortcut] {
      AppShortcut(
         intent: CreateToDoIntent(),
         phrases: [
            "Create a toDō using \(.applicationName)",
            "Add a new toDō using \(.applicationName)",
            "Let's create a new toDō using \(.applicationName)"
         ],
         shortTitle: "Create toDō",
         systemImageName: "plus.circle.fill"
      )

      AppShortcut(
         intent: CreateToDoWithAppleIntelligenceIntent(),
         phrases: [
            "Create a \(.applicationName)",
            "I want \(.applicationName) something",
            "Enter a \(.applicationName)"
         ],
         shortTitle: "Create with Apple Intelligence",
         systemImageName: "apple.intelligence"
      )

      AppShortcut(
         intent: CompleteToDoIntent(),
         phrases: [
            "Finish \(\.$toDo) in \(.applicationName)",
            "Complete \(\.$toDo) inside \(.applicationName)"
         ],
         shortTitle: "Complete toDō",
         systemImageName: "checkmark.circle.fill"
      )

      AppShortcut(
         intent: ListToDosIntent(),
         phrases: [
            "List my toDōs in \(.applicationName)",
            "Read my toDō list in \(.applicationName)"
         ],
         shortTitle: "List toDōs",
         systemImageName: "list.bullet"
      )

      AppShortcut(
         intent: ReadToDoIntent(),
         phrases: [
            "Read \(\.$toDo) in \(.applicationName)",
            "Show details for \(\.$toDo) in \(.applicationName)"
         ],
         shortTitle: "Read toDō",
         systemImageName: "doc.text.magnifyingglass"
      )

      AppShortcut(
         intent: UpdateToDoIntent(),
         phrases: [
            "Update \(\.$toDo) in \(.applicationName)",
            "Change \(\.$toDo) in \(.applicationName)"
         ],
         shortTitle: "Update toDō",
         systemImageName: "pencil"
      )

      AppShortcut(
         intent: ArchiveToDoIntent(),
         phrases: ["Archive \(\.$toDo) in \(.applicationName)"],
         shortTitle: "Archive toDō",
         systemImageName: "archivebox.fill"
      )

      AppShortcut(
         intent: TrashToDoIntent(),
         phrases: ["Trash \(\.$toDo) in \(.applicationName)"],
         shortTitle: "Trash toDō",
         systemImageName: "trash.fill"
      )

      AppShortcut(
         intent: RestoreToDoIntent(),
         phrases: ["Restore \(\.$toDo) in \(.applicationName)"],
         shortTitle: "Restore toDō",
         systemImageName: "arrow.uturn.backward"
      )

      AppShortcut(
         intent: DeleteToDoIntent(),
         phrases: ["Delete \(\.$toDo) in \(.applicationName)"],
         shortTitle: "Delete toDō",
         systemImageName: "trash"
      )

   }
}
