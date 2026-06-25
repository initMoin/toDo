import SwiftUI
import SwiftData
import Combine
import CoreLocation
import MapKit

struct ToDoLifecycleActionBar: View {
   @Environment(\.appDifferentiatesWithoutColor) private var differentiatesWithoutColor

   let isDone: Bool
   let removalAction: AppPreferences.DoneSwipePrimaryAction
   var includesRemovalAction = true
   var includesSnooze = false
   let onRemoval: () -> Void
   let onSnooze: () -> Void
   let onToggleDone: () -> Void

   var body: some View {
      if #available(iOS 26, *) {
         GlassEffectContainer(spacing: 16) {
            controls
         }
         .frame(maxWidth: .infinity, alignment: .center)
         .padding(.horizontal, 20)
      } else {
         controls
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppColor.surfaceElevated, in: Capsule())
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 18)
      }
   }

   private var controls: some View {
      HStack(spacing: 14) {
         if includesSnooze {
            lifecycleActionButton(
               systemName: "clock.arrow.circlepath",
               accessibilityLabel: "Snooze toDō",
               foreground: AppColor.onAction,
               background: AppColor.actionPrimary,
               action: onSnooze
            )
         }

         if includesRemovalAction {
            lifecycleActionButton(
               systemName: removalAction.systemImage,
               accessibilityLabel: LocalizedStringKey(removalAction.accessibilityLabel),
               foreground: AppColor.onAction,
               background: removalAction == .delete ? AppColor.actionDestructive : AppColor.actionSecondary,
               action: onRemoval
            )
         }

         lifecycleActionButton(
            systemName: isDone ? "arrow.uturn.backward" : "checkmark",
            accessibilityLabel: isDone ? "Mark toDō active" : "Mark toDō done",
            foreground: AppColor.onAction,
            background: isDone ? AppColor.actionPrimary : AppColor.actionSuccess,
            action: onToggleDone
         )
      }
   }

   private func lifecycleActionButton(
      systemName: String,
      accessibilityLabel: LocalizedStringKey,
      foreground: Color,
      background: Color,
      action: @escaping () -> Void
   ) -> some View {
      Button(action: action) {
         ZStack(alignment: .bottomTrailing) {
            Image(systemName: systemName)
               .font(.appDisplay(18, relativeTo: .headline))
               .foregroundStyle(foreground)
               .frame(width: 34, height: 34)
               .background {
                  if #unavailable(iOS 26) {
                     Circle().fill(background)
                  }
               }
               .appInteractiveCircleGlass(tint: background)
               .contentShape(Circle())
               .overlay {
                  if differentiatesWithoutColor {
                     Circle()
                        .strokeBorder(foreground, style: StrokeStyle(lineWidth: 2.5, dash: [4, 3]))
                  }
               }

            if differentiatesWithoutColor {
               Image(systemName: "checkmark")
                  .font(.system(size: 8, weight: .black))
                  .foregroundStyle(foreground)
                  .padding(3)
                  .background(background, in: Circle())
                  .accessibilityHidden(true)
            }
         }
      }
      .buttonStyle(.plain)
      .accessibilityLabel(accessibilityLabel)
      .accessibilityInputLabels([Text(accessibilityLabel)])
   }
}

struct TagPillFlowLayout: Layout {
   var spacing: CGFloat
   var rowSpacing: CGFloat

   func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
      let maxWidth = proposal.width ?? .greatestFiniteMagnitude
      var x: CGFloat = 0
      var y: CGFloat = 0
      var rowHeight: CGFloat = 0
      var usedWidth: CGFloat = 0

      for subview in subviews {
         let size = subview.sizeThatFits(.unspecified)
         let nextX = x == 0 ? size.width : x + spacing + size.width

         if nextX > maxWidth, x > 0 {
            usedWidth = max(usedWidth, x)
            x = size.width
            y += rowHeight + rowSpacing
            rowHeight = size.height
         } else {
            x = nextX
            rowHeight = max(rowHeight, size.height)
         }
      }

      usedWidth = max(usedWidth, x)
      return CGSize(width: proposal.width ?? usedWidth, height: y + rowHeight)
   }

   func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
      let maxX = bounds.maxX
      var x = bounds.minX
      var y = bounds.minY
      var rowHeight: CGFloat = 0

      for subview in subviews {
         let size = subview.sizeThatFits(.unspecified)
         let needsWrap = x > bounds.minX && (x + spacing + size.width > maxX)
         if needsWrap {
            x = bounds.minX
            y += rowHeight + rowSpacing
            rowHeight = 0
         } else if x > bounds.minX {
            x += spacing
         }

         subview.place(
            at: CGPoint(x: x, y: y),
            proposal: ProposedViewSize(width: size.width, height: size.height)
         )
         x += size.width
         rowHeight = max(rowHeight, size.height)
      }
   }
}

struct NanoDoReadOnlyRowView: View {
   let nanoDo: NanoDo

   var body: some View {
      VStack(alignment: .leading, spacing: 4) {
         HStack(spacing: 8) {
            Image(systemName: nanoDo.isDone ? "checkmark.circle.fill" : "circle")
               .foregroundStyle(nanoDo.isDone ? AppColor.actionPrimary : AppColor.textSecondary)
            Text(nanoDo.task)
               .foregroundStyle(AppColor.textPrimary)
         }

         if let dueDate = nanoDo.dueDate {
            Text(AppLocalization.dateTimeString(dueDate))
               .font(.appBody(12, relativeTo: .caption))
               .foregroundStyle(AppColor.textSecondary)
         }
      }
   }
}

struct ToDoDueDateCalendar: View {
   @Binding var selection: Date?
   @State private var visibleMonth: Date
   @Environment(\.colorScheme) private var colorScheme

   private let calendar = AppLocalization.displayCalendar
   private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

   init(selection: Binding<Date?>) {
      _selection = selection
      _visibleMonth = State(initialValue: Self.monthStart(for: selection.wrappedValue ?? .now))
   }

   var body: some View {
      VStack(spacing: 12) {
         HStack(spacing: 12) {
            Button {
               moveMonth(by: -1)
            } label: {
               Image(systemName: "chevron.left")
                  .font(.appBodyStrong(13, relativeTo: .caption))
                  .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")

            Text(AppLocalization.monthYearString(visibleMonth))
               .font(.appDisplay(17, relativeTo: .headline))
               .foregroundStyle(AppColor.textPrimary)
               .frame(maxWidth: .infinity)

            Button {
               moveMonth(by: 1)
            } label: {
               Image(systemName: "chevron.right")
                  .font(.appBodyStrong(13, relativeTo: .caption))
                  .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")
         }
         .foregroundStyle(AppColor.textSecondary)

         LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
               Text(symbol)
                  .font(.appBodyStrong(11, relativeTo: .caption2))
                  .foregroundStyle(AppColor.textSecondary)
                  .frame(height: 24)
            }

            ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
               if let date {
                  dayButton(for: date)
               } else {
                  Color.clear
                     .frame(width: 34, height: 34)
               }
            }
         }
      }
      .padding(12)
      .background(AppColor.surfaceMuted, in: .rect(cornerRadius: 18))
      .onChange(of: selection) { _, newValue in
         if let newValue,
            !calendar.isDate(newValue, equalTo: visibleMonth, toGranularity: .month) {
            visibleMonth = Self.monthStart(for: newValue)
         }
      }
   }

   private func dayButton(for date: Date) -> some View {
      let isSelected = selection.map { calendar.isDate($0, inSameDayAs: date) } ?? false
      let isToday = calendar.isDateInToday(date)

      return Button {
         withAnimation(AppAnimation.easeFast) {
            selection = isSelected ? nil : date
         }
      } label: {
         Text(dayNumber(for: date))
            .font(isSelected ? .appSubtitle(16, relativeTo: .headline) : .appBodyStrong(15, relativeTo: .subheadline))
            .foregroundStyle(dayTextColor(isSelected: isSelected, isToday: isToday))
            .frame(width: 34, height: 34)
            .background {
               if isSelected {
                  Circle()
                     .fill(AppColor.main)
                     .shadow(color: AppColor.main.opacity(0.24), radius: 8, y: 4)
               }
            }
            .overlay {
               if isToday && !isSelected {
                  Circle()
                     .stroke(AppColor.main, lineWidth: 1.5)
               }
            }
            .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(AppLocalization.completeDateString(date))
      .accessibilityAddTraits(isSelected ? .isSelected : [])
   }

   private var weekdaySymbols: [String] {
      let symbols = calendar.veryShortStandaloneWeekdaySymbols
      let firstWeekdayIndex = max(calendar.firstWeekday - 1, 0)
      return Array(symbols[firstWeekdayIndex...]) + Array(symbols[..<firstWeekdayIndex])
   }

   private var monthDays: [Date?] {
      guard let range = calendar.range(of: .day, in: .month, for: visibleMonth),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth)) else {
         return []
      }

      let weekday = calendar.component(.weekday, from: firstDay)
      let leadingEmptyDays = (weekday - calendar.firstWeekday + 7) % 7
      let dates = range.compactMap { day -> Date? in
         calendar.date(byAdding: .day, value: day - 1, to: firstDay)
      }

      return Array(repeating: nil, count: leadingEmptyDays) + dates
   }

   private func dayNumber(for date: Date) -> String {
      AppLocalization.dayNumberString(date)
   }

   private func dayTextColor(isSelected: Bool, isToday: Bool) -> Color {
      if isSelected {
         return AppColor.brandYellowForeground(for: colorScheme)
      }

      return isToday ? AppColor.textPrimary : AppColor.textSecondary
   }

   private func moveMonth(by value: Int) {
      withAnimation(AppAnimation.easeFast) {
         visibleMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
      }
   }

   private static func monthStart(for date: Date) -> Date {
      let calendar = AppLocalization.displayCalendar
      return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
   }
}

struct NanoDoRowView: View {
   @Environment(\.modelContext) private var context
   @Bindable var nanoDo: NanoDo
   var allowsTextEditing = true
   var completesParentImmediately = true
   var onMutation: () -> Void = {}
   let onDelete: () -> Void

   var body: some View {
      VStack(alignment: .leading, spacing: 10) {
         HStack(alignment: .top, spacing: 10) {
            Button {
               HapticFeedbackService.play(nanoDo.isDone ? .taskReopened : .taskCompleted)
               withAnimation(AppAnimation.easeFast) {
                  nanoDo.isDone.toggle()
                  nanoDo.markUpdated()
                  if completesParentImmediately {
                     let completedParent = nanoDo.toDo?.completeIfAllNanoDosAreDone() ?? false
                     if completedParent, let parent = nanoDo.toDo {
                        LiveActivityService.shared.endActivity(for: parent)
                     }
                  }
                  // Update the parent before saving so child and parent state
                  // are persisted and synced as one mutation.
                  onMutation()
                  try? context.save()
                  NotificationManager.shared.scheduleRefresh()
                  WidgetSnapshotService.shared.writeSnapshot(from: context)
                  SyncCoordinator.shared.scheduleLocalSync()
               }
            } label: {
               Image(systemName: nanoDo.isDone ? "checkmark.circle.fill" : "circle")
                  .font(.appDisplay(23, relativeTo: .headline))
                  .foregroundStyle(nanoDo.isDone ? AppColor.actionPrimary : AppColor.textSecondary)
                  .frame(width: 34, height: 34)
                  .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(nanoDo.isDone ? "Mark nanoDo active" : "Mark nanoDo done")
            .accessibilityInputLabels([
               Text(nanoDo.isDone ? "Mark nanoDo active" : "Mark nanoDo done"),
               Text(nanoDo.isDone ? "Reopen nanoDo" : "Complete nanoDo")
            ])

            if allowsTextEditing {
               TextField("NanoDo", text: Binding(
                  get: { nanoDo.task },
                  set: {
                     nanoDo.task = $0
                     nanoDo.markUpdated()
                     SyncCoordinator.shared.scheduleLocalSync()
                     onMutation()
                  }
               ))
               .font(.appUserEntry(18, relativeTo: .headline))
               .foregroundStyle(nanoDo.isDone ? AppColor.textSecondary : AppColor.textPrimary)
               .strikethrough(nanoDo.isDone, color: AppColor.textSecondary.opacity(0.6))
            } else {
               Text(nanoDo.task)
                  .font(.appDisplay(18, relativeTo: .headline))
                  .foregroundStyle(nanoDo.isDone ? AppColor.textSecondary : AppColor.textPrimary)
                  .strikethrough(nanoDo.isDone, color: AppColor.textSecondary.opacity(0.6))
                  .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if allowsTextEditing {
               Button(role: .destructive) {
                  onDelete()
               } label: {
                  Image(systemName: "trash")
                     .frame(width: 26, height: 26)
               }
               .buttonStyle(AppOutlinedIconButtonStyle(tint: AppColor.actionDestructive, size: 28, symbolSize: 12, lineWidth: 2))
               .accessibilityLabel("Delete nanoDo")
               .accessibilityInputLabels([
                  Text("Delete nanoDo"),
                  Text("Remove nanoDo")
               ])
            }
         }

         HStack(spacing: 10) {
            if let dueDate = nanoDo.dueDate {
               Image(systemName: "calendar")
                  .font(.appBodyStrong(12, relativeTo: .caption))
                  .foregroundStyle(AppColor.actionPrimary)

               DatePicker("Due", selection: Binding(
                  get: { dueDate },
                  set: {
                     nanoDo.dueDate = $0
                     nanoDo.markUpdated()
                     NotificationManager.shared.scheduleRefresh()
                     SyncCoordinator.shared.scheduleLocalSync()
                     onMutation()
                  }
               ), displayedComponents: [.date, .hourAndMinute])
               .labelsHidden()
               .datePickerStyle(.compact)
               .font(.appBodyStrong(12, relativeTo: .caption))
               .tint(AppColor.actionPrimary)

               Button {
                  nanoDo.dueDate = nil
                  nanoDo.markUpdated()
                  NotificationManager.shared.scheduleRefresh()
                  SyncCoordinator.shared.scheduleLocalSync()
                  onMutation()
               } label: {
                  Image(systemName: "xmark.circle.fill")
                     .font(.appBodyStrong(13, relativeTo: .caption))
               }
               .buttonStyle(.plain)
               .foregroundStyle(AppColor.textSecondary)
               .accessibilityLabel("Clear due date")
            } else {
               Button {
                  nanoDo.dueDate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
                  nanoDo.markUpdated()
                  NotificationManager.shared.scheduleRefresh()
                  SyncCoordinator.shared.scheduleLocalSync()
                  onMutation()
               } label: {
                  Label("Add due date", systemImage: "calendar.badge.plus")
                     .font(.appBodyStrong(13, relativeTo: .caption))
               }
               .buttonStyle(.plain)
               .foregroundStyle(AppColor.actionPrimary)
            }
         }
         .padding(.leading, 40)
         .font(.appBodyStrong(12, relativeTo: .caption))
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AppColor.surfaceElevated.opacity(nanoDo.isDone ? 0.62 : 0.92), in: .rect(cornerRadius: 18))
      .overlay(
         RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(AppColor.secondary.opacity(nanoDo.isDone ? 0.12 : 0.22), lineWidth: 1)
      )
      .opacity(nanoDo.isDone ? 0.72 : 1)
   }
}

struct SwipeableNanoDoRow: View {
   @Bindable var nanoDo: NanoDo
   var completesParentImmediately = true
   var onMutation: () -> Void = {}
   let onDelete: () -> Void
   @State private var dragOffset: CGFloat = 0

   private let actionWidth: CGFloat = 58

   var body: some View {
      ZStack(alignment: .trailing) {
         Button(role: .destructive) {
            close()
            onDelete()
         } label: {
            Image(systemName: "trash")
               .font(.appDisplay(13, relativeTo: .footnote))
               .foregroundStyle(AppColor.onAction)
               .frame(width: 38, height: 38)
               .background {
                  if #unavailable(iOS 26.0) {
                     Circle()
                        .fill(AppColor.actionDestructive)
                  }
               }
               .appInteractiveCircleGlass(tint: AppColor.actionDestructive)
         }
         .padding(.trailing, 10)
         .buttonStyle(.plain)
         .accessibilityLabel("Delete nanoDo")
         .accessibilityInputLabels([
            Text("Delete nanoDo"),
            Text("Remove nanoDo")
         ])

         NanoDoRowView(
            nanoDo: nanoDo,
            allowsTextEditing: false,
            completesParentImmediately: completesParentImmediately,
            onMutation: onMutation
         ) {
            onDelete()
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .offset(x: dragOffset)
         .gesture(
            DragGesture(minimumDistance: 12)
               .onChanged { value in
                  let proposed = value.translation.width
                  dragOffset = min(0, max(-actionWidth, proposed))
               }
               .onEnded { value in
                  if value.translation.width < -(actionWidth + 26) {
                     close()
                     onDelete()
                  } else if value.translation.width < -24 {
                     reveal()
                  } else {
                     close()
                  }
               }
         )
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .animation(AppAnimation.easeFast, value: dragOffset)
   }

   private func reveal() {
      dragOffset = -actionWidth
   }

   private func close() {
      dragOffset = 0
   }
}

@MainActor
final class LocationReminderPlaceSearch: NSObject, ObservableObject {
   struct Selection {
      let title: String
      let subtitle: String
      let coordinate: CLLocationCoordinate2D

      var displayText: String {
         subtitle.isEmpty ? title : "\(title), \(subtitle)"
      }
   }

   @Published var query: String = "" {
      didSet {
         let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
         guard trimmedQuery.count >= 2 else {
            completer.queryFragment = ""
            completions = []
            isSearching = false
            return
         }

         isSearching = true
         completer.queryFragment = trimmedQuery
      }
   }

   @Published var completions: [MKLocalSearchCompletion] = []
   @Published private(set) var selectedPlace: Selection?
   @Published private(set) var isSearching = false

   private let completer = MKLocalSearchCompleter()

   override init() {
      super.init()
      completer.resultTypes = [.address, .pointOfInterest]
      completer.delegate = self
   }

   func resolve(_ completion: MKLocalSearchCompletion) async {
      isSearching = true
      defer { isSearching = false }

      let request = MKLocalSearch.Request(completion: completion)
      let search = MKLocalSearch(request: request)

      do {
         guard let mapItem = try await search.start().mapItems.first else { return }
         selectedPlace = Selection(
            title: mapItem.name ?? completion.title,
            subtitle: completion.subtitle,
            coordinate: mapItem.location.coordinate
         )
      } catch {
         selectedPlace = nil
      }
   }
}

extension LocationReminderPlaceSearch: MKLocalSearchCompleterDelegate {
   func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
      completions = completer.results
      isSearching = false
   }

   func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
      completions = []
      isSearching = false
   }
}

#Preview {
   NavigationStack {
      ToDoView(mode: .create(preselectedTagID: nil))
   }
   .modelContainer(PreviewSupport.makeModelContainer())
   .environmentObject(SupabaseAuthStore.preview)
}

#Preview("iPad Inline Edit") {
   ToDoView(
      mode: .create(preselectedTagID: nil),
      isInlineOverlayEdit: true
   )
   .frame(width: 720, height: 820)
   .modelContainer(PreviewSupport.makeModelContainer())
   .environmentObject(SupabaseAuthStore.preview)
}
