import SwiftUI
import AuthenticationServices

private enum WatchLocalization {
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

   static func timeString(_ date: Date) -> String {
      formatted(date, dateStyle: .none, timeStyle: .short)
   }

   private static func formatted(_ date: Date, dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
      let formatter = DateFormatter()
      formatter.locale = displayLocale
      formatter.calendar = .current
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
            watchBrandFooter
         }
         .padding(.horizontal, 2)
         .padding(.bottom, 12)
      }
      .toolbarBackground(.hidden, for: .navigationBar)
      .background(WatchAppColor.surface)
      .tint(WatchAppColor.actionPrimary)
   }

   private var accountCard: some View {
      WatchCard(spacing: 8) {
         WatchMetadataRow(
            systemImage: authStore.authState.isAuthenticated ? "person.crop.circle.badge.checkmark" : "icloud.slash",
            title: "Sign In",
            value: authStore.authState.detail,
            accent: authStore.authState.isAuthenticated ? WatchAppColor.actionSuccess : WatchAppColor.main
         )

         if !authStore.authState.isAuthenticated {
            SignInWithAppleButton(.signIn) { request in
               authStore.prepareAppleRequest(request)
            } onCompletion: { result in
               authStore.handleAppleAuthorization(result)
            }
            .frame(height: 34)
            .disabled(authStore.isSigningIn)
         } else if authStore.authState.source == .apple {
            Button(role: .destructive) {
               authStore.signOut()
            } label: {
               Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .font(.watchBodyStrong(12, relativeTo: .caption))
         }

         if authStore.isSigningIn {
            ProgressView("Signing In")
               .font(.watchBody(11, relativeTo: .caption2))
         }

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
               value: "\(store.queuedActionCount) pending",
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
      WatchActionGroup(title: "Settings", systemImage: "gearshape.fill", accent: WatchAppColor.secondary) {
         WatchMetadataRow(
            systemImage: "bell.badge",
            title: "Notifications",
            value: "Managed by iPhone and Watch settings",
            accent: WatchAppColor.secondary
         )

         NavigationLink {
            WatchSnoozeOptionsView()
         } label: {
            Label("Snooze Options", systemImage: "zzz")
         }
         .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.secondary))

         Button(action: openDoneToDos) {
            Label(doneToDosLabel, systemImage: "checkmark.circle.fill")
         }
         .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.actionSuccess))
      }
   }

   private var doneToDosLabel: String {
      let count = store.doneItems.count
      return count == 1 ? "Done toDō" : "Done toDōs"
   }

   private var watchBrandFooter: some View {
      VStack(spacing: 10) {
         Text("\(Text("toDō").foregroundStyle(WatchAppColor.main).bold()) what matters")
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
      .custom("Aleo-Bold", size: 15, relativeTo: .caption)
   }

   private var watchBrandWordmarkItalicFont: Font {
      .custom("Aleo-BoldItalic", size: 15, relativeTo: .caption)
   }

   private var updatedText: String {
      if store.queuedActionCount > 0 {
         return "Queued"
      }

      if let lastUpdated = store.lastUpdated {
         return lastUpdated.formatted(date: .omitted, time: .shortened)
      }

      return store.statusText
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
               systemImage: "checkmark.circle.fill",
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
               WatchActionGroup(title: "Recently Done", systemImage: "checkmark.circle.fill", accent: WatchAppColor.actionSuccess) {
                  ForEach(doneItems) { item in
                     Button {
                        store.select(item)
                     } label: {
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
                        value: "Available from any due toDō",
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

               Text(title)
                  .font(.watchDisplay(15, relativeTo: .subheadline))
                  .foregroundStyle(WatchAppColor.textPrimary)

               Text("\(items.count)")
                  .font(.watchBodyStrong(10, relativeTo: .caption2))
                  .foregroundStyle(WatchAppColor.textSecondary)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(WatchAppColor.surfaceMuted, in: Capsule())
            }
            .padding(.horizontal, 4)

            ForEach(items) { item in
               WatchToDoRowActionButton(
                  item: item,
                  accent: accent,
                  onOpen: { store.select(item) },
                  onToggleDone: { item.isDone ? store.reopen(item) : store.complete(item) }
               )
            }
         }
         .padding(.top, 3)
      }
   }
}

struct CaptureToDoView: View {
   @ObservedObject var store: WatchToDoStore
   @Environment(\.dismiss) private var dismiss
   @State private var task = ""
   @State private var dueDate: Date?
   @State private var isTimeSensitive = false

   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 12) {
            WatchScreenHeader(
               title: "New toDō",
               systemImage: "plus.circle.fill",
               accent: WatchAppColor.actionPrimary
            )

            WatchCard {
               TextField("What do you want toDō?", text: $task, axis: .vertical)
                  .font(.watchDisplay(17, relativeTo: .headline))
                  .foregroundStyle(WatchAppColor.textPrimary)
                  .lineLimit(1...4)
                  .textInputAutocapitalization(.sentences)
            }

            WatchCard(spacing: 10) {
               Button {
                  extractDetailsFromTask()
               } label: {
                  Label("Extract from text", systemImage: "wand.and.stars")
                     .font(.watchBodyStrong(12, relativeTo: .caption))
               }
               .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.actionPrimary))

               if let dueDate {
                  WatchMetadataRow(
                     systemImage: "calendar",
                     title: "Due Date",
                     value: dueDate.formatted(date: .abbreviated, time: .shortened),
                     accent: WatchAppColor.actionPrimary
                  )
               } else {
                  WatchMetadataRow(
                     systemImage: "calendar",
                     title: "Due Date",
                     value: "No Due Date",
                     accent: WatchAppColor.textSecondary
                  )
               }

               WatchPickerBlock(title: "Due Date", systemImage: "calendar", height: 118) {
                  DatePicker(
                     "Due Date",
                     selection: Binding(
                        get: { dueDate ?? defaultDateForNewSelection() },
                        set: { newValue in
                           dueDate = merge(date: newValue, withTimeFrom: dueDate)
                        }
                     ),
                     displayedComponents: .date
                  )
                  .labelsHidden()
                  .tint(WatchAppColor.actionPrimary)
               }

               if let dueDate {
                  WatchPickerBlock(title: "Due Time", systemImage: "clock", height: 96) {
                     DatePicker(
                        "Due Time",
                        selection: Binding(
                           get: { dueDate },
                           set: { self.dueDate = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                     )
                     .labelsHidden()
                     .tint(WatchAppColor.actionPrimary)
                  }
               }

               VStack(spacing: 7) {
                  Button {
                     setQuickDue(.today)
                  } label: {
                     Label("Today \(formattedDefaultTodayTime)", systemImage: "sun.max.fill")
                  }
                  .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.actionPrimary))

                  Button {
                     setQuickDue(.tomorrow)
                  } label: {
                     Label("Tomorrow \(formattedDefaultTomorrowTime)", systemImage: "calendar.badge.clock")
                  }
                  .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.secondary))

                  Button {
                     dueDate = nil
                  } label: {
                     Label("No Due Date", systemImage: "calendar.badge.minus")
                  }
                  .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.textSecondary))
               }

               Toggle(isOn: $isTimeSensitive) {
                  Label("Time-Sensitive", systemImage: "exclamationmark.circle.fill")
                     .font(.watchBodyStrong(12, relativeTo: .caption))
               }
               .tint(WatchAppColor.destructive)

               Text("Quick picks set default times: Today \(formattedDefaultTodayTime), Tomorrow \(formattedDefaultTomorrowTime). Adjust time below.")
                  .font(.watchBody(11, relativeTo: .caption2))
                  .foregroundStyle(WatchAppColor.textSecondary)
            }

            Button {
               store.create(task: task, dueDate: dueDate, isTimeSensitive: isTimeSensitive)
               dismiss()
            } label: {
               Label("Add toDō", systemImage: "checkmark.circle.fill")
                  .font(.watchBodyStrong(14, relativeTo: .subheadline))
                  .frame(maxWidth: .infinity)
            }
            .buttonStyle(WatchProminentButtonStyle())
            .disabled(task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
         }
         .padding(.horizontal, 2)
         .padding(.bottom, 12)
      }
      .navigationTitle("New toDō")
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

   private var formattedDefaultTodayTime: String {
      date(atHour: defaultTodayHour, minute: 0, on: Date()).formatted(date: .omitted, time: .shortened)
   }

   private var formattedDefaultTomorrowTime: String {
      let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
      return date(atHour: defaultTomorrowHour, minute: 0, on: tomorrow).formatted(date: .omitted, time: .shortened)
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

struct WatchToDoDetailView: View {
   let item: WatchToDoItem
   @ObservedObject var store: WatchToDoStore
   var onClose: (() -> Void)?

   private var todo: WatchToDoItem? {
      store.items.first { $0.id == item.id } ?? item
   }

   var body: some View {
      if let todo = todo {
         ScrollView {
            VStack(alignment: .leading, spacing: 12) {
               HStack(alignment: .center, spacing: 8) {
                  Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                     .font(.watchBodyStrong(13, relativeTo: .caption))
                     .foregroundStyle(todo.isDone ? WatchAppColor.actionSuccess : detailAccent(for: todo))
                     .frame(width: 28, height: 28)
                     .background(detailAccent(for: todo).opacity(0.16), in: Circle())

                  Text("Your toDō")
                     .font(.watchDisplay(18, relativeTo: .headline))
                     .foregroundStyle(WatchAppColor.textPrimary)

                  Spacer(minLength: 0)

                  if let onClose {
                     Button(action: onClose) {
                        Image(systemName: "xmark")
                           .font(.system(size: 12, weight: .bold))
                           .frame(width: 32, height: 32)
                     }
                     .buttonStyle(WatchIconButtonStyle(
                        fill: WatchAppColor.surfaceElevated,
                        foreground: WatchAppColor.destructive,
                        size: 32,
                        stroke: WatchAppColor.destructive,
                        strokeWidth: 2.4
                     ))
                     .accessibilityLabel("Close")
                  }
               }

               WatchCard(spacing: 8) {
                  Text(todo.task)
                     .font(.watchDisplay(20, relativeTo: .headline))
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
                  WatchActionGroup(title: "NanoDos", systemImage: "smallcircle.filled.circle", accent: WatchAppColor.main) {
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
                        store.archive(todo)
                     } label: {
                        Image(systemName: "archivebox")
                     }
                     .buttonStyle(WatchIconButtonStyle(fill: WatchAppColor.secondary, symbolSize: 17, symbolWeight: .black))
                     .accessibilityLabel("Archive")

                     Button {
                        store.trash(todo)
                     } label: {
                        Image(systemName: "trash")
                     }
                     .buttonStyle(WatchIconButtonStyle(fill: WatchAppColor.destructive, symbolSize: 17, symbolWeight: .black))
                     .accessibilityLabel("Trash")

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
                        Text(todo.createdAt.formatted(date: .abbreviated, time: .omitted))
                           .font(.watchBody(11, relativeTo: .caption2))
                     }
                     Spacer()
                     VStack(alignment: .trailing, spacing: 2) {
                        Text("Modified")
                           .font(.watchBodyStrong(10, relativeTo: .caption2))
                           .foregroundStyle(WatchAppColor.textSecondary)
                        Text(todo.updatedAt.formatted(date: .omitted, time: .shortened))
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
         .background(WatchAppColor.surfaceElevated)
      } else {
         Text("toDō not found.")
            .font(.watchBody(12, relativeTo: .caption))
      }
   }

   private func detailAccent(for item: WatchToDoItem) -> Color {
      item.isOverdue ? WatchAppColor.destructive : (item.isTimeSensitive ? WatchAppColor.destructive : WatchAppColor.actionPrimary)
   }

   private func formattedDetailDateTime(_ date: Date) -> String {
      WatchLocalization.dateTimeString(date)
   }
}

struct WatchNanoDoRow: View {
   let nanoDo: WatchNanoDoItem
   let onToggleDone: () -> Void
   let onDelete: () -> Void

   var body: some View {
      HStack(spacing: 8) {
         Button(action: onToggleDone) {
            Image(systemName: nanoDo.isDone ? "checkmark.circle.fill" : "circle")
               .font(.watchDisplay(16, relativeTo: .headline))
               .frame(width: 28, height: 28)
         }
         .buttonStyle(.plain)
         .foregroundStyle(nanoDo.isDone ? WatchAppColor.actionSuccess : WatchAppColor.textSecondary)
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

struct WatchDueReminderBanner: View {
   let item: WatchToDoItem
   let now: Date
   let onOpen: () -> Void
   let onDone: () -> Void
   let onSnooze: () -> Void
   let onDismiss: () -> Void

   var body: some View {
      VStack(alignment: .leading, spacing: 9) {
         HStack(spacing: 7) {
            Image(systemName: item.isTimeSensitive ? "bolt.fill" : "bell.badge.fill")
               .font(.watchBodyStrong(12, relativeTo: .caption))
               .foregroundStyle(WatchAppColor.onAction)
               .frame(width: 24, height: 24)
               .background(WatchAppColor.main, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
               Text("Due")
                  .font(.watchBodyStrong(10, relativeTo: .caption2))
                  .foregroundStyle(WatchAppColor.main)

               Text(dueText)
                  .font(.watchBodyStrong(11, relativeTo: .caption2))
                  .foregroundStyle(WatchAppColor.textSecondary)
            }

            Spacer(minLength: 0)

            Button(action: onDismiss) {
               Image(systemName: "xmark")
                  .font(.system(size: 14, weight: .bold))
                  .frame(width: 34, height: 34)
                  .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(WatchAppColor.textSecondary)
            .accessibilityLabel("Dismiss details")
         }

         Text(item.task)
            .font(.watchDisplay(16, relativeTo: .headline))
            .foregroundStyle(WatchAppColor.textPrimary)
            .lineLimit(2)

         HStack(spacing: 8) {
            Button(action: onDone) {
               Image(systemName: "checkmark")
                  .font(.system(size: 14, weight: .black, design: .rounded))
                  .frame(width: 32, height: 32)
            }
            .buttonStyle(WatchIconButtonStyle(fill: WatchAppColor.actionSuccess, symbolSize: 17, symbolWeight: .black))
            .accessibilityLabel("Done")

            Button(action: onSnooze) {
               Image(systemName: "arrow.clockwise")
                  .font(.system(size: 15, weight: .black, design: .rounded))
               .frame(width: 32, height: 32)
            }
            .buttonStyle(WatchIconButtonStyle(fill: WatchAppColor.white, foreground: WatchAppColor.black, symbolSize: 17, symbolWeight: .black))
            .accessibilityLabel("Snooze 15 minutes")

            Button(action: onOpen) {
               Image(systemName: "arrow.up.right")
                  .font(.system(size: 14, weight: .black, design: .rounded))
                  .frame(width: 32, height: 32)
            }
            .buttonStyle(WatchIconButtonStyle(fill: WatchAppColor.actionPrimary, symbolSize: 17, symbolWeight: .black))
            .accessibilityLabel("Open toDō")
         }
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
         RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(WatchAppColor.surfaceElevated)
            .shadow(color: .black.opacity(0.34), radius: 14, x: 0, y: 8)
      )
      .overlay(
         RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(item.isTimeSensitive ? WatchAppColor.destructive.opacity(0.75) : WatchAppColor.main.opacity(0.65), lineWidth: 1)
      )
   }

   private var dueText: String {
      guard let dueDate = item.dueDate else { return "" }
      if dueDate <= now {
         return dueDate.formatted(date: .omitted, time: .shortened)
      }
      return dueDate.formatted(date: .abbreviated, time: .shortened)
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
               systemImage: "arrow.up.right.circle.fill",
               accent: WatchAppColor.actionPrimary
            )

            WatchCard {
               TextField("toDō", text: $task, axis: .vertical)
                  .font(.watchDisplay(17, relativeTo: .headline))
                  .foregroundStyle(WatchAppColor.textPrimary)
                  .lineLimit(1...4)
                  .textInputAutocapitalization(.sentences)
            }

            WatchActionGroup(title: "Schedule", systemImage: "clock", accent: WatchAppColor.actionPrimary) {
               if dueDate == nil {
                  Button {
                     dueDate = defaultDueDate()
                  } label: {
                     Label("Add Due Date", systemImage: "calendar.badge.plus")
                  }
                  .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.actionPrimary))
               } else {
                  WatchPickerBlock(title: "Due Date", systemImage: "calendar", height: 118) {
                     DatePicker(
                        "Due Date",
                        selection: Binding(
                           get: { dueDate ?? defaultDueDate() },
                           set: { dueDate = merge(date: $0, withTimeFrom: dueDate) }
                        ),
                        displayedComponents: .date
                     )
                     .labelsHidden()
                     .tint(WatchAppColor.actionPrimary)
                  }

                  WatchPickerBlock(title: "Due Time", systemImage: "clock", height: 96) {
                     DatePicker(
                        "Due Time",
                        selection: Binding(
                           get: { dueDate ?? defaultDueDate() },
                           set: { dueDate = merge(time: $0, withDateFrom: dueDate) }
                        ),
                        displayedComponents: .hourAndMinute
                     )
                     .labelsHidden()
                     .tint(WatchAppColor.actionPrimary)
                  }

                  Button {
                     dueDate = nil
                     isTimeSensitive = false
                  } label: {
                     Label("Remove Due Date", systemImage: "calendar.badge.minus")
                  }
                  .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.textSecondary))
               }

               Toggle(isOn: $isTimeSensitive) {
                  Label("Time-Sensitive", systemImage: "bolt.fill")
                     .font(.watchBodyStrong(12, relativeTo: .caption))
               }
               .disabled(dueDate == nil)
               .tint(WatchAppColor.destructive)
            }

            Button {
               save()
            } label: {
               Label("Save", systemImage: "checkmark.circle.fill")
                  .font(.watchBodyStrong(14, relativeTo: .subheadline))
                  .frame(maxWidth: .infinity)
            }
            .buttonStyle(WatchProminentButtonStyle())
            .disabled(task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
         }
         .padding(.horizontal, 2)
         .padding(.bottom, 12)
      }
      .background(WatchAppColor.surface)
      .navigationTitle("Edit")
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
                              Image(systemName: "checkmark.circle.fill")
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
      HStack(spacing: 8) {
         Button(action: onToggleDone) {
            Image(systemName: item.isDone ? "arrow.uturn.backward" : "checkmark")
               .font(.watchBodyStrong(14, relativeTo: .caption))
               .frame(width: 34, height: 34)
         }
         .buttonStyle(WatchIconButtonStyle(
            fill: item.isDone ? WatchAppColor.secondary : WatchAppColor.actionSuccess,
            size: 34
         ))
         .accessibilityLabel(item.isDone ? "Mark Active" : "Mark Done")

         Button(action: onOpen) {
            WatchToDoRow(item: item, accent: accent)
         }
         .buttonStyle(.plain)
         .accessibilityLabel(item.task)
         .accessibilityHint("Opens this toDō.")
      }
      .frame(maxWidth: .infinity, alignment: .leading)
   }
}

struct WatchToDoRow: View {
   let item: WatchToDoItem
   let accent: Color

   var body: some View {
      HStack(alignment: .center, spacing: 9) {
         VStack(alignment: .leading, spacing: 3) {
            Text(item.task)
               .font(.watchDisplay(16, relativeTo: .headline))
               .foregroundStyle(taskTextColor)
               .lineLimit(2)
               .strikethrough(item.isDone)

            HStack(spacing: 5) {
               if let dueDate = item.dueDate {
                  Text(formattedDueText(dueDate))
               } else if !item.isDone {
                  Text("No Due Date")
               }

               if item.isTimeSensitive {
                  Image(systemName: "exclamationmark.circle.fill")
               }
            }
            .font(.watchBodyStrong(11, relativeTo: .caption2))
            .foregroundStyle(metadataColor)
         }

         Spacer(minLength: 0)

         Image(systemName: "chevron.right")
            .font(.watchBodyStrong(9, relativeTo: .caption2))
            .foregroundStyle(WatchAppColor.textSecondary.opacity(0.7))
            .padding(.top, 5)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 9)
      .background(rowBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
      .overlay(
         RoundedRectangle(cornerRadius: 17, style: .continuous)
            .stroke(rowBorderColor, lineWidth: rowBorderWidth)
            .padding(item.isTimeSensitive && !item.isDone ? 2 : 0)
      )
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
            .font(.watchDisplay(17, relativeTo: .headline))
            .foregroundStyle(accent)
            .frame(width: 30, height: 30)
            .background(accent.opacity(0.16), in: Circle())

         VStack(alignment: .leading, spacing: 1) {
            Text(title)
               .font(.watchDisplay(21, relativeTo: .title3))
               .foregroundStyle(WatchAppColor.textPrimary)

            if let subtitle, !subtitle.isEmpty {
               Text(subtitle)
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
      .overlay(
         RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(WatchAppColor.border, lineWidth: 1)
      )
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
            Text(title)
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
         Label(title, systemImage: systemImage)
            .font(.watchBodyStrong(10, relativeTo: .caption2))
            .foregroundStyle(WatchAppColor.textSecondary)

         content
            .frame(maxWidth: .infinity)
            .frame(height: height)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
   }
}

struct WatchActionGroup<Content: View>: View {
   let title: String
   let systemImage: String
   let accent: Color
   @ViewBuilder let content: Content

   var body: some View {
      VStack(alignment: .leading, spacing: 7) {
         Label(title, systemImage: systemImage)
            .font(.watchDisplay(14, relativeTo: .subheadline))
            .foregroundStyle(accent)
            .padding(.horizontal, 4)

         WatchCard(spacing: 7) {
            content
         }
      }
   }
}

struct WatchProminentButtonStyle: ButtonStyle {
   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .foregroundStyle(WatchAppColor.onAction)
         .padding(.vertical, 9)
         .padding(.horizontal, 12)
         .background(
            Capsule(style: .continuous)
               .fill(configuration.isPressed ? WatchAppColor.secondary : WatchAppColor.actionPrimary)
         )
         .scaleEffect(configuration.isPressed ? 0.96 : 1)
         .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
   }
}

struct WatchFilledButtonStyle: ButtonStyle {
   let fill: Color

   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .font(.watchBodyStrong(13, relativeTo: .caption))
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

struct WatchSoftButtonStyle: ButtonStyle {
   let accent: Color

   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .font(.watchBodyStrong(12, relativeTo: .caption))
         .foregroundStyle(accent)
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(.vertical, 8)
         .padding(.horizontal, 10)
         .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
               .fill(configuration.isPressed ? accent.opacity(0.24) : accent.opacity(0.13))
         )
         .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
               .stroke(accent.opacity(configuration.isPressed ? 0.35 : 0.18), lineWidth: 1)
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
