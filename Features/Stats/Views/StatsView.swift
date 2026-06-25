import SwiftUI
import SwiftData

struct StatsView: View {
   @Environment(\.dismiss) private var dismiss
   @Environment(\.colorScheme) private var colorScheme
   @Environment(\.horizontalSizeClass) private var horizontalSizeClass
   @Environment(\.appReduceMotion) private var reduceMotion
   @AppStorage(AppPreferences.Keys.statsInsightsEnabled) private var statsInsightsEnabled = false
   @AppStorage(AppPreferences.Keys.appleIntelligenceEnabled) private var appleIntelligenceEnabled = false
   @Query private var toDos: [ToDo]
   @Query private var nanoDos: [NanoDo]
   @Query private var tags: [Tag]

   private let ownerUserID: UUID?

   init(ownerUserID: UUID? = nil) {
      self.ownerUserID = ownerUserID
   }

   private var scopedToDos: [ToDo] {
      toDos.filter { $0.ownerUserID == ownerUserID }
   }

   private var scopedNanoDos: [NanoDo] {
      nanoDos.filter { $0.ownerUserID == ownerUserID }
   }

   private var scopedTags: [Tag] {
      tags.filter { $0.ownerUserID == ownerUserID }
   }

   private var snapshot: ToDoStatsSnapshot {
      ToDoStatsSnapshot(toDos: scopedToDos, nanoDos: scopedNanoDos, tags: scopedTags)
   }

   var body: some View {
      let currentSnapshot = snapshot

      ZStack(alignment: .top) {
         AppColor.surface
            .ignoresSafeArea()

         ScrollView {
            VStack(alignment: .leading, spacing: 18) {
               StatsHeroCard(snapshot: currentSnapshot)
               StatsFocusGrid(snapshot: currentSnapshot)

               if usesRegularWidthLayout {
                  LazyVGrid(columns: statsBoardColumns, alignment: .center, spacing: 18) {
                     StatsMomentumCard(snapshot: currentSnapshot)
                     StatsWorkloadCard(snapshot: currentSnapshot)
                     StatsTagCard(snapshot: currentSnapshot)
                     StatsTrendCard(snapshot: currentSnapshot)
                     StatsPlanningCard(snapshot: currentSnapshot)
                     StatsPressureCard(snapshot: currentSnapshot)
                  }
               } else {
                  StatsMomentumCard(snapshot: currentSnapshot)
                  StatsWorkloadCard(snapshot: currentSnapshot)
                  StatsTagCard(snapshot: currentSnapshot)
                  StatsTrendCard(snapshot: currentSnapshot)
                  StatsPlanningCard(snapshot: currentSnapshot)
                  StatsPressureCard(snapshot: currentSnapshot)
               }

               StatsInsightCard(
                  snapshot: currentSnapshot,
                  isEnabled: $statsInsightsEnabled,
                  isAppleIntelligenceEnabled: $appleIntelligenceEnabled
               )
            }
            .frame(maxWidth: statsContentMaxWidth, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 28)
         }
      }
      .background(AppColor.surface)
      .appBaseTypography()
      .settingsNativeNavigationTitle("Stats", colorScheme: colorScheme, background: AppColor.secondary)
      .appReducedMotionBackButton(enabled: reduceMotion)
      .accessibilityIdentifier("stats.view")
   }

   private var usesRegularWidthLayout: Bool {
      horizontalSizeClass == .regular
   }

   private var statsContentMaxWidth: CGFloat {
      usesRegularWidthLayout ? 1040 : .infinity
   }

   private var statsBoardColumns: [GridItem] {
      [
         GridItem(.flexible(minimum: 320, maximum: 500), spacing: 18, alignment: .top),
         GridItem(.flexible(minimum: 320, maximum: 500), spacing: 18, alignment: .top)
      ]
   }
}

private struct ToDoStatsSnapshot {
   let totalToDos: Int
   let activeToDos: Int
   let completedToDos: Int
   let archivedToDos: Int
   let trashedToDos: Int
   let overdueToDos: Int
   let dueTodayToDos: Int
   let scheduledToDos: Int
   let timeSensitiveToDos: Int
   let recurringToDos: Int
   let locationReminderToDos: Int
   let openNanoDos: Int
   let completedNanoDos: Int
   let createdThisWeek: Int
   let completedThisWeek: Int
   let completedThisMonth: Int
   let completionRate: Double
   let dueDateCoverage: Double
   let nanoDoCompletionRate: Double
   let averageNanoDosPerActiveToDo: Double
   let mostUsedTagName: String?
   let mostUsedTagCount: Int
   let oldestActiveAgeInDays: Int?
   let completedLastSevenDays: Int
   let completedDailyAverage: Double
   let onTimeCompletedDueToDos: Int
   let lateCompletedDueToDos: Int
   let noDueCompletedToDos: Int
   let activeToDosWithNanoDos: Int
   let activeToDosWithoutNanoDos: Int
   let completionRateWithNanoDos: Double
   let completionRateWithoutNanoDos: Double
   let recurringCompletedLastThirtyDays: Int
   let overdueRecurringToDos: Int
   let staleSevenDays: Int
   let staleFourteenDays: Int
   let staleThirtyDays: Int
   let focusPressureScore: Int
   let overduePatternLabel: String
   let topActiveTagName: String?
   let topActiveTagCount: Int

   init(toDos: [ToDo], nanoDos: [NanoDo], tags: [Tag], now: Date = .now) {
      let calendar = Calendar.current
      let weekStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
      let monthStart = calendar.date(byAdding: .day, value: -30, to: now) ?? now
      let active = toDos.filter(\.isActive)
      let completed = toDos.filter { $0.lifecycleState == .done }
      let scheduled = active.filter { $0.dueDate != nil }
      let dueCompleted = completed.filter { $0.dueDate != nil }
      let noDueCompleted = completed.filter { $0.dueDate == nil }
      let activeWithNanoDos = active.filter { !$0.nanoDos.isEmpty }
      let activeWithoutNanoDos = active.filter { $0.nanoDos.isEmpty }
      let withNanoDos = toDos.filter { !$0.nanoDos.isEmpty && $0.lifecycleState != .trashed }
      let withoutNanoDos = toDos.filter { $0.nanoDos.isEmpty && $0.lifecycleState != .trashed }
      let nanoTotal = nanoDos.count
      let nanoCompleted = nanoDos.filter(\.isDone).count
      let tagUsage = Self.tagUsage(from: toDos)
      let activeTagUsage = Self.tagUsage(from: active)
      let topTag = tagUsage.max { lhs, rhs in
         if lhs.value == rhs.value { return lhs.key > rhs.key }
         return lhs.value < rhs.value
      }
      let topActiveTag = activeTagUsage.max { lhs, rhs in
         if lhs.value == rhs.value { return lhs.key > rhs.key }
         return lhs.value < rhs.value
      }
      let oldestActive = active.map(\.createdAt).min()
      let sevenDayStaleDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
      let fourteenDayStaleDate = calendar.date(byAdding: .day, value: -14, to: now) ?? now
      let thirtyDayStaleDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now
      let completedThisWeekCount = completed.filter { $0.syncUpdatedAt >= weekStart }.count
      let completedThisMonthCount = completed.filter { $0.syncUpdatedAt >= monthStart }.count

      totalToDos = toDos.count
      activeToDos = active.count
      completedToDos = completed.count
      archivedToDos = toDos.filter { $0.lifecycleState == .archived }.count
      trashedToDos = toDos.filter { $0.lifecycleState == .trashed }.count
      overdueToDos = active.filter(\.isLate).count
      dueTodayToDos = active.filter { toDo in
         guard let dueDate = toDo.dueDate else { return false }
         return calendar.isDateInToday(dueDate)
      }.count
      scheduledToDos = scheduled.count
      timeSensitiveToDos = active.filter { $0.reminderIntent == .timeSensitive }.count
      recurringToDos = active.filter(\.isRecurring).count
      locationReminderToDos = active.filter(\.hasLocationReminder).count
      openNanoDos = nanoTotal - nanoCompleted
      completedNanoDos = nanoCompleted
      createdThisWeek = toDos.filter { $0.createdAt >= weekStart }.count
      completedThisWeek = completedThisWeekCount
      completedThisMonth = completedThisMonthCount
      completionRate = Self.ratio(completed.count, toDos.filter { $0.lifecycleState != .trashed }.count)
      dueDateCoverage = Self.ratio(scheduled.count, active.count)
      nanoDoCompletionRate = Self.ratio(nanoCompleted, nanoTotal)
      averageNanoDosPerActiveToDo = active.isEmpty ? 0 : Double(active.reduce(0) { $0 + $1.nanoDos.count }) / Double(active.count)
      mostUsedTagName = topTag?.key
      mostUsedTagCount = topTag?.value ?? 0
      completedLastSevenDays = completedThisWeekCount
      completedDailyAverage = Double(completedThisWeekCount) / 7
      onTimeCompletedDueToDos = dueCompleted.filter { toDo in
         guard let dueDate = toDo.dueDate else { return false }
         return toDo.syncUpdatedAt <= dueDate
      }.count
      lateCompletedDueToDos = dueCompleted.filter { toDo in
         guard let dueDate = toDo.dueDate else { return false }
         return toDo.syncUpdatedAt > dueDate
      }.count
      noDueCompletedToDos = noDueCompleted.count
      activeToDosWithNanoDos = activeWithNanoDos.count
      activeToDosWithoutNanoDos = activeWithoutNanoDos.count
      completionRateWithNanoDos = Self.ratio(withNanoDos.filter { $0.lifecycleState == .done }.count, withNanoDos.count)
      completionRateWithoutNanoDos = Self.ratio(withoutNanoDos.filter { $0.lifecycleState == .done }.count, withoutNanoDos.count)
      recurringCompletedLastThirtyDays = completed.filter { $0.isRecurring && $0.syncUpdatedAt >= monthStart }.count
      overdueRecurringToDos = active.filter { $0.isRecurring && $0.isLate }.count
      staleSevenDays = active.filter { $0.syncUpdatedAt < sevenDayStaleDate }.count
      staleFourteenDays = active.filter { $0.syncUpdatedAt < fourteenDayStaleDate }.count
      staleThirtyDays = active.filter { $0.syncUpdatedAt < thirtyDayStaleDate }.count
      focusPressureScore = min((overdueToDos * 4) + (timeSensitiveToDos * 3) + (dueTodayToDos * 2) + active.count, 100)
      overduePatternLabel = Self.overduePatternLabel(from: active.filter(\.isLate), calendar: calendar)
      topActiveTagName = topActiveTag?.key
      topActiveTagCount = topActiveTag?.value ?? 0

      if let oldestActive {
         oldestActiveAgeInDays = max(calendar.dateComponents([.day], from: oldestActive, to: now).day ?? 0, 0)
      } else {
         oldestActiveAgeInDays = nil
      }
   }

   var activeHealthLabel: String {
      if overdueToDos > 0 {
         return String(localized: "Needs attention")
      }

      if dueTodayToDos > 0 {
         return String(localized: "Focused today")
      }

      return String(localized: "Clear runway")
   }

   var completionRateLabel: String {
      Self.percentString(completionRate)
   }

   var dueDateCoverageLabel: String {
      Self.percentString(dueDateCoverage)
   }

   var nanoDoCompletionRateLabel: String {
      Self.percentString(nanoDoCompletionRate)
   }

   var averageNanoDosLabel: String {
      AppLocalization.decimalString(averageNanoDosPerActiveToDo, maximumFractionDigits: 1)
   }

   var oldestActiveLabel: String {
      guard let oldestActiveAgeInDays else { return String(localized: "No active toDōs") }
      return AppLocalization.localizedCount(oldestActiveAgeInDays, singularKey: "%@ day", pluralKey: "%@ days")
   }

   var completedDailyAverageLabel: String {
      AppLocalization.decimalString(completedDailyAverage, maximumFractionDigits: 1)
   }

   var onTimeCompletionRateLabel: String {
      Self.percentString(Self.ratio(onTimeCompletedDueToDos, onTimeCompletedDueToDos + lateCompletedDueToDos))
   }

   var completionRateWithNanoDosLabel: String {
      Self.percentString(completionRateWithNanoDos)
   }

   var completionRateWithoutNanoDosLabel: String {
      Self.percentString(completionRateWithoutNanoDos)
   }

   var focusPressureLabel: String {
      "\(AppLocalization.numberString(focusPressureScore))/100"
   }

   var strongestInsight: String {
      if overdueToDos > 0 {
         return String(localized: "Overdue toDōs are creating the most pressure right now.")
      }

      if staleFourteenDays > 0 {
         return String(localized: "Some active toDōs have not moved in over two weeks.")
      }

      if completionRateWithNanoDos > completionRateWithoutNanoDos, activeToDosWithNanoDos > 0 {
         return String(localized: "toDōs with NanoDos are completing at a stronger rate.")
      }

      if dueTodayToDos > 0 {
         return String(localized: "Today has scheduled work ready for focused attention.")
      }

      return String(localized: "You're caught up. Nothing needs urgent attention right now.")
   }

   var appleIntelligenceInput: AppleIntelligenceSummaryInput {
      AppleIntelligenceSummaryInput(
         activeCount: activeToDos,
         overdueCount: overdueToDos,
         dueTodayCount: dueTodayToDos,
         timeSensitiveCount: timeSensitiveToDos,
         completedLastSevenDaysCount: completedLastSevenDays,
         staleCount: staleFourteenDays,
         focusPressureScore: focusPressureScore,
         strongestDeterministicInsight: strongestInsight
      )
   }

   private static func tagUsage(from toDos: [ToDo]) -> [String: Int] {
      var usage: [String: Int] = [:]

      for toDo in toDos where toDo.lifecycleState != .trashed {
         for tag in toDo.effectiveTags {
            usage[tag.displayName, default: 0] += 1
         }
      }

      return usage.filter { $0.value > 0 }
   }

   private static func ratio(_ numerator: Int, _ denominator: Int) -> Double {
      guard denominator > 0 else { return 0 }
      return Double(numerator) / Double(denominator)
   }

   private static func percentString(_ value: Double) -> String {
      AppLocalization.decimalString(value * 100, maximumFractionDigits: 0) + "%"
   }

   private static func overduePatternLabel(from overdueToDos: [ToDo], calendar: Calendar) -> String {
      let dueDates = overdueToDos.compactMap(\.dueDate)
      guard !dueDates.isEmpty else { return String(localized: "No overdue pattern") }

      let groupedByWeekday = Dictionary(grouping: dueDates) { calendar.component(.weekday, from: $0) }
      guard let weekday = groupedByWeekday.max(by: { $0.value.count < $1.value.count })?.key,
            calendar.weekdaySymbols.indices.contains(weekday - 1)
      else {
         return String(localized: "Pattern unavailable")
      }

      return calendar.weekdaySymbols[weekday - 1]
   }
}

private struct StatsHeroCard: View {
   let snapshot: ToDoStatsSnapshot

   var body: some View {
      VStack(alignment: .leading, spacing: 18) {
         HStack(alignment: .center, spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
               .font(.appBodyStrong(20, relativeTo: .title3))
               .foregroundStyle(AppColor.white)
               .frame(width: 44, height: 44)
               .background(AppColor.secondary, in: Circle())
               .shadow(color: AppColor.secondary.opacity(0.24), radius: 14, y: 8)

            VStack(alignment: .leading, spacing: 6) {
               Text("Measure what matters")
                  .font(.appDisplay(26, relativeTo: .title2))
                  .foregroundStyle(AppColor.textPrimary)
            }
         }

         HStack(spacing: 12) {
            StatsHeroMetric(title: "Active", value: snapshot.activeToDos, tint: AppColor.secondary)
            StatsHeroMetric(title: "Done", value: snapshot.completedToDos, tint: AppColor.tertiary)
            StatsHeroMetric(title: "Overdue", value: snapshot.overdueToDos, tint: AppColor.destructive)
         }
      }
      .statsCardStyle(accent: AppColor.secondary)
   }
}

private struct StatsHeroMetric: View {
   let title: LocalizedStringKey
   let value: Int
   let tint: Color

   var body: some View {
      VStack(alignment: .leading, spacing: 4) {
         Text(AppLocalization.numberString(value))
            .font(.appDisplay(30, relativeTo: .title2))
            .foregroundStyle(tint)

         Text(title)
            .font(.appBodyStrong(12, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(tint.opacity(0.1), in: .rect(cornerRadius: 18))
   }
}

private struct StatsFocusGrid: View {
   let snapshot: ToDoStatsSnapshot

   private var columns: [GridItem] {
      [GridItem(.adaptive(minimum: 148), spacing: 12)]
   }

   var body: some View {
      LazyVGrid(columns: columns, spacing: 12) {
         StatsTile(title: "Due Today", value: AppLocalization.numberString(snapshot.dueTodayToDos), systemName: "calendar", tint: AppColor.tertiary)
         StatsTile(title: "Time-Sensitive", value: AppLocalization.numberString(snapshot.timeSensitiveToDos), systemName: "bolt.fill", tint: AppColor.destructive)
         StatsTile(title: "Scheduled", value: snapshot.dueDateCoverageLabel, systemName: "clock.badge.checkmark", tint: AppColor.secondary)
         StatsTile(title: "Recurring", value: AppLocalization.numberString(snapshot.recurringToDos), systemName: "repeat", tint: AppColor.main)
      }
   }
}

private struct StatsMomentumCard: View {
   let snapshot: ToDoStatsSnapshot

   var body: some View {
      VStack(alignment: .leading, spacing: 16) {
         StatsSectionHeader(title: "Momentum", systemName: "speedometer", tint: AppColor.tertiary)

         StatsProgressRow(title: "Completion Rate", value: snapshot.completionRateLabel, progress: snapshot.completionRate, tint: AppColor.tertiary)
         StatsProgressRow(title: "NanoDo Completion", value: snapshot.nanoDoCompletionRateLabel, progress: snapshot.nanoDoCompletionRate, tint: AppColor.tertiary)

         HStack(spacing: 12) {
            StatsCompactMetric(title: "Created This Week", value: AppLocalization.numberString(snapshot.createdThisWeek), tint: AppColor.tertiary)
            StatsCompactMetric(title: "Done This Week", value: AppLocalization.numberString(snapshot.completedThisWeek), tint: AppColor.tertiary)
            StatsCompactMetric(title: "Done 30 Days", value: AppLocalization.numberString(snapshot.completedThisMonth), tint: AppColor.tertiary)
         }
      }
      .statsCardStyle(accent: AppColor.tertiary)
   }
}

private struct StatsWorkloadCard: View {
   let snapshot: ToDoStatsSnapshot

   var body: some View {
      VStack(alignment: .leading, spacing: 16) {
         StatsSectionHeader(title: "Workload Shape", systemName: "square.stack.3d.up", tint: AppColor.secondary)

         StatsDetailRow(title: "Open NanoDos", value: AppLocalization.numberString(snapshot.openNanoDos), systemName: "smallcircle.filled.circle", tint: AppColor.secondary)
         StatsDetailRow(title: "Average NanoDos", value: snapshot.averageNanoDosLabel, systemName: "number", tint: AppColor.secondary)
         StatsDetailRow(title: "Location Reminders", value: AppLocalization.numberString(snapshot.locationReminderToDos), systemName: "location.fill", tint: AppColor.secondary)
         StatsDetailRow(title: "Oldest Active", value: snapshot.oldestActiveLabel, systemName: "hourglass", tint: AppColor.secondary)
      }
      .statsCardStyle(accent: AppColor.secondary)
   }
}

private struct StatsTagCard: View {
   let snapshot: ToDoStatsSnapshot

   var body: some View {
      VStack(alignment: .leading, spacing: 16) {
         StatsSectionHeader(title: "Organization", systemName: "tag.fill", tint: AppColor.main)

         StatsDetailRow(title: "Top Tag", value: topTagLabel, systemName: "number", tint: AppColor.main)
         StatsDetailRow(title: "Archived", value: AppLocalization.numberString(snapshot.archivedToDos), systemName: "archivebox.fill", tint: AppColor.main)
         StatsDetailRow(title: "Trash", value: AppLocalization.numberString(snapshot.trashedToDos), systemName: "trash.fill", tint: AppColor.main)
         StatsDetailRow(title: "Total toDōs", value: AppLocalization.numberString(snapshot.totalToDos), systemName: "tray.full.fill", tint: AppColor.main)
      }
      .statsCardStyle(accent: AppColor.main)
   }

   private var topTagLabel: String {
      guard let mostUsedTagName = snapshot.mostUsedTagName else {
         return String(localized: "No tag activity")
      }

      return "#\(mostUsedTagName) · \(AppLocalization.numberString(snapshot.mostUsedTagCount))"
   }
}

private struct StatsTrendCard: View {
   let snapshot: ToDoStatsSnapshot

   var body: some View {
      VStack(alignment: .leading, spacing: 16) {
         StatsSectionHeader(title: "Completion Trends", systemName: "chart.xyaxis.line", tint: AppColor.tertiary)

         HStack(spacing: 12) {
            StatsCompactMetric(title: "Done Last 7 Days", value: AppLocalization.numberString(snapshot.completedLastSevenDays), tint: AppColor.tertiary)
            StatsCompactMetric(title: "Daily Average", value: snapshot.completedDailyAverageLabel, tint: AppColor.tertiary)
         }

         StatsProgressRow(title: "Overall Completion", value: snapshot.completionRateLabel, progress: snapshot.completionRate, tint: AppColor.tertiary)
      }
      .statsCardStyle(accent: AppColor.tertiary)
   }
}

private struct StatsPlanningCard: View {
   let snapshot: ToDoStatsSnapshot

   var body: some View {
      VStack(alignment: .leading, spacing: 16) {
         StatsSectionHeader(title: "Planning Accuracy", systemName: "calendar.badge.clock", tint: AppColor.secondary)

         StatsProgressRow(title: "On-Time Due Completion", value: snapshot.onTimeCompletionRateLabel, progress: Double(snapshot.onTimeCompletedDueToDos) / Double(max(snapshot.onTimeCompletedDueToDos + snapshot.lateCompletedDueToDos, 1)), tint: AppColor.secondary)
         StatsDetailRow(title: "Completed Before Due", value: AppLocalization.numberString(snapshot.onTimeCompletedDueToDos), systemName: "checkmark.circle.fill", tint: AppColor.secondary)
         StatsDetailRow(title: "Completed After Due", value: AppLocalization.numberString(snapshot.lateCompletedDueToDos), systemName: "exclamationmark.circle.fill", tint: AppColor.secondary)
         StatsDetailRow(title: "No-Due Completions", value: AppLocalization.numberString(snapshot.noDueCompletedToDos), systemName: "minus.circle.fill", tint: AppColor.secondary)
         StatsDetailRow(title: "Overdue Pattern", value: snapshot.overduePatternLabel, systemName: "calendar", tint: AppColor.secondary)
      }
      .statsCardStyle(accent: AppColor.secondary)
   }
}

private struct StatsPressureCard: View {
   let snapshot: ToDoStatsSnapshot

   var body: some View {
      VStack(alignment: .leading, spacing: 16) {
         StatsSectionHeader(title: "Pressure Signals", systemName: "gauge.with.dots.needle.67percent", tint: AppColor.destructive)

         StatsProgressRow(title: "Focus Pressure", value: snapshot.focusPressureLabel, progress: Double(snapshot.focusPressureScore) / 100, tint: AppColor.destructive)
         StatsDetailRow(title: "Stale 7 Days", value: AppLocalization.numberString(snapshot.staleSevenDays), systemName: "clock.arrow.circlepath", tint: AppColor.destructive)
         StatsDetailRow(title: "Stale 14 Days", value: AppLocalization.numberString(snapshot.staleFourteenDays), systemName: "clock.badge.exclamationmark", tint: AppColor.destructive)
         StatsDetailRow(title: "Stale 30 Days", value: AppLocalization.numberString(snapshot.staleThirtyDays), systemName: "hourglass", tint: AppColor.destructive)
         StatsDetailRow(title: "Overdue Recurring", value: AppLocalization.numberString(snapshot.overdueRecurringToDos), systemName: "repeat.circle.fill", tint: AppColor.destructive)
         StatsDetailRow(title: "Top Active Tag", value: topActiveTagLabel, systemName: "tag.fill", tint: AppColor.destructive)
      }
      .statsCardStyle(accent: AppColor.destructive)
   }

   private var topActiveTagLabel: String {
      guard let topActiveTagName = snapshot.topActiveTagName else {
         return String(localized: "No active tag load")
      }

      return "#\(topActiveTagName) · \(AppLocalization.numberString(snapshot.topActiveTagCount))"
   }
}

private struct StatsInsightCard: View {
   @Environment(\.accessibilityReduceMotion) private var reduceMotion
   @Environment(\.openURL) private var openURL
   let snapshot: ToDoStatsSnapshot
   @Binding var isEnabled: Bool
   @Binding var isAppleIntelligenceEnabled: Bool
   @State private var animateGlow = false
   @State private var didUnlock = false

   private let appleIntelligenceSupportURL = URL(string: "https://support.apple.com/en-us/121115")!

   @State private var orbOneSize: CGFloat = 150
   @State private var orbTwoSize: CGFloat = 92
   @State private var orbOneOpacity: Double = 0.14
   @State private var orbTwoOpacity: Double = 0.12
   @State private var orbOneOffset: CGSize = CGSize(width: 48, height: -58)
   @State private var orbTwoOffset: CGSize = CGSize(width: -220, height: 164)
   @State private var backgroundShift: CGFloat = -0.18
   @State private var appleIntelligenceSummary: String?
   @State private var isGeneratingAppleIntelligenceSummary = false

   var body: some View {
      ZStack(alignment: .topTrailing) {
         decorativeOrbs

         VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
               Image(systemName: isEnabled ? "sparkles" : "lock.open.rotation")
                  .font(.appBodyStrong(22, relativeTo: .title3))
                  .foregroundStyle(AppColor.white)
                  .frame(width: 52, height: 52)
                  .background(AppColor.secondary, in: Circle())
                  .shadow(color: AppColor.secondary.opacity(isEnabled ? 0.45 : 0.18), radius: isEnabled ? 18 : 8, y: 8)
                  .scaleEffect(didUnlock ? 1.08 : 1)

               VStack(alignment: .leading, spacing: 5) {
                  Text(isEnabled ? String(localized: "Insights Unlocked") : String(localized: "Private Insights"))
                     .font(.appDisplay(24, relativeTo: .title2))
                     .foregroundStyle(AppColor.textPrimary)

                  Text("Built for you, processed on this device.")
                     .font(.appBodyStrong(14, relativeTo: .body))
                     .foregroundStyle(AppColor.secondary)

                  Text("Your patterns stay private. Insights simply help you see what deserves attention next.")
                     .font(.appBody(13, relativeTo: .caption))
                     .foregroundStyle(AppColor.textSecondary)
                     .fixedSize(horizontal: false, vertical: true)
               }
            }

            if isEnabled {
               VStack(alignment: .leading, spacing: 14) {
                  Text(displayedInsight)
                     .font(.appBody(18, relativeTo: .body))
                     .foregroundStyle(AppColor.textPrimary)
                     .lineSpacing(2)
                     .fixedSize(horizontal: false, vertical: true)
                     .transition(.move(edge: .bottom).combined(with: .opacity))

                  StatsDetailRow(title: "With NanoDos", value: snapshot.completionRateWithNanoDosLabel, systemName: "checklist", tint: AppColor.secondary, valueSize: 18)
                  StatsDetailRow(title: "Without NanoDos", value: snapshot.completionRateWithoutNanoDosLabel, systemName: "list.bullet", tint: AppColor.secondary, valueSize: 18)
                  StatsDetailRow(title: "Recurring Done 30 Days", value: AppLocalization.numberString(snapshot.recurringCompletedLastThirtyDays), systemName: "repeat", tint: AppColor.secondary, valueSize: 18)
                  appleIntelligenceBlock
               }
               .task(id: appleIntelligenceTaskID) {
                  await refreshAppleIntelligenceSummary()
               }
            } else {
               Button {
                  HapticFeedbackService.play(.reveal)
                  withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.78)) {
                     isEnabled = true
                     didUnlock = true
                  }
               } label: {
                  HStack(spacing: 10) {
                     Image(systemName: "sparkles")
                     Text("Unlock Insights")
                     Spacer(minLength: 0)
                     Image(systemName: "arrow.right")
                  }
                  .font(.appBodyStrong(16, relativeTo: .body))
                  .foregroundStyle(AppColor.white)
                  .padding(.horizontal, 18)
                  .padding(.vertical, 15)
                  .background(AppColor.secondary, in: .rect(cornerRadius: 20))
               }
               .buttonStyle(.plain)
               .shadow(color: AppColor.secondary.opacity(0.28), radius: 16, y: 9)
            }
         }
         .padding(20)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(insightBackground, in: .rect(cornerRadius: 30))
      .overlay {
         RoundedRectangle(cornerRadius: 30, style: .continuous)
            .stroke(AppColor.secondary.opacity(isEnabled ? 0.45 : 0.24), lineWidth: 1)
      }
      .shadow(color: AppColor.secondary.opacity(isEnabled ? 0.18 : 0.08), radius: isEnabled ? 24 : 14, y: isEnabled ? 14 : 8)
      .onAppear {
         guard !reduceMotion else { return }

         withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            animateGlow = true
            backgroundShift = 0.22
         }
      }
      .task {
         guard !reduceMotion else { return }

         await runOrbAnimationLoop()
      }
      .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82), value: isEnabled)
   }

   private var appleIntelligenceBlock: some View {
      VStack(alignment: .leading, spacing: 12) {
         HStack(alignment: .center, spacing: 12) {
            Image(systemName: isAppleIntelligenceEnabled ? "apple.intelligence" : "apple.intelligence.badge.xmark")
               .font(.appDisplay(17, relativeTo: .headline))
               .foregroundStyle(AppColor.onAction)
               .frame(width: 36, height: 36)
               .background(AppColor.textPrimary, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
               Text("Apple Intelligence")
                  .font(.appDisplay(22, relativeTo: .title3))
                  .foregroundStyle(AppColor.textPrimary)

               Text("Let toDō help summarize, organize, and surface what matters using Apple Intelligence when available.")
                  .font(.appBody(13, relativeTo: .caption))
                  .foregroundStyle(AppColor.textSecondary)
                  .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            Toggle("Use Apple Intelligence", isOn: $isAppleIntelligenceEnabled)
               .labelsHidden()
               .tint(AppColor.secondary)
               .disabled(!isAppleIntelligenceAvailable)
               .accessibilityLabel("Use Apple Intelligence")
         }

         Text("Designed with privacy at the center. Supported features use Apple Intelligence when available without making AI required for toDō.")
            .font(.appBody(12, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

         if !isAppleIntelligenceAvailable {
            Button {
               openURL(appleIntelligenceSupportURL)
            } label: {
               HStack(spacing: 8) {
                  Text("Apple Intelligence is not available on this device, OS version, language, or region yet.")
                     .font(.appBodyStrong(12, relativeTo: .caption))
                     .fixedSize(horizontal: false, vertical: true)

                  Image(systemName: "arrow.right")
                     .font(.appDisplay(12, relativeTo: .caption))
               }
               .foregroundStyle(AppColor.secondary)
               .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Learn about Apple Intelligence availability")
         }

         if isAppleIntelligenceEnabled, isAppleIntelligenceAvailable {
            Label(
               isGeneratingAppleIntelligenceSummary ? String(localized: "Apple Intelligence is reviewing your patterns...") : String(localized: "Apple Intelligence is on."),
               systemImage: isGeneratingAppleIntelligenceSummary ? "sparkles" : "checkmark.seal.fill"
            )
            .font(.appBodyStrong(12, relativeTo: .caption))
            .foregroundStyle(AppColor.secondary)
         }
      }
      .padding(14)
      .background(AppColor.surfaceMuted.opacity(0.72), in: .rect(cornerRadius: 20))
      .overlay {
         RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(AppColor.secondary.opacity(0.18), lineWidth: 1)
      }
   }

   private var isAppleIntelligenceAvailable: Bool {
      AppleIntelligenceService.isAvailable
   }

   private var displayedInsight: String {
      if isAppleIntelligenceEnabled, let appleIntelligenceSummary, !appleIntelligenceSummary.isEmpty {
         return appleIntelligenceSummary
      }

      return snapshot.strongestInsight
   }

   private var appleIntelligenceTaskID: String {
      [
         isAppleIntelligenceEnabled ? "on" : "off",
         "\(snapshot.activeToDos)",
         "\(snapshot.overdueToDos)",
         "\(snapshot.dueTodayToDos)",
         "\(snapshot.timeSensitiveToDos)",
         "\(snapshot.completedLastSevenDays)",
         "\(snapshot.staleFourteenDays)",
         "\(snapshot.focusPressureScore)"
      ].joined(separator: "-")
   }

   @MainActor
   private func refreshAppleIntelligenceSummary() async {
      guard isEnabled, isAppleIntelligenceEnabled, isAppleIntelligenceAvailable else {
         appleIntelligenceSummary = nil
         isGeneratingAppleIntelligenceSummary = false
         return
      }

      isGeneratingAppleIntelligenceSummary = true
      let summary = await AppleIntelligenceService.summarize(
         snapshot.appleIntelligenceInput,
         isEnabled: isAppleIntelligenceEnabled
      )
      appleIntelligenceSummary = summary
      isGeneratingAppleIntelligenceSummary = false
   }

   private var insightBackground: LinearGradient {
      LinearGradient(
         colors: [
            AppColor.surfaceElevated,
            AppColor.secondary.opacity(isEnabled ? 0.18 : 0.1),
            AppColor.tertiary.opacity(isEnabled ? 0.12 : 0.06)
         ],
         startPoint: UnitPoint(x: backgroundShift, y: 0),
         endPoint: UnitPoint(x: 1.0 - backgroundShift, y: 1)
      )
   }

   private var decorativeOrbs: some View {
      ZStack {
      Circle()
            .fill(
               RadialGradient(
                  colors: [
                     AppColor.secondary.opacity(orbOneOpacity),
                     AppColor.secondary.opacity(0)
                  ],
                  center: .center,
                  startRadius: 0,
                  endRadius: orbOneSize / 2
               )
            )
            .frame(width: orbOneSize, height: orbOneSize)
            .blur(radius: animateGlow ? 1 : 8)
            .offset(orbOneOffset)
            .animation(.easeInOut(duration: 4.8), value: orbOneSize)
            .animation(.easeInOut(duration: 4.8), value: orbOneOpacity)
            .animation(.easeInOut(duration: 4.8), value: orbOneOffset)

         Circle()
            .fill(
               RadialGradient(
                  colors: [
                     AppColor.tertiary.opacity(orbTwoOpacity),
                     AppColor.tertiary.opacity(0)
                  ],
                  center: .center,
                  startRadius: 0,
                  endRadius: orbTwoSize / 2
               )
            )
            .frame(width: orbTwoSize, height: orbTwoSize)
            .blur(radius: animateGlow ? 1 : 7)
            .offset(orbTwoOffset)
            .animation(.easeInOut(duration: 5.6), value: orbTwoSize)
            .animation(.easeInOut(duration: 5.6), value: orbTwoOpacity)
            .animation(.easeInOut(duration: 5.6), value: orbTwoOffset)
      }
      .allowsHitTesting(false)
   }

   private func runOrbAnimationLoop() async {
      randomizeOrbState(animated: false)

      while !Task.isCancelled {
         try? await Task.sleep(for: .seconds(5.2))
         guard !Task.isCancelled else { return }
         randomizeOrbState(animated: true)
      }
   }

   @MainActor
   private func randomizeOrbState(animated: Bool) {
      let updates = {
         orbOneSize = CGFloat.random(in: 132...178)
         orbTwoSize = CGFloat.random(in: 82...118)

         orbOneOpacity = Double.random(in: 0.08...0.18)
         orbTwoOpacity = Double.random(in: 0.06...0.16)

         orbOneOffset = CGSize(
            width: CGFloat.random(in: 26...64),
            height: CGFloat.random(in: -76 ... -36)
         )

         orbTwoOffset = CGSize(
            width: CGFloat.random(in: -240 ... -188),
            height: CGFloat.random(in: 132 ... 188)
         )
      }

      if animated {
         withAnimation(.easeInOut(duration: 5.2)) {
            updates()
         }
      } else {
         updates()
      }
   }
}

private struct StatsTile: View {
   let title: LocalizedStringKey
   let value: String
   let systemName: String
   let tint: Color

   var body: some View {
      VStack(alignment: .leading, spacing: 12) {
         Image(systemName: systemName)
            .font(.appBodyStrong(18, relativeTo: .headline))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(tint.opacity(0.14), in: Circle())

         Text(value)
            .font(.appDisplay(30, relativeTo: .title2))
            .foregroundStyle(AppColor.textPrimary)

         Text(title)
            .font(.appBodyStrong(13, relativeTo: .caption))
            .foregroundStyle(AppColor.textSecondary)
      }
      .padding(16)
      .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
      .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 24))
      .overlay {
         RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(tint.opacity(0.18), lineWidth: 1)
      }
   }
}

private struct StatsSectionHeader: View {
   let title: LocalizedStringKey
   let systemName: String
   var tint: Color = AppColor.secondary

   var body: some View {
      HStack(alignment: .center, spacing: 14) {
         Image(systemName: systemName)
            .font(.appBodyStrong(20, relativeTo: .headline))
            .foregroundStyle(AppColor.white)
            .frame(width: 44, height: 44)
            .background(tint, in: Circle())
            .shadow(color: tint.opacity(0.24), radius: 14, y: 8)

         VStack(alignment: .leading, spacing: 6) {
            Text(title)
               .font(.appDisplay(26, relativeTo: .title2))
               .foregroundStyle(AppColor.textPrimary)
         }
      }
   }
}

private struct StatsProgressRow: View {
   let title: LocalizedStringKey
   let value: String
   let progress: Double
   let tint: Color

   var body: some View {
      VStack(alignment: .leading, spacing: 8) {
         HStack {
            Text(title)
               .font(.appBodyStrong(14, relativeTo: .body))
               .foregroundStyle(AppColor.textPrimary)

            Spacer()

            Text(value)
               .font(.appBodyStrong(14, relativeTo: .body))
               .foregroundStyle(tint)
         }

         GeometryReader { proxy in
            ZStack(alignment: .leading) {
               Capsule()
                  .fill(AppColor.border.opacity(0.35))

               Capsule()
                  .fill(tint)
                  .frame(width: max(proxy.size.width * min(max(progress, 0), 1), 6))
            }
         }
         .frame(height: 9)
      }
   }
}

private struct StatsCompactMetric: View {
   let title: LocalizedStringKey
   let value: String
   var tint: Color = AppColor.textPrimary

   var body: some View {
      VStack(alignment: .leading, spacing: 5) {
         Text(value)
            .font(.appDisplay(22, relativeTo: .title3))
            .foregroundStyle(tint)

         Text(title)
            .font(.appBodyStrong(11, relativeTo: .caption2))
            .foregroundStyle(AppColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
      .padding(12)
      .background(AppColor.surface.opacity(0.78), in: .rect(cornerRadius: 18))
   }
}

private struct StatsDetailRow: View {
   let title: LocalizedStringKey
   let value: String
   let systemName: String
   var tint: Color = AppColor.secondary
   var valueSize: CGFloat = 14

   var body: some View {
      HStack(spacing: 12) {
         Image(systemName: systemName)
            .font(.appBodyStrong(14, relativeTo: .body))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(tint.opacity(0.12), in: Circle())

         Text(title)
            .font(.appBodyStrong(14, relativeTo: .body))
            .foregroundStyle(AppColor.textPrimary)

         Spacer(minLength: 12)

         Text(value)
            .font(.appBodyStrong(valueSize, relativeTo: .body))
            .foregroundStyle(valueSize > 14 ? AppColor.textPrimary : AppColor.textSecondary)
            .multilineTextAlignment(.trailing)
      }
   }
}

private extension View {
   func statsCardStyle(accent: Color = AppColor.secondary) -> some View {
      modifier(StatsCardModifier(accent: accent))
   }
}

private struct StatsCardModifier: ViewModifier {
   @Environment(\.colorScheme) private var colorScheme
   let accent: Color

   func body(content: Content) -> some View {
      content
         .padding(18)
         .frame(maxWidth: .infinity, alignment: .leading)
         .background(AppColor.surfaceElevated, in: .rect(cornerRadius: 28))
         .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
               .stroke(AppColor.border.opacity(colorScheme == .dark ? 0.7 : 0.45), lineWidth: 1)
         }
         .shadow(color: AppColor.shadow.opacity(colorScheme == .dark ? 0.18 : 0.1), radius: 18, y: 10)
   }
}

#Preview {
   NavigationStack {
      StatsView()
   }
   .modelContainer(PreviewSupport.makeModelContainer())
}
