import SwiftUI
import WatchKit

enum WatchLocalization {
   static var displayLocale: Locale {
      let identifier = Locale.preferredLanguages.first ?? Locale.current.identifier
      if identifier.hasPrefix("ar") {
         return Locale(identifier: "ar_SA@numbers=arab")
      }
      if identifier.hasPrefix("ur") {
         return Locale(identifier: "ur_PK@numbers=arabext")
      }
      if identifier.hasPrefix("hi") {
         return Locale(identifier: "hi_IN@numbers=deva")
      }
      if identifier.hasPrefix("th") {
         return Locale(identifier: "th_TH@numbers=thai")
      }
      return Locale(identifier: identifier)
   }

   static func dateTimeString(_ date: Date) -> String {
      formatted(date, dateStyle: .medium, timeStyle: .short)
   }

   static func dateString(_ date: Date) -> String {
      formatted(date, dateStyle: .medium, timeStyle: .none)
   }

   static func monthDayString(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.locale = displayLocale
      formatter.calendar = displayCalendar
      formatter.setLocalizedDateFormatFromTemplate("MMMd")
      return formatter.string(from: date)
   }

   static func timeString(_ date: Date) -> String {
      formatted(date, dateStyle: .none, timeStyle: .short)
   }

   static func numberString(_ number: Int) -> String {
      let formatter = NumberFormatter()
      formatter.locale = displayLocale
      formatter.numberStyle = .none
      return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
   }

   static func localizedCount(_ count: Int, singularKey: String, pluralKey: String) -> String {
      String(
         format: String(localized: String.LocalizationValue(count == 1 ? singularKey : pluralKey)),
         numberString(count)
      )
   }

   private static var displayCalendar: Calendar {
      let identifier = Locale.preferredLanguages.first ?? Locale.current.identifier
      var calendar = Calendar(identifier: identifier.hasPrefix("ar") ? .islamicUmmAlQura : .gregorian)
      calendar.locale = displayLocale
      calendar.timeZone = .current
      return calendar
   }

   private static func formatted(_ date: Date, dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
      let formatter = DateFormatter()
      formatter.locale = displayLocale
      formatter.calendar = displayCalendar
      formatter.dateStyle = dateStyle
      formatter.timeStyle = timeStyle
      return formatter.string(from: date)
   }
}

struct WatchAccountView: View {
   @ObservedObject var authStore: WatchAuthStore
   @ObservedObject var store: WatchToDoStore
   let openDoneToDos: () -> Void

   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 12) {
            WatchScreenHeader(
               title: "Settings",
               systemImage: "gearshape.fill",
               accent: WatchAppColor.main
            )

            syncStatusCard
            accountCard
            settingsCard
            doneToDosCard
            watchBrandFooter
         }
         .padding(.horizontal, 2)
         .padding(.bottom, 12)
      }
	      .toolbarBackground(.hidden, for: .navigationBar)
	      .background(WatchAppColor.surface)
	      .tint(WatchAppColor.actionPrimary)
	      .accessibilityIdentifier("watch.todo.create")
	   }

   private var accountCard: some View {
      WatchCard(spacing: 8) {
         WatchMetadataRow(
            systemImage: authStore.authState.isAuthenticated ? "person.crop.circle.badge.checkmark" : "icloud.slash",
            title: "Account",
            value: authStore.authState.detail,
            accent: authStore.authState.isAuthenticated ? WatchAppColor.actionSuccess : WatchAppColor.main
         )

         if let errorMessage = authStore.errorMessage {
            Text(errorMessage)
               .font(.watchBody(11, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.destructive)
         }
      }
   }

   private var syncStatusCard: some View {
      WatchCard(spacing: 8) {
         WatchMetadataRow(
            systemImage: "arrow.clockwise.icloud",
            title: "Updated",
            value: updatedText,
            accent: statusColor
         )

         if store.queuedActionCount > 0 {
            WatchMetadataRow(
               systemImage: "tray.and.arrow.up.fill",
               title: "Queued",
               value: String(format: String(localized: "%@ pending"), WatchLocalization.numberString(store.queuedActionCount)),
               accent: WatchAppColor.main
            )
         }

         Button {
            store.requestRefresh()
         } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
         }
         .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.actionPrimary))
      }
   }

   private var settingsCard: some View {
      WatchActionGroup(title: "Notifications", systemImage: "bell.badge", accent: WatchAppColor.secondary) {
         WatchMetadataRow(
            systemImage: "bell.badge",
            title: "Alerts",
            value: String(localized: "Uses your iPhone and Watch notification settings"),
            accent: WatchAppColor.secondary
         )

         NavigationLink {
            WatchSnoozeOptionsView()
         } label: {
            Label("Snooze", systemImage: "zzz")
         }
         .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.secondary))
      }
   }

   private var doneToDosCard: some View {
      WatchActionGroup(title: "History", systemImage: "clock.arrow.circlepath", accent: WatchAppColor.actionSuccess) {
         Button(action: openDoneToDos) {
            Label(doneToDosLabel, systemImage: "tray.full")
         }
         .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.actionSuccess))
      }
   }

   private var doneToDosLabel: String {
      let count = store.doneItems.count
      return WatchLocalization.localizedCount(count, singularKey: "%@ done toDō", pluralKey: "%@ done toDōs")
   }

   private var watchBrandFooter: some View {
      VStack(spacing: 10) {
         Text("\(Text("toDō").foregroundStyle(WatchAppColor.main).bold()) \(Text(String(localized: "what matters")))")
            .font(.watchAccent(13, relativeTo: .caption))
            .foregroundStyle(WatchAppColor.textPrimary)
            .multilineTextAlignment(.center)

         Link(destination: URL(string: "https://yourtodo.today")!) {
            Text("yourtodo.today")
               .font(.watchBodyStrong(11, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.secondary)
         }
         .buttonStyle(.plain)

         watchBrandWordmark

         Link(destination: URL(string: "https://iamshift.dev")!) {
            Image("brand-logomark")
               .resizable()
               .scaledToFit()
               .frame(width: 42, height: 42)
         }
         .buttonStyle(.plain)
      }
      .frame(maxWidth: .infinity)
      .padding(.top, 8)
      .padding(.bottom, 4)
   }

   private var watchBrandWordmark: some View {
      HStack(spacing: 0) {
         Text("mo")
            .font(watchBrandWordmarkFont)
         Text("i").italic()
            .font(watchBrandWordmarkItalicFont)
         Text("n.")
            .font(watchBrandWordmarkFont)
         Text("sh").italic()
            .font(watchBrandWordmarkItalicFont)
         Text("i")
            .font(watchBrandWordmarkFont)
         Text("ft()").italic()
            .font(watchBrandWordmarkItalicFont)
      }
      .foregroundStyle(WatchAppColor.textPrimary)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("moin.shift()")
   }

   private var watchBrandWordmarkFont: Font {
      .custom("Aleo", size: 15, relativeTo: .caption)
         .weight(.medium)
   }

   private var watchBrandWordmarkItalicFont: Font {
      .custom("Aleo", size: 15, relativeTo: .caption)
         .weight(.regular)
         .italic()
   }

   private var updatedText: String {
      if store.queuedActionCount > 0 {
         return String(localized: "Queued")
      }

      if let lastUpdated = store.lastUpdated {
         return WatchLocalization.timeString(lastUpdated)
      }

      return String(localized: String.LocalizationValue(store.statusText))
   }

   private var statusColor: Color {
      switch store.statusText {
      case "Updated", "Saved", "Connected", "Account Ready":
         return WatchAppColor.actionSuccess
      case "Sending", "Syncing":
         return WatchAppColor.main
      case "Queued":
         return WatchAppColor.secondary
      default:
         return WatchAppColor.textSecondary
      }
   }
}

struct WatchDoneToDosView: View {
   @ObservedObject var store: WatchToDoStore

   private var doneItems: [WatchToDoItem] {
      store.doneItems
   }

   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 12) {
            WatchScreenHeader(
               title: "Done",
               systemImage: "tray.full",
               accent: WatchAppColor.actionSuccess
            )

            if doneItems.isEmpty {
               WatchCard(spacing: 8) {
                  Image(systemName: "tray")
                     .font(.watchDisplay(22, relativeTo: .title3))
                     .foregroundStyle(WatchAppColor.textSecondary)

                  Text("No done toDōs yet.")
                     .font(.watchBodyStrong(13, relativeTo: .caption))
                     .foregroundStyle(WatchAppColor.textPrimary)
               }
            } else {
               WatchCard(spacing: 7) {
                  ForEach(doneItems) { item in
                     NavigationLink(value: WatchRoute.toDoDetail(item.id)) {
                        WatchToDoRow(item: item, accent: WatchAppColor.actionSuccess)
                     }
                     .buttonStyle(.plain)
                  }
               }
            }
         }
         .padding(.horizontal, 2)
         .padding(.bottom, 12)
      }
      .navigationTitle("Done")
      .toolbarBackground(.hidden, for: .navigationBar)
      .background(WatchAppColor.surface)
      .tint(WatchAppColor.actionPrimary)
   }
}

struct WatchSnoozeOptionsView: View {
   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 12) {
            WatchScreenHeader(
               title: "Snooze Options",
               systemImage: "zzz",
               accent: WatchAppColor.secondary
            )

            ForEach(WatchSnoozeUnit.allCases) { unit in
               WatchActionGroup(title: unit.title, systemImage: "clock", accent: WatchAppColor.secondary) {
                  ForEach(Array(unit.values.enumerated()), id: \.offset) { _, value in
                     WatchMetadataRow(
                        systemImage: "timer",
                        title: unit.label(for: value),
                        value: String(localized: "Available from any due toDō"),
                        accent: WatchAppColor.secondary
                     )
                  }
               }
            }
         }
         .padding(.horizontal, 2)
         .padding(.bottom, 12)
      }
      .navigationTitle("Snooze Options")
      .toolbarBackground(.hidden, for: .navigationBar)
      .background(WatchAppColor.surface)
      .tint(WatchAppColor.actionPrimary)
   }
}

struct ToDoSection: View {
   let title: String
   let items: [WatchToDoItem]
   let accent: Color
   let systemImage: String
   @ObservedObject var store: WatchToDoStore

   var body: some View {
      if !items.isEmpty {
         VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
               Image(systemName: systemImage)
                  .font(.watchBodyStrong(10, relativeTo: .caption2))
                  .foregroundStyle(accent)

               Text(LocalizedStringKey(title))
                  .font(.watchDisplay(18, relativeTo: .headline))
                  .foregroundStyle(WatchAppColor.textPrimary)

               Text(WatchLocalization.numberString(items.count))
                  .font(.watchBodyStrong(10, relativeTo: .caption2))
                  .foregroundStyle(WatchAppColor.textSecondary)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(WatchAppColor.surfaceMuted, in: Capsule())
            }
            .padding(.horizontal, 4)

            ForEach(items) { item in
               NavigationLink(value: WatchRoute.toDoDetail(item.id)) {
                  WatchToDoRow(item: item, accent: accent)
               }
               .buttonStyle(.plain)
            }
         }
         .padding(.top, 3)
      }
   }
}

struct CaptureToDoView: View {
   @ObservedObject var store: WatchToDoStore
   var onCreated: (() -> Void)?
   @Environment(\.dismiss) private var dismiss
   @State private var task = ""
   @State private var dueDate: Date?
   @State private var isTimeSensitive = false

   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 12) {
            WatchScreenHeader(
               title: "New toDō",
               systemImage: "plus",
               accent: WatchAppColor.actionPrimary
            )

            ZStack(alignment: .topTrailing) {
               WatchCard {
                  TextField("what toDō today?", text: $task, axis: .vertical)
                     .font(.watchUserEntry(17, relativeTo: .headline))
                     .foregroundStyle(WatchAppColor.textPrimary)
                     .lineLimit(1...4)
                     .textInputAutocapitalization(.sentences)
               }

               Button {
                  extractDetailsFromTask()
               } label: {
                  Image(systemName: "mic.fill")
               }
               .buttonStyle(WatchCompactIconButtonStyle(
                  fill: WatchAppColor.actionPrimary,
                  size: 32,
                  minHeight: 32,
                  symbolSize: 15,
                  cornerRadius: 16
               ))
               .accessibilityLabel("Extract from text")
               .offset(x: -6, y: -8)
            }

            WatchCard(spacing: 12) {
               WatchScheduleSummary(dueDate: dueDate)

               if dueDate == nil {
                  Button {
                     dueDate = date(atHour: defaultTodayHour, minute: 0, on: Date())
                  } label: {
                     WatchScheduleWideAction(
                        title: "Add Due Date",
                        systemImage: "calendar",
                        accent: WatchAppColor.actionPrimary
                     )
                  }
                  .buttonStyle(.plain)
               } else {
                  HStack(spacing: 8) {
                     NavigationLink {
                        WatchDateSelectionView(
                           title: "Due Date",
                           selection: Binding(
                              get: { dueDate ?? defaultDateForNewSelection() },
                              set: { dueDate = merge(date: $0, withTimeFrom: dueDate) }
                           )
                        )
                     } label: {
                        WatchScheduleTile(
                           title: "Date",
                           value: dueDate.map(WatchLocalization.monthDayString) ?? "",
                           systemImage: "calendar",
                           accent: WatchAppColor.actionPrimary
                        )
                     }
                     .buttonStyle(.plain)

                     NavigationLink {
                        WatchTimeSelectionView(
                           title: "Due Time",
                           selection: Binding(
                              get: { dueDate ?? defaultDateForNewSelection() },
                              set: { dueDate = merge(time: $0, withDateFrom: dueDate) }
                           )
                        )
                     } label: {
                        WatchScheduleTile(
                           title: "Time",
                           value: dueDate.map(WatchLocalization.timeString) ?? "",
                           systemImage: "clock",
                           accent: WatchAppColor.secondary
                        )
                     }
                     .buttonStyle(.plain)
                  }
               }

               VStack(alignment: .leading, spacing: 7) {
                  Text("Quick Picks")
                     .font(.watchBodyStrong(10, relativeTo: .caption2))
                     .foregroundStyle(WatchAppColor.textSecondary)
                     .padding(.horizontal, 2)

                  HStack(spacing: 8) {
                     Button {
                        setQuickDue(.today)
                     } label: {
                        WatchSchedulePill(title: "Today", value: formattedDefaultTodayTime, accent: WatchAppColor.actionPrimary)
                     }
                     .buttonStyle(.plain)

                     Button {
                        setQuickDue(.tomorrow)
                     } label: {
                        WatchSchedulePill(title: "Tomorrow", value: formattedDefaultTomorrowTime, accent: WatchAppColor.secondary)
                     }
                     .buttonStyle(.plain)
                  }

                  if dueDate != nil {
                     Button {
                        dueDate = nil
                        isTimeSensitive = false
                     } label: {
                        WatchScheduleWideAction(
                           title: "Clear Due Date",
                           systemImage: "xmark",
                           accent: WatchAppColor.textSecondary
                        )
                     }
                     .buttonStyle(.plain)
                  }
               }

               WatchScheduleToggleRow(
                  isOn: $isTimeSensitive,
                  dueDate: $dueDate,
                  defaultDueDate: { date(atHour: defaultTodayHour, minute: 0, on: Date()) }
               )
            }

            Button {
               store.create(task: task, dueDate: dueDate, isTimeSensitive: isTimeSensitive)
               onCreated?()
               dismiss()
            } label: {
               Label("Add toDō", systemImage: "plus")
                  .font(.watchButton(20, relativeTo: .title3))
            }
            .buttonStyle(WatchProminentButtonStyle())
            .frame(maxWidth: .infinity, alignment: .center)
            .disabled(task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
         }
         .padding(.horizontal, 2)
         .padding(.bottom, 12)
      }
      .navigationTitle("")
      .toolbar {
         ToolbarItem(placement: .cancellationAction) {
            Button {
               dismiss()
            } label: {
               WatchCloseIconButton()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel")
         }
      }
      .toolbarBackground(.hidden, for: .navigationBar)
      .background(WatchAppColor.surface)
      .tint(WatchAppColor.actionPrimary)
   }

   private enum QuickDue { case today, tomorrow }

   private var defaultTodayHour: Int { 17 }
   private var defaultTomorrowHour: Int { 9 }

   private func defaultDateForNewSelection() -> Date {
      Date()
   }

   private func date(atHour hour: Int, minute: Int, on baseDay: Date) -> Date {
      var comps = Calendar.current.dateComponents([.year, .month, .day], from: baseDay)
      comps.hour = hour
      comps.minute = minute
      comps.second = 0
      return Calendar.current.date(from: comps) ?? baseDay
   }

   private func merge(date newDay: Date, withTimeFrom base: Date?) -> Date {
      let cal = Calendar.current
      let baseTimeSource = base ?? date(atHour: defaultTodayHour, minute: 0, on: newDay)
      let time = cal.dateComponents([.hour, .minute, .second], from: baseTimeSource)
      var comps = cal.dateComponents([.year, .month, .day], from: newDay)
      comps.hour = time.hour
      comps.minute = time.minute
      comps.second = time.second
      return cal.date(from: comps) ?? newDay
   }

   private func merge(time newTime: Date, withDateFrom base: Date?) -> Date {
      let cal = Calendar.current
      let baseDay = base ?? newTime
      let time = cal.dateComponents([.hour, .minute, .second], from: newTime)
      var comps = cal.dateComponents([.year, .month, .day], from: baseDay)
      comps.hour = time.hour
      comps.minute = time.minute
      comps.second = time.second
      return cal.date(from: comps) ?? newTime
   }

   private var formattedDefaultTodayTime: String {
      WatchLocalization.timeString(date(atHour: defaultTodayHour, minute: 0, on: Date()))
   }

   private var formattedDefaultTomorrowTime: String {
      let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
      return WatchLocalization.timeString(date(atHour: defaultTomorrowHour, minute: 0, on: tomorrow))
   }

   private func setQuickDue(_ quick: QuickDue) {
      let cal = Calendar.current
      switch quick {
      case .today:
         let today = cal.startOfDay(for: Date())
         let defaultBase = date(atHour: defaultTodayHour, minute: 0, on: today)
         let baseTime = dueDate ?? defaultBase
         dueDate = merge(date: today, withTimeFrom: baseTime)
      case .tomorrow:
         let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
         let defaultBase = date(atHour: defaultTomorrowHour, minute: 0, on: tomorrow)
         let baseTime = dueDate ?? defaultBase
         dueDate = merge(date: tomorrow, withTimeFrom: baseTime)
      }
   }

   private func extractDetailsFromTask() {
      let input = task.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !input.isEmpty else { return }

      if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
         let ns = input as NSString
         let range = NSRange(location: 0, length: ns.length)
         if let match = detector.firstMatch(in: input, options: [], range: range),
            let matchDate = match.date {
            var resolved = matchDate
            let matchedText = ns.substring(with: match.range).lowercased()
            let hasTimeIndicators = matchedText.range(of: "(\\d{1,2}:\\d{2}|\\d{1,2}\\s?(am|pm)|am|pm)", options: .regularExpression) != nil

            if !hasTimeIndicators {
               let cal = Calendar.current
               if cal.isDateInToday(matchDate) {
                  resolved = date(atHour: defaultTodayHour, minute: 0, on: matchDate)
               } else if cal.isDateInTomorrow(matchDate) {
                  resolved = date(atHour: defaultTomorrowHour, minute: 0, on: matchDate)
               }
               if let existing = dueDate {
                  resolved = merge(date: resolved, withTimeFrom: existing)
               }
            }

            dueDate = resolved
         }
      }

      let lower = input.lowercased()
      let sensitiveKeywords = ["urgent", "asap", "time-sensitive", "time sensitive", "immediately", "now", "priority", "!!!"]
      if sensitiveKeywords.contains(where: { lower.contains($0) }) {
         isTimeSensitive = true
      }
   }
}

private enum WatchRemovalAction: String {
   case archive
   case delete

   var systemImage: String {
      switch self {
      case .archive:
         return "archivebox.fill"
      case .delete:
         return "trash.fill"
      }
   }

   var fillColor: Color {
      switch self {
      case .archive:
         return WatchAppColor.secondary
      case .delete:
         return WatchAppColor.destructive
      }
   }

   var accessibilityLabel: LocalizedStringKey {
      switch self {
      case .archive:
         return "Archive"
      case .delete:
         return "Trash"
      }
   }
}

struct WatchToDoDetailView: View {
   let itemID: String
   @ObservedObject var store: WatchToDoStore
   var onDeleted: (String) -> Void = { _ in }
   @Environment(\.dismiss) private var dismiss
   @AppStorage("doneSwipePrimaryAction") private var removalActionRaw = "delete"
   @State private var isDeleting = false
   @State private var isBackdropVisible = false

   private var todo: WatchToDoItem? {
      store.items.first { $0.id == itemID }
   }

   private var removalAction: WatchRemovalAction {
      WatchRemovalAction(rawValue: removalActionRaw) ?? .delete
   }

   var body: some View {
      if let todo = todo {
         ScrollView {
            VStack(alignment: .leading, spacing: 12) {
               HStack(alignment: .center, spacing: 8) {
                  Image(systemName: todo.isDone ? "checkmark" : "circle.fill")
                     .font(.system(size: todo.isDone ? 13 : 8, weight: .black, design: .rounded))
                     .foregroundStyle(todo.isDone ? WatchAppColor.onAction : detailAccent(for: todo))
                     .frame(width: 28, height: 28)
                     .background(todo.isDone ? WatchAppColor.actionSuccess : detailAccent(for: todo).opacity(0.16), in: Circle())

                  Text("Your toDō")
                     .font(.watchDisplay(18, relativeTo: .headline))
                     .foregroundStyle(WatchAppColor.textPrimary)

                  Spacer(minLength: 0)
               }

               WatchCard(spacing: 8) {
                  Text(todo.task)
                     .font(.watchUserEntry(20, relativeTo: .headline))
                     .foregroundStyle(WatchAppColor.textPrimary)
                     .strikethrough(todo.isDone)

                  if let dueDate = todo.dueDate {
                     WatchMetadataRow(
                        systemImage: "calendar",
                        title: String(localized: "Due"),
                        value: formattedDetailDateTime(dueDate),
                        accent: WatchAppColor.actionPrimary
                     )
                  }

                  if todo.isTimeSensitive {
                     WatchMetadataRow(
                        systemImage: "bolt.fill",
                        title: String(localized: "Priority"),
                        value: String(localized: "Time-Sensitive"),
                        accent: WatchAppColor.destructive
                     )
                  }
               }

               if !todo.nanoDos.isEmpty {
                  WatchActionGroup(title: "nanoDos", systemImage: "smallcircle.filled.circle", accent: WatchAppColor.main) {
                     ForEach(todo.nanoDos) { nanoDo in
                        WatchNanoDoRow(
                           nanoDo: nanoDo,
                           onToggleDone: {
                              nanoDo.isDone ? store.reopenNanoDo(nanoDo, in: todo) : store.completeNanoDo(nanoDo, in: todo)
                           },
                           onDelete: {
                              store.deleteNanoDo(nanoDo, in: todo)
                           }
                        )
                     }
                  }
               }

               if store.canOpenOnPhone {
                  Button {
                     store.openOnPhone(todo)
                  } label: {
                     Label("Open on iPhone", systemImage: "iphone.and.arrow.forward")
                        .font(.watchBodyStrong(12, relativeTo: .caption))
                        .frame(maxWidth: .infinity)
                  }
                  .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.main))
                  .accessibilityLabel("Open on iPhone")
               }

               WatchCard(spacing: 10) {
                  HStack(spacing: 10) {
                     Spacer(minLength: 0)

                     Button {
                        performRemovalAction(todo)
                     } label: {
                        Image(systemName: removalAction.systemImage)
                     }
                     .buttonStyle(WatchIconButtonStyle(fill: removalAction.fillColor, symbolSize: 17, symbolWeight: .black))
                     .accessibilityLabel(removalAction.accessibilityLabel)

                     Button {
                        todo.isDone ? store.reopen(todo) : store.complete(todo)
                     } label: {
                        Image(systemName: todo.isDone ? "arrow.uturn.backward" : "checkmark")
                     }
                     .buttonStyle(WatchIconButtonStyle(fill: todo.isDone ? WatchAppColor.secondary : WatchAppColor.actionSuccess, symbolSize: 17, symbolWeight: .black))
                     .accessibilityLabel(todo.isDone ? "Mark Active" : "Mark Done")

                     Spacer(minLength: 0)
                  }
               }

               HStack(spacing: 8) {
                  if !todo.isDone {
                     NavigationLink {
                        WatchSnoozePickerView(item: todo, store: store)
                     } label: {
                        Label("Snooze", systemImage: "clock.arrow.circlepath")
                           .font(.watchBodyStrong(12, relativeTo: .caption))
                           .frame(maxWidth: .infinity)
                     }
                     .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.secondary))
                  }

                  NavigationLink {
                     WatchToDoEditView(item: todo, store: store)
                  } label: {
                     Label("Edit", systemImage: "arrow.up.right")
                        .font(.watchBodyStrong(12, relativeTo: .caption))
                        .frame(maxWidth: .infinity)
                  }
                  .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.actionPrimary))
               }

               WatchCard(spacing: 6) {
                  HStack {
                     VStack(alignment: .leading, spacing: 2) {
                        Text("Created")
                           .font(.watchBodyStrong(10, relativeTo: .caption2))
                           .foregroundStyle(WatchAppColor.textSecondary)
                        Text(WatchLocalization.dateString(todo.createdAt))
                           .font(.watchBody(11, relativeTo: .caption2))
                     }
                     Spacer()
                     VStack(alignment: .trailing, spacing: 2) {
                        Text("Modified")
                           .font(.watchBodyStrong(10, relativeTo: .caption2))
                           .foregroundStyle(WatchAppColor.textSecondary)
                        Text(WatchLocalization.timeString(todo.updatedAt))
                           .font(.watchBody(11, relativeTo: .caption2))
                     }
                  }
               }
               .opacity(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 14)
         }
         .frame(maxWidth: .infinity)
         .background {
            WatchFocusedToDoBackdrop(isVisible: isBackdropVisible)
         }
         .scaleEffect(isDeleting ? 0.86 : 1)
         .opacity(isDeleting ? 0.18 : 1)
         .overlay {
            if isDeleting {
               WatchDeletionBurstView()
                  .transition(.scale(scale: 0.82).combined(with: .opacity))
            }
         }
         .animation(.spring(response: 0.34, dampingFraction: 0.76), value: isDeleting)
         .onAppear {
            isBackdropVisible = false
            withAnimation(.easeOut(duration: 0.46).delay(0.04)) {
               isBackdropVisible = true
            }
         }
	         .onDisappear {
	            withAnimation(.easeIn(duration: 0.22)) {
	               isBackdropVisible = false
	            }
	         }
	         .accessibilityIdentifier("watch.todo.view")
	      } else {
         Color.clear
            .task {
               dismiss()
            }
      }
   }

   private func delete(_ todo: WatchToDoItem) {
      guard !isDeleting else { return }
      WKInterfaceDevice.current().play(.click)
      withAnimation(.spring(response: 0.34, dampingFraction: 0.76)) {
         isDeleting = true
      }

      Task {
         try? await Task.sleep(nanoseconds: 560_000_000)
         await MainActor.run {
            store.trash(todo)
            onDeleted(String(localized: "Deleted."))
            dismiss()
         }
      }
   }

   private func performRemovalAction(_ todo: WatchToDoItem) {
      switch removalAction {
      case .archive:
         guard !isDeleting else { return }
         WKInterfaceDevice.current().play(.click)
         store.archive(todo)
         dismiss()
      case .delete:
         delete(todo)
      }
   }

   private func detailAccent(for item: WatchToDoItem) -> Color {
      item.isOverdue ? WatchAppColor.destructive : (item.isTimeSensitive ? WatchAppColor.destructive : WatchAppColor.actionPrimary)
   }

   private func formattedDetailDateTime(_ date: Date) -> String {
      WatchLocalization.dateTimeString(date)
   }
}

private struct WatchFocusedToDoBackdrop: View {
   let isVisible: Bool

   var body: some View {
      ZStack {
         WatchAppColor.surfaceElevated

         Circle()
            .fill(
               RadialGradient(
                  colors: [
                     Color.black.opacity(isVisible ? 0.62 : 0),
                     Color.black.opacity(isVisible ? 0.38 : 0),
                     Color.black.opacity(isVisible ? 0.14 : 0),
                     .clear
                  ],
                  center: .center,
                  startRadius: 6,
                  endRadius: 122
               )
            )
            .scaleEffect(isVisible ? 1.2 : 0.72)
            .blur(radius: isVisible ? 3 : 13)
            .allowsHitTesting(false)
      }
      .ignoresSafeArea()
   }
}

struct WatchNanoDoRow: View {
   let nanoDo: WatchNanoDoItem
   let onToggleDone: () -> Void
   let onDelete: () -> Void

   var body: some View {
      HStack(spacing: 8) {
         Button(action: onToggleDone) {
            Image(systemName: nanoDo.isDone ? "arrow.uturn.backward" : "checkmark")
               .font(.system(size: nanoDo.isDone ? 12 : 13, weight: .black, design: .rounded))
               .frame(width: 28, height: 28)
               .background(nanoDo.isDone ? WatchAppColor.secondary : WatchAppColor.actionSuccess, in: Circle())
         }
         .buttonStyle(.plain)
         .foregroundStyle(WatchAppColor.onAction)
         .accessibilityLabel(nanoDo.isDone ? "Mark nanoDo active" : "Mark nanoDo done")

         VStack(alignment: .leading, spacing: 2) {
            Text(nanoDo.task)
               .font(.watchBodyStrong(13, relativeTo: .caption))
               .foregroundStyle(nanoDo.isDone ? WatchAppColor.textSecondary : WatchAppColor.textPrimary)
               .lineLimit(2)
               .strikethrough(nanoDo.isDone)

            if let dueDate = nanoDo.dueDate {
               Text(WatchLocalization.dateTimeString(dueDate))
                  .font(.watchBody(10, relativeTo: .caption2))
                  .foregroundStyle(WatchAppColor.textSecondary)
            }
         }

         Spacer(minLength: 0)

         Button(role: .destructive, action: onDelete) {
            Image(systemName: "trash")
               .font(.system(size: 12, weight: .bold))
               .frame(width: 28, height: 28)
         }
         .buttonStyle(.plain)
         .foregroundStyle(WatchAppColor.destructive)
         .accessibilityLabel("Delete nanoDo")
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 7)
      .background(WatchAppColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
   }
}

struct WatchDeletionBurstView: View {
   @State private var animate = false

   var body: some View {
      ZStack {
         Circle()
            .stroke(WatchAppColor.destructive.opacity(0.42), lineWidth: 2)
            .frame(width: animate ? 96 : 38, height: animate ? 96 : 38)
            .opacity(animate ? 0 : 1)

         Circle()
            .fill(WatchAppColor.destructive)
            .frame(width: animate ? 54 : 42, height: animate ? 54 : 42)
            .shadow(color: WatchAppColor.destructive.opacity(0.35), radius: 12, y: 3)

         Image(systemName: "trash")
            .font(.system(size: 20, weight: .black, design: .rounded))
            .foregroundStyle(WatchAppColor.onAction)
            .scaleEffect(animate ? 1.08 : 0.88)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .onAppear {
         withAnimation(.easeOut(duration: 0.52)) {
            animate = true
         }
      }
      .accessibilityHidden(true)
   }
}

struct WatchToastView: View {
   let message: String

   var body: some View {
      HStack(spacing: 8) {
         Image(systemName: "trash")
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(WatchAppColor.onAction)
            .frame(width: 24, height: 24)
            .background(WatchAppColor.destructive, in: Circle())

         Text(message)
            .font(.watchBodyStrong(12, relativeTo: .caption))
            .foregroundStyle(WatchAppColor.textPrimary)

         Spacer(minLength: 0)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .background(WatchAppColor.surfaceElevated, in: Capsule(style: .continuous))
      .overlay {
         Capsule(style: .continuous)
            .stroke(WatchAppColor.destructive.opacity(0.42), lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
      .accessibilityElement(children: .combine)
   }
}

struct WatchDueReminderBanner: View {
   let item: WatchToDoItem
   let now: Date
   let onOpen: () -> Void
   let onDone: () -> Void
   let onSnooze: () -> Void
   let onDismiss: () -> Void

   var body: some View {
      VStack(alignment: .leading, spacing: 7) {
         HStack(alignment: .center, spacing: 7) {
            Image(systemName: item.isTimeSensitive ? "bolt.fill" : "bell.badge.fill")
               .font(.watchBodyStrong(11, relativeTo: .caption))
               .foregroundStyle(WatchAppColor.onAction)
               .frame(width: 23, height: 23)
               .background(WatchAppColor.main, in: Circle())

            Text(item.task)
               .font(.watchUserEntry(15, relativeTo: .headline))
               .foregroundStyle(WatchAppColor.textPrimary)
               .lineLimit(1)
               .minimumScaleFactor(0.72)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
               WatchCloseIconButton(size: 29, symbolSize: 13)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss details")
         }

         Text(dueText)
            .font(.watchBodyStrong(10, relativeTo: .caption2))
            .foregroundStyle(WatchAppColor.main)
            .lineLimit(1)

         HStack(spacing: 8) {
            Button(action: onDone) {
               Image(systemName: "checkmark")
                  .font(.system(size: 13, weight: .black, design: .rounded))
                  .frame(width: 28, height: 28)
            }
            .buttonStyle(WatchIconButtonStyle(fill: WatchAppColor.actionSuccess, size: 34, symbolSize: 16, symbolWeight: .black))
            .accessibilityLabel("Done")

            Button(action: onSnooze) {
               Image(systemName: "arrow.clockwise")
                  .font(.system(size: 14, weight: .black, design: .rounded))
                  .frame(width: 28, height: 28)
            }
            .buttonStyle(WatchIconButtonStyle(fill: WatchAppColor.white, foreground: WatchAppColor.black, size: 34, symbolSize: 16, symbolWeight: .black))
            .accessibilityLabel("Snooze 15 minutes")

            Button(action: onOpen) {
               Image(systemName: "arrow.up.right")
                  .font(.system(size: 13, weight: .black, design: .rounded))
                  .frame(width: 28, height: 28)
            }
            .buttonStyle(WatchIconButtonStyle(fill: WatchAppColor.actionPrimary, size: 34, symbolSize: 16, symbolWeight: .black))
            .accessibilityLabel("Open toDō")
         }
         .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(10)
      .background(WatchAppColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
      .overlay {
         RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(WatchAppColor.destructive, lineWidth: item.isTimeSensitive ? 1.4 : 0)
      }
      .shadow(color: Color.black.opacity(0.24), radius: 10, y: 5)
   }

   private var dueText: String {
      guard let dueDate = item.dueDate else { return "" }
      if dueDate <= now {
         return WatchLocalization.timeString(dueDate)
      }
      return WatchLocalization.dateTimeString(dueDate)
   }
}

private struct WatchDateSelectionView: View {
   let title: String
   @Binding var selection: Date

   var body: some View {
      VStack(alignment: .leading, spacing: 12) {
         WatchScreenHeader(
            title: title,
            systemImage: "calendar",
            accent: WatchAppColor.actionPrimary
         )

         WatchCard {
            DatePicker(
               title,
               selection: $selection,
               displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.wheel)
            .tint(WatchAppColor.actionPrimary)
            .frame(maxWidth: .infinity)
         }

         Text("Use the Digital Crown here. The main form stays easy to scroll.")
            .font(.watchBody(11, relativeTo: .caption2))
            .foregroundStyle(WatchAppColor.textSecondary)
            .padding(.horizontal, 4)
      }
      .padding(.horizontal, 2)
      .background(WatchAppColor.surface)
      .navigationTitle("")
      .toolbarBackground(.hidden, for: .navigationBar)
      .tint(WatchAppColor.actionPrimary)
   }
}

private struct WatchTimeSelectionView: View {
   let title: String
   @Binding var selection: Date

   var body: some View {
      VStack(alignment: .leading, spacing: 12) {
         WatchScreenHeader(
            title: title,
            systemImage: "clock",
            accent: WatchAppColor.secondary
         )

         WatchCard {
            DatePicker(
               title,
               selection: $selection,
               displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.wheel)
            .tint(WatchAppColor.secondary)
            .frame(maxWidth: .infinity)
         }

         Text("Set the time here, then swipe back when finished.")
            .font(.watchBody(11, relativeTo: .caption2))
            .foregroundStyle(WatchAppColor.textSecondary)
            .padding(.horizontal, 4)
      }
      .padding(.horizontal, 2)
      .background(WatchAppColor.surface)
      .navigationTitle("")
      .toolbarBackground(.hidden, for: .navigationBar)
      .tint(WatchAppColor.secondary)
   }
}

struct WatchToDoEditView: View {
   let item: WatchToDoItem
   @ObservedObject var store: WatchToDoStore
   @Environment(\.dismiss) private var dismiss

   @State private var task: String
   @State private var dueDate: Date?
   @State private var isTimeSensitive: Bool

   init(item: WatchToDoItem, store: WatchToDoStore) {
      self.item = item
      self.store = store
      _task = State(initialValue: item.task)
      _dueDate = State(initialValue: item.dueDate)
      _isTimeSensitive = State(initialValue: item.isTimeSensitive)
   }

   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 12) {
            WatchScreenHeader(
               title: "Edit toDō",
               systemImage: "arrow.up.right",
               accent: WatchAppColor.actionPrimary
            )

            WatchCard {
               TextField("toDō", text: $task, axis: .vertical)
                  .font(.watchUserEntry(17, relativeTo: .headline))
                  .foregroundStyle(WatchAppColor.textPrimary)
                  .lineLimit(1...4)
                  .textInputAutocapitalization(.sentences)
            }

            WatchActionGroup(title: "Schedule", systemImage: "clock", accent: WatchAppColor.actionPrimary, cardSpacing: 12) {
               WatchScheduleSummary(dueDate: dueDate)

               if dueDate == nil {
                  Button {
                     dueDate = defaultDueDate()
                  } label: {
                     WatchScheduleWideAction(
                        title: "Add Due Date",
                        systemImage: "calendar",
                        accent: WatchAppColor.actionPrimary
                     )
                  }
                  .buttonStyle(.plain)
               } else {
                  HStack(spacing: 8) {
                     NavigationLink {
                        WatchDateSelectionView(
                           title: "Due Date",
                           selection: Binding(
                              get: { dueDate ?? defaultDueDate() },
                              set: { dueDate = merge(date: $0, withTimeFrom: dueDate) }
                           )
                        )
                     } label: {
                        WatchScheduleTile(
                           title: "Date",
                           value: dueDate.map(WatchLocalization.monthDayString) ?? "",
                           systemImage: "calendar",
                           accent: WatchAppColor.actionPrimary
                        )
                     }
                     .buttonStyle(.plain)

                     NavigationLink {
                        WatchTimeSelectionView(
                           title: "Due Time",
                           selection: Binding(
                              get: { dueDate ?? defaultDueDate() },
                              set: { dueDate = merge(time: $0, withDateFrom: dueDate) }
                           )
                        )
                     } label: {
                        WatchScheduleTile(
                           title: "Time",
                           value: dueDate.map(WatchLocalization.timeString) ?? "",
                           systemImage: "clock",
                           accent: WatchAppColor.secondary
                        )
                     }
                     .buttonStyle(.plain)
                  }
               }

               VStack(alignment: .leading, spacing: 7) {
                  Text("Quick Picks")
                     .font(.watchBodyStrong(10, relativeTo: .caption2))
                     .foregroundStyle(WatchAppColor.textSecondary)
                     .padding(.horizontal, 2)

                  HStack(spacing: 8) {
                     Button {
                        dueDate = quickDueDate(.today)
                     } label: {
                        WatchSchedulePill(title: "Today", value: formattedEditTodayTime, accent: WatchAppColor.actionPrimary)
                     }
                     .buttonStyle(.plain)

                     Button {
                        dueDate = quickDueDate(.tomorrow)
                     } label: {
                        WatchSchedulePill(title: "Tomorrow", value: formattedEditTomorrowTime, accent: WatchAppColor.secondary)
                     }
                     .buttonStyle(.plain)
                  }

                  if dueDate != nil {
                     Button {
                        dueDate = nil
                        isTimeSensitive = false
                     } label: {
                        WatchScheduleWideAction(
                           title: "Clear Due Date",
                           systemImage: "xmark",
                           accent: WatchAppColor.textSecondary
                        )
                     }
                     .buttonStyle(.plain)
                  }
               }

               WatchScheduleToggleRow(
                  isOn: $isTimeSensitive,
                  dueDate: $dueDate,
                  defaultDueDate: defaultDueDate
               )
            }

            Button {
               save()
            } label: {
               Label("Save", systemImage: "tray.and.arrow.down")
                  .font(.watchButton(20, relativeTo: .title3))
            }
            .buttonStyle(WatchProminentButtonStyle())
            .frame(maxWidth: .infinity, alignment: .center)
            .disabled(task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
         }
         .padding(.horizontal, 2)
         .padding(.bottom, 12)
      }
      .background(WatchAppColor.surface)
      .navigationTitle("")
      .toolbar {
         ToolbarItem(placement: .cancellationAction) {
            Button {
               dismiss()
            } label: {
               WatchCloseIconButton()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel")
         }
      }
   }

   private func save() {
      store.updateTask(task, for: item)
      store.setDueDate(dueDate, for: item, isTimeSensitive: dueDate == nil ? false : isTimeSensitive)
      dismiss()
   }

   private func merge(date newDay: Date, withTimeFrom base: Date?) -> Date {
      let calendar = Calendar.current
      let baseTime = base ?? newDay
      let time = calendar.dateComponents([.hour, .minute, .second], from: baseTime)
      var components = calendar.dateComponents([.year, .month, .day], from: newDay)
      components.hour = time.hour
      components.minute = time.minute
      components.second = time.second
      return calendar.date(from: components) ?? newDay
   }

   private func merge(time newTime: Date, withDateFrom base: Date?) -> Date {
      let calendar = Calendar.current
      let baseDay = base ?? newTime
      let time = calendar.dateComponents([.hour, .minute, .second], from: newTime)
      var components = calendar.dateComponents([.year, .month, .day], from: baseDay)
      components.hour = time.hour
      components.minute = time.minute
      components.second = time.second
      return calendar.date(from: components) ?? newTime
   }

   private func defaultDueDate() -> Date {
      let calendar = Calendar.current
      let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
      var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
      components.hour = 9
      components.minute = 0
      components.second = 0
      return calendar.date(from: components) ?? tomorrow
   }

   private enum EditQuickDue { case today, tomorrow }

   private var formattedEditTodayTime: String {
      WatchLocalization.timeString(date(atHour: 17, minute: 0, on: Date()))
   }

   private var formattedEditTomorrowTime: String {
      let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
      return WatchLocalization.timeString(date(atHour: 9, minute: 0, on: tomorrow))
   }

   private func quickDueDate(_ quick: EditQuickDue) -> Date {
      let calendar = Calendar.current
      switch quick {
      case .today:
         return date(atHour: 17, minute: 0, on: calendar.startOfDay(for: Date()))
      case .tomorrow:
         let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
         return date(atHour: 9, minute: 0, on: tomorrow)
      }
   }

   private func date(atHour hour: Int, minute: Int, on baseDay: Date) -> Date {
      var components = Calendar.current.dateComponents([.year, .month, .day], from: baseDay)
      components.hour = hour
      components.minute = minute
      components.second = 0
      return Calendar.current.date(from: components) ?? baseDay
   }
}

struct WatchSnoozeView: View {
   let toDoID: String
   @ObservedObject var store: WatchToDoStore
   @Environment(\.dismiss) private var dismiss

   @State private var selectedUnit: WatchSnoozeUnit? = nil
   @State private var selectedValue: Int? = nil

   private var todo: WatchToDoItem? {
      store.items.first { $0.id == toDoID }
   }

   var body: some View {
      if let todo = todo {
         List {
            if let unit = selectedUnit {
               Section("For how long?") {
                  ForEach(Array(unit.values.enumerated()), id: \.offset) { _, value in
                     Button {
                        selectedValue = value
                        store.snooze(todo, seconds: unit.seconds(for: value))

                        Task {
                           try? await Task.sleep(nanoseconds: 300_000_000)
                           dismiss() // Returns to Detail View
                        }
                     } label: {
                        HStack {
                           Text(unit.label(for: value))
                              .font(.watchBodyStrong(15, relativeTo: .body))
                           Spacer()
                           if selectedValue == value {
                              Image(systemName: "checkmark")
                           }
                        }
                        .foregroundStyle(selectedValue == value ? WatchAppColor.actionSuccess : WatchAppColor.actionSecondary)
                     }
                  }
               }
            } else {
               Section("Snooze Unit") {
                  ForEach(WatchSnoozeUnit.allCases) { unit in
                     Button {
                        withAnimation { selectedUnit = unit }
                     } label: {
                        Text(unit.title)
                           .font(.watchBodyStrong(15, relativeTo: .body))
                     }
                  }
               }
            }
         }
         .navigationTitle(selectedUnit?.title ?? "Snooze")
      }
   }
}

struct WatchToDoRowActionButton: View {
   let item: WatchToDoItem
   let accent: Color
   let onOpen: () -> Void
   let onToggleDone: () -> Void

   var body: some View {
      WatchToDoRow(
         item: item,
         accent: accent,
         onOpen: onOpen,
         onToggleDone: onToggleDone
      )
      .accessibilityElement(children: .contain)
      .accessibilityLabel(item.task)
      .accessibilityHint("Open this toDō or use the leading control to mark it done.")
   }
}

struct WatchToDoRow: View {
   let item: WatchToDoItem
   let accent: Color
   var onOpen: (() -> Void)?
   var onToggleDone: (() -> Void)?

   var body: some View {
      HStack(alignment: .center, spacing: 9) {
         if onToggleDone != nil {
            completionControl
         }

         if let onOpen {
            Button {
               onOpen()
            } label: {
               rowContent
            }
            .buttonStyle(.plain)
         } else {
            rowContent
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 9)
      .padding(.vertical, 8)
      .background(rowBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay {
         RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(rowBorderColor, lineWidth: rowBorderWidth)
      }
      .scaleEffect(item.isDone ? 0.985 : 1)
      .animation(.spring(response: 0.34, dampingFraction: 0.72), value: item.isDone)
   }

   private var rowContent: some View {
      HStack(alignment: .center, spacing: 8) {
         VStack(alignment: .leading, spacing: 3) {
            Text(item.task)
               .font(.watchUserEntry(16, relativeTo: .headline))
               .foregroundStyle(taskTextColor)
               .lineLimit(2)
               .strikethrough(item.isDone)

            HStack(spacing: 5) {
               if let dueDate = item.dueDate {
                  Text(formattedDueText(dueDate))
               } else if !item.isDone {
                  Text("Quiet")
               }

               if item.isTimeSensitive {
                  Image(systemName: "exclamationmark.circle.fill")
               }
            }
            .font(.watchBodyStrong(11, relativeTo: .caption2))
            .foregroundStyle(metadataColor)
         }

         Spacer(minLength: 0)

         if onOpen != nil {
            Image(systemName: "chevron.right")
               .font(.watchBodyStrong(9, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.textSecondary.opacity(0.7))
               .padding(.top, 5)
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
   }

   private var completionControl: some View {
      Group {
         if let onToggleDone {
            Button {
               onToggleDone()
            } label: {
               completionIndicator
            }
            .buttonStyle(.plain)
         } else {
            completionIndicator
         }
      }
      .accessibilityLabel(item.isDone ? "Mark Active" : "Mark Done")
   }

   private var completionIndicator: some View {
      ZStack {
         Circle()
            .fill(completionFill)
            .frame(width: 32, height: 32)

         if item.isDone {
            Image(systemName: "checkmark")
               .font(.system(size: 14, weight: .black, design: .rounded))
               .foregroundStyle(completionSymbolColor)
               .scaleEffect(1.04)
         }
      }
      .overlay {
         Circle()
            .stroke(completionStroke, lineWidth: item.isDone ? 0 : 2)
      }
      .shadow(color: completionFill.opacity(item.isDone ? 0 : 0.22), radius: 8, y: 3)
      .animation(.spring(response: 0.32, dampingFraction: 0.66), value: item.isDone)
   }

   private var rowBackground: Color {
      if item.isDone {
         return WatchAppColor.surfaceMuted.opacity(0.58)
      }
      if item.isOverdue {
         return WatchAppColor.destructive
      }
      return WatchAppColor.surfaceElevated
   }

   private var completionFill: Color {
      if item.isDone {
         return WatchAppColor.main
      }
      return Color.clear
   }

   private var completionStroke: Color {
      item.isDone ? Color.clear : WatchAppColor.main
   }

   private var completionSymbolColor: Color {
      WatchAppColor.onAction
   }

   private var rowBorderColor: Color {
      guard !item.isDone else { return WatchAppColor.border }
      if item.isTimeSensitive {
         return WatchAppColor.destructive
      }
      return WatchAppColor.border
   }

   private var rowBorderWidth: CGFloat {
      item.isTimeSensitive && !item.isDone ? 1.5 : 1
   }

   private var taskTextColor: Color {
      if item.isDone {
         return WatchAppColor.textSecondary
      }
      return item.isOverdue ? WatchAppColor.white : WatchAppColor.textPrimary
   }

   private var metadataColor: Color {
      if item.isOverdue {
         return WatchAppColor.white.opacity(0.84)
      }
      return item.isTimeSensitive ? WatchAppColor.destructive : WatchAppColor.textSecondary
   }

   private func formattedDueText(_ date: Date) -> String {
      let cal = Calendar.current
      if cal.isDateInToday(date) {
         return String(localized: "Today") + " " + WatchLocalization.timeString(date)
      } else if cal.isDateInTomorrow(date) {
         return String(localized: "Tomorrow") + " " + WatchLocalization.timeString(date)
      } else {
         return WatchLocalization.dateTimeString(date)
      }
   }
}

struct WatchScreenHeader: View {
   let title: String
   let subtitle: String?
   let systemImage: String
   let accent: Color

   init(title: String, subtitle: String? = nil, systemImage: String, accent: Color) {
      self.title = title
      self.subtitle = subtitle
      self.systemImage = systemImage
      self.accent = accent
   }

   var body: some View {
      HStack(alignment: .center, spacing: 9) {
         Image(systemName: systemImage)
            .font(.system(size: 16, weight: .black, design: .rounded))
            .foregroundStyle(accent)
            .frame(width: 30, height: 30)
            .background(WatchAppColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: WatchAppColor.surfaceMuted.opacity(0.28), radius: 7, y: 3)

         VStack(alignment: .leading, spacing: 1) {
            Text(LocalizedStringKey(title))
               .font(.watchDisplay(24, relativeTo: .title2))
               .foregroundStyle(WatchAppColor.textPrimary)

            if let subtitle, !subtitle.isEmpty {
               Text(LocalizedStringKey(subtitle))
                  .font(.watchBody(11, relativeTo: .caption2))
                  .foregroundStyle(WatchAppColor.textSecondary)
                  .lineLimit(2)
            }
         }
      }
      .padding(.top, 3)
      .accessibilityElement(children: .combine)
   }
}

struct WatchCard<Content: View>: View {
   private let spacing: CGFloat
   @ViewBuilder private let content: Content

   init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
      self.spacing = spacing
      self.content = content()
   }

   var body: some View {
      VStack(alignment: .leading, spacing: spacing) {
         content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(WatchAppColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
   }
}

struct WatchMetadataRow: View {
   let systemImage: String
   let title: String
   let value: String
   let accent: Color

   var body: some View {
      HStack(spacing: 8) {
         Image(systemName: systemImage)
            .font(.watchBodyStrong(11, relativeTo: .caption))
            .foregroundStyle(accent)
            .frame(width: 20, height: 20)
            .background(accent.opacity(0.14), in: Circle())

         VStack(alignment: .leading, spacing: 1) {
            Text(LocalizedStringKey(title))
               .font(.watchBodyStrong(10, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.textSecondary)

            Text(value)
               .font(.watchBodyStrong(12, relativeTo: .caption))
               .foregroundStyle(WatchAppColor.textPrimary)
               .lineLimit(2)
         }
      }
   }
}

struct WatchPickerBlock<Content: View>: View {
   let title: String
   let systemImage: String
   let height: CGFloat
   @ViewBuilder let content: Content

   var body: some View {
      VStack(alignment: .leading, spacing: 6) {
         Label(LocalizedStringKey(title), systemImage: systemImage)
            .font(.watchBodyStrong(10, relativeTo: .caption2))
            .foregroundStyle(WatchAppColor.textSecondary)

         content
            .frame(maxWidth: .infinity)
            .frame(height: height)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
   }
}

struct WatchScheduleSummary: View {
   let dueDate: Date?

   var body: some View {
      HStack(spacing: 10) {
         Image(systemName: dueDate == nil ? "calendar" : "calendar")
            .font(.system(size: 14, weight: .black, design: .rounded))
            .foregroundStyle(accent)
            .frame(width: 28, height: 28)

         VStack(alignment: .leading, spacing: 2) {
            Text("Schedule")
               .font(.watchBodyStrong(11, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.textSecondaryStrong)

            Text(summaryText)
               .font(.watchDisplay(17, relativeTo: .headline))
               .foregroundStyle(WatchAppColor.textPrimary)
               .lineLimit(2)
         }

         Spacer(minLength: 0)
      }
      .padding(.horizontal, 2)
      .padding(.vertical, 3)
   }

   private var accent: Color {
      dueDate == nil ? WatchAppColor.textSecondary : WatchAppColor.actionPrimary
   }

   private var summaryText: String {
      guard let dueDate else { return String(localized: "No Due Date") }
      return WatchLocalization.dateTimeString(dueDate)
   }
}

struct WatchScheduleTile: View {
   let title: String
   let value: String
   let systemImage: String
   let accent: Color

   var body: some View {
      VStack(alignment: .leading, spacing: 7) {
         Image(systemName: systemImage)
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(WatchAppColor.onAction)
            .frame(width: 30, height: 24, alignment: .leading)

         Text(LocalizedStringKey(title))
            .font(.watchBodyStrong(10, relativeTo: .caption2))
            .foregroundStyle(WatchAppColor.onAction.opacity(0.72))

            Text(value)
            .font(.watchBodyStrong(13, relativeTo: .caption))
            .foregroundStyle(WatchAppColor.onAction)
            .lineLimit(1)
            .minimumScaleFactor(0.74)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(9)
      .background(
         RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(accent)
      )
      .shadow(color: accent.opacity(0.18), radius: 8, y: 4)
      .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
   }
}

struct WatchSchedulePill: View {
   let title: String
   let value: String
   let accent: Color

   var body: some View {
      VStack(alignment: .leading, spacing: 2) {
         Text(LocalizedStringKey(title))
            .font(.watchBodyStrong(11, relativeTo: .caption))
            .foregroundStyle(WatchAppColor.onAction)
            .lineLimit(1)

         Text(value)
            .font(.watchBodyStrong(9, relativeTo: .caption2))
            .foregroundStyle(WatchAppColor.onAction.opacity(0.72))
            .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 8)
      .padding(.horizontal, 9)
      .background(
         Capsule(style: .continuous)
            .fill(accent)
      )
      .shadow(color: accent.opacity(0.16), radius: 6, y: 3)
      .contentShape(Capsule(style: .continuous))
   }
}

struct WatchScheduleWideAction: View {
   let title: String
   let systemImage: String
   let accent: Color

   var body: some View {
      HStack(spacing: 9) {
         Image(systemName: systemImage)
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(WatchAppColor.onAction)
            .frame(width: 30, height: 30)

         VStack(alignment: .leading, spacing: 1) {
           Text(LocalizedStringKey(title))
               .font(.watchButton(18, relativeTo: .headline))
               .foregroundStyle(WatchAppColor.onAction)
         }

         Spacer(minLength: 0)
      }
      .padding(10)
      .background(
         RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(accent)
      )
      .shadow(color: accent.opacity(0.18), radius: 8, y: 4)
      .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
   }
}

struct WatchScheduleToggleRow: View {
   @Binding var isOn: Bool
   @Binding var dueDate: Date?
   let defaultDueDate: () -> Date

   var body: some View {
      Button {
         if dueDate == nil {
            dueDate = defaultDueDate()
         }
         isOn.toggle()
      } label: {
         HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
               .font(.system(size: 15, weight: .black, design: .rounded))
               .foregroundStyle(foreground)
               .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
               Text("Time-Sensitive")
                  .font(.watchBodyStrong(12, relativeTo: .caption))
                  .foregroundStyle(foreground)
            }

            Spacer(minLength: 0)

            Text(isOn ? String(localized: "On") : String(localized: "Off"))
               .font(.watchBodyStrong(11, relativeTo: .caption2))
               .foregroundStyle(stateTextColor)
               .padding(.horizontal, 8)
               .padding(.vertical, 5)
               .background(stateBackground, in: Capsule(style: .continuous))
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(10)
         .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
               .fill(background)
         )
         .overlay {
            if !isOn {
               RoundedRectangle(cornerRadius: 16, style: .continuous)
                  .stroke(WatchAppColor.destructive, lineWidth: 2)
            }
         }
         .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      .buttonStyle(.plain)
      .shadow(color: isOn ? WatchAppColor.destructive.opacity(0.18) : .clear, radius: 8, y: 4)
   }

   private var foreground: Color {
      isOn ? WatchAppColor.onAction : WatchAppColor.destructive
   }

   private var background: some ShapeStyle {
      isOn ? AnyShapeStyle(WatchAppColor.destructive) : AnyShapeStyle(Color.clear)
   }

   private var stateTextColor: Color {
      isOn ? WatchAppColor.destructive : WatchAppColor.destructive
   }

   private var stateBackground: Color {
      isOn ? WatchAppColor.onAction.opacity(0.95) : WatchAppColor.destructive.opacity(0.12)
   }
}

struct WatchActionGroup<Content: View>: View {
   let title: String
   let systemImage: String
   let accent: Color
   var cardSpacing: CGFloat = 7
   @ViewBuilder let content: Content

   var body: some View {
      VStack(alignment: .leading, spacing: 7) {
         Label(LocalizedStringKey(title), systemImage: systemImage)
            .font(.watchDisplay(18, relativeTo: .headline))
            .foregroundStyle(accent)
            .padding(.horizontal, 4)

         WatchCard(spacing: cardSpacing) {
            content
         }
      }
   }
}

struct WatchProminentButtonStyle: ButtonStyle {
   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .font(.watchButton(20, relativeTo: .title3))
         .foregroundStyle(WatchAppColor.onAction)
         .frame(minWidth: 122, minHeight: 48)
         .padding(.horizontal, 16)
         .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
               .fill(configuration.isPressed ? WatchAppColor.secondary : WatchAppColor.actionPrimary)
         )
         .shadow(
            color: (configuration.isPressed ? WatchAppColor.secondary : WatchAppColor.actionPrimary).opacity(0.2),
            radius: 8,
            y: 4
         )
         .scaleEffect(configuration.isPressed ? 0.96 : 1)
         .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
   }
}

struct WatchHomeActionButtonStyle: ButtonStyle {
   let foreground: Color
   let fill: Color
   let pressedFill: Color
   let height: CGFloat

   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .font(.watchButton(19, relativeTo: .headline))
         .foregroundStyle(foreground)
         .padding(.horizontal, 12)
         .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .center)
         .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
               .fill(configuration.isPressed ? pressedFill : fill)
         )
         .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
         .scaleEffect(configuration.isPressed ? 0.97 : 1)
         .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
   }
}

struct WatchFilledButtonStyle: ButtonStyle {
   let fill: Color

   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .font(.watchButton(18, relativeTo: .headline))
         .foregroundStyle(WatchAppColor.onAction)
         .padding(.vertical, 9)
         .padding(.horizontal, 12)
         .background(
            Capsule(style: .continuous)
               .fill(configuration.isPressed ? fill.opacity(0.74) : fill)
         )
         .scaleEffect(configuration.isPressed ? 0.96 : 1)
         .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
   }
}

struct WatchIconButtonStyle: ButtonStyle {
   let fill: Color
   var foreground: Color = WatchAppColor.onAction
   var size: CGFloat = 38
   var symbolSize: CGFloat = 15
   var symbolWeight: Font.Weight = .semibold
   var stroke: Color?
   var strokeWidth: CGFloat = 0

   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .font(.system(size: symbolSize, weight: symbolWeight, design: .rounded))
         .foregroundStyle(foreground)
         .frame(width: size, height: size)
         .background {
            Circle()
               .fill(.regularMaterial)
               .overlay {
                  Circle()
                     .fill(configuration.isPressed ? fill.opacity(0.58) : fill.opacity(0.82))
               }
         }
         .overlay {
            if let stroke, strokeWidth > 0 {
               Circle().stroke(stroke, lineWidth: strokeWidth)
            }
         }
         .scaleEffect(configuration.isPressed ? 0.93 : 1)
         .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
   }
}

struct WatchCompactIconButtonStyle: ButtonStyle {
   let fill: Color
   var foreground: Color = WatchAppColor.onAction
   var size: CGFloat = 34
   var minHeight: CGFloat = 34
   var symbolSize: CGFloat = 15
   var cornerRadius: CGFloat = 13

   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .font(.system(size: symbolSize, weight: .black, design: .rounded))
         .foregroundStyle(foreground)
         .frame(
            minWidth: size,
            idealWidth: size,
            maxWidth: size,
            minHeight: minHeight
         )
         .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
               .fill(configuration.isPressed ? fill.opacity(0.72) : fill)
         )
         .shadow(color: fill.opacity(0.18), radius: 7, y: 3)
         .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
         .scaleEffect(configuration.isPressed ? 0.94 : 1)
         .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
   }
}

struct WatchCloseIconButton: View {
   var size: CGFloat = 34
   var symbolSize: CGFloat = 15

   var body: some View {
      Image(systemName: "xmark")
         .font(.system(size: symbolSize, weight: .black, design: .rounded))
         .foregroundStyle(WatchAppColor.onAction)
         .frame(width: size, height: size, alignment: .center)
         .background(WatchAppColor.destructive, in: Circle())
         .contentShape(Circle())
   }
}

struct WatchSoftButtonStyle: ButtonStyle {
   let accent: Color

   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .font(.watchButton(18, relativeTo: .headline))
         .foregroundStyle(accent)
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(.vertical, 8)
         .padding(.horizontal, 10)
         .background(
         RoundedRectangle(cornerRadius: 14, style: .continuous)
               .fill(configuration.isPressed ? accent.opacity(0.24) : accent.opacity(0.13))
         )
         .scaleEffect(configuration.isPressed ? 0.97 : 1)
         .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
   }
}

struct WatchCircleButtonStyle: ButtonStyle {
   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .foregroundStyle(WatchAppColor.onAction)
         .background(
            Circle()
               .fill(configuration.isPressed ? WatchAppColor.secondary : WatchAppColor.actionPrimary)
         )
         .scaleEffect(configuration.isPressed ? 0.94 : 1)
         .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
   }
}

#Preview {
   ToDosView()
}
