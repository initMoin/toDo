import SwiftUI
import AuthenticationServices

struct WatchAccountView: View {
   @ObservedObject var authStore: WatchAuthStore
   @ObservedObject var store: WatchToDoStore

   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 12) {
            WatchScreenHeader(
               title: "Settings",
               subtitle: authStore.authState.title,
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
      }
   }

   @ViewBuilder
   private var doneToDosCard: some View {
      if !store.recentlyDoneItems.isEmpty {
         WatchActionGroup(title: "Done", systemImage: "checkmark.circle.fill", accent: WatchAppColor.actionSuccess) {
            ForEach(store.recentlyDoneItems) { item in
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

struct WatchSnoozeOptionsView: View {
   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 12) {
            WatchScreenHeader(
               title: "Snooze Options",
               subtitle: "Presets for due ToDos",
               systemImage: "zzz",
               accent: WatchAppColor.secondary
            )

            ForEach(WatchSnoozeUnit.allCases) { unit in
               WatchActionGroup(title: unit.title, systemImage: "clock", accent: WatchAppColor.secondary) {
                  ForEach(Array(unit.values.enumerated()), id: \.offset) { _, value in
                     WatchMetadataRow(
                        systemImage: "timer",
                        title: unit.label(for: value),
                        value: "Available from any due ToDo",
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
               Button {
                  store.select(item)
               } label: {
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
   @Environment(\.dismiss) private var dismiss
   @State private var task = ""
   @State private var dueDate: Date?
   @State private var isTimeSensitive = false

   var body: some View {
      ScrollView {
         VStack(alignment: .leading, spacing: 12) {
            WatchScreenHeader(
               title: "New ToDo",
               subtitle: "Capture one focus at a time.",
               systemImage: "plus.circle.fill",
               accent: WatchAppColor.actionPrimary
            )

            WatchCard {
               TextField("What do you want toDo?", text: $task, axis: .vertical)
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
               Label("Add ToDo", systemImage: "checkmark.circle.fill")
                  .font(.watchBodyStrong(14, relativeTo: .subheadline))
                  .frame(maxWidth: .infinity)
            }
            .buttonStyle(WatchProminentButtonStyle())
            .disabled(task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
         }
         .padding(.horizontal, 2)
         .padding(.bottom, 12)
      }
      .navigationTitle("New ToDo")
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
   @Environment(\.dismiss) private var dismiss

   private var todo: WatchToDoItem? {
      store.items.first { $0.id == item.id } ?? item
   }

   var body: some View {
      if let todo = todo {
         ScrollView {
            VStack(alignment: .leading, spacing: 12) {
               WatchScreenHeader(
                  title: todo.isDone ? "Done" : "Active",
                  subtitle: "Focus on one task",
                  systemImage: todo.isDone ? "checkmark.circle.fill" : "circle",
                  accent: todo.isDone ? WatchAppColor.actionSuccess : detailAccent(for: todo)
               )

               WatchCard(spacing: 8) {
                  Text(todo.task)
                     .font(.watchDisplay(20, relativeTo: .headline))
                     .foregroundStyle(WatchAppColor.textPrimary)
                     .strikethrough(todo.isDone)

                  if let dueDate = todo.dueDate {
                     WatchMetadataRow(
                        systemImage: "calendar",
                        title: "Due",
                        value: dueDate.formatted(date: .abbreviated, time: .shortened),
                        accent: WatchAppColor.actionPrimary
                     )
                  }

                  if todo.isTimeSensitive {
                     WatchMetadataRow(
                        systemImage: "bolt.fill",
                        title: "Priority",
                        value: "Time-Sensitive",
                        accent: WatchAppColor.destructive
                     )
                  }
               }

               WatchCard(spacing: 8) {
                  Button {
                     todo.isDone ? store.reopen(todo) : store.complete(todo)
                  } label: {
                     Label(todo.isDone ? "Reopen" : "Complete",
                           systemImage: todo.isDone ? "arrow.uturn.backward" : "checkmark.circle.fill")
                     .frame(maxWidth: .infinity)
                  }
                  .buttonStyle(WatchFilledButtonStyle(fill: todo.isDone ? WatchAppColor.secondary : WatchAppColor.actionSuccess))

                  if !todo.isDone {
                     NavigationLink {
                        WatchSnoozePickerView(item: todo, store: store)
                     } label: {
                        Label("Snooze", systemImage: "zzz")
                     }
                     .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.actionSecondary))
                  }
               }

               WatchActionGroup(title: "Schedule", systemImage: "clock", accent: WatchAppColor.actionPrimary) {
                  if todo.dueDate == nil {
                     Button {
                        store.setDueDate(defaultDueDate(), for: todo)
                     } label: {
                        Label("Add Due Date", systemImage: "calendar.badge.plus")
                     }
                     .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.actionPrimary))
                  } else {
                     WatchPickerBlock(title: "Due Date", systemImage: "calendar", height: 118) {
                        DatePicker(
                           "Due Date",
                           selection: Binding(
                              get: { todo.dueDate ?? defaultDueDate() },
                              set: { store.setDueDate(merge(date: $0, withTimeFrom: todo.dueDate), for: todo) }
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
                              get: { todo.dueDate ?? defaultDueDate() },
                              set: { store.setDueDate(merge(time: $0, withDateFrom: todo.dueDate), for: todo) }
                           ),
                           displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .tint(WatchAppColor.actionPrimary)
                     }

                     Button {
                        store.setDueDate(nil, for: todo)
                     } label: {
                        Label("Remove Due Date", systemImage: "calendar.badge.minus")
                     }
                     .buttonStyle(WatchSoftButtonStyle(accent: WatchAppColor.textSecondary))
                  }

                  Toggle(isOn: Binding(
                     get: { todo.isTimeSensitive },
                     set: { store.setDueDate(todo.dueDate, for: todo, isTimeSensitive: $0) }
                  )) {
                     Label("Time-Sensitive", systemImage: "bolt.fill")
                        .font(.watchBodyStrong(12, relativeTo: .caption))
                  }
                  .tint(WatchAppColor.destructive)
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
            .padding(.horizontal, 2)
            .padding(.bottom, 12)
         }
         .background(WatchAppColor.surface)
      } else {
         Text("ToDo not found.")
            .font(.watchBody(12, relativeTo: .caption))
      }
   }

   private func detailAccent(for item: WatchToDoItem) -> Color {
      item.isOverdue ? WatchAppColor.destructive : (item.isTimeSensitive ? WatchAppColor.destructive : WatchAppColor.actionPrimary)
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

struct WatchToDoRow: View {
   let item: WatchToDoItem
   let accent: Color

   var body: some View {
      HStack(alignment: .center, spacing: 9) {
         Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
            .font(.watchDisplay(18, relativeTo: .headline))
            .foregroundStyle(leadingColor)
            .frame(width: 20, height: 20)

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
      .padding(.horizontal, 11)
      .padding(.vertical, 9)
      .background(rowBackground, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
      .overlay(
         RoundedRectangle(cornerRadius: 17, style: .continuous)
            .stroke(rowBorderColor, lineWidth: rowBorderWidth)
            .padding(item.isTimeSensitive && !item.isDone ? 2 : 0)
      )
   }

   private var leadingColor: Color {
      if item.isDone {
         return WatchAppColor.actionSuccess
      }
      if item.isOverdue {
         return WatchAppColor.white
      }
      if item.isTimeSensitive {
         return WatchAppColor.destructive
      }
      return accent
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
         return "Today " + date.formatted(date: .omitted, time: .shortened)
      } else if cal.isDateInTomorrow(date) {
         return "Tomorrow " + date.formatted(date: .omitted, time: .shortened)
      } else {
         return date.formatted(date: .abbreviated, time: .shortened)
      }
   }
}

struct WatchScreenHeader: View {
   let title: String
   let subtitle: String
   let systemImage: String
   let accent: Color

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

            Text(subtitle)
               .font(.watchBody(11, relativeTo: .caption2))
               .foregroundStyle(WatchAppColor.textSecondary)
               .lineLimit(2)
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
