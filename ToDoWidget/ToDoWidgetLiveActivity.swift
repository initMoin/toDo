import AppIntents
import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

struct ToDoWidgetLiveActivity: Widget {
   var body: some WidgetConfiguration {
      ActivityConfiguration(for: ToDoLiveActivityAttributes.self) { context in
         ToDoLiveActivitySurfaceView(context: context)
            .activityBackgroundTint(Color(hex: 0x0E1011))
            .activitySystemActionForegroundColor(Color(hex: 0xF0B42D))
      } dynamicIsland: { context in
         DynamicIsland {
            DynamicIslandExpandedRegion(.center) {
               ToDoDynamicIslandTitleRow(context: context)
            }

            DynamicIslandExpandedRegion(.bottom) {
               HStack(alignment: .center, spacing: 10) {
                  Image(systemName: "calendar.badge.clock")
                     .font(.system(size: 16, weight: .semibold))
                     .foregroundStyle(context.state.accentColor)
                     .frame(width: 24, height: 24)

                  LiveActivityShortDueDateTimeText(
                     dueDate: context.state.dueDate,
                     dateSize: 16,
                     timeSize: 18,
                     spacing: 10
                  )
                  .frame(maxWidth: .infinity, alignment: .leading)
               }
               .padding(.horizontal, 2)
               .frame(maxWidth: .infinity, alignment: .leading)
            }
         } compactLeading: {
            LiveActivityCompactDueDateText(dueDate: context.state.dueDate, size: 12)
               .foregroundStyle(context.state.accentColor)
         } compactTrailing: {
            LiveActivityShortDueTimeText(dueDate: context.state.dueDate, size: 12)
               .foregroundStyle(Color(hex: 0xF4F1E8))
         } minimal: {
            Image(systemName: context.state.statusSystemImage)
               .foregroundStyle(context.state.accentColor)
         }
         .widgetURL(context.attributes.deepLinkURL)
         .keylineTint(context.state.accentColor)
      }
      .supplementalActivityFamilies([.small])
   }
}

private struct ToDoLiveActivitySurfaceView: View {
   @Environment(\.activityFamily) private var activityFamily

   let context: ActivityViewContext<ToDoLiveActivityAttributes>

   var body: some View {
      Group {
         switch activityFamily {
         case .small:
            ToDoWatchLiveActivityView(context: context)
         default:
            ToDoLiveActivityLockScreenView(context: context)
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
   }
}

private struct ToDoLiveActivityLockScreenView: View {
   @Environment(\.horizontalSizeClass) private var horizontalSizeClass

   let context: ActivityViewContext<ToDoLiveActivityAttributes>

   var body: some View {
      Group {
         if usesRegularWidthLayout {
            regularWidthLayout
         } else {
            compactWidthLayout
         }
      }
      .widgetURL(context.attributes.deepLinkURL)
   }

   private var usesRegularWidthLayout: Bool {
      horizontalSizeClass == .regular
   }

   private var compactWidthLayout: some View {
      VStack(alignment: .leading, spacing: 10) {
         HStack(alignment: .center, spacing: 8) {
            Spacer(minLength: 6)

            LiveActivityUpdatedText(updatedAt: context.state.updatedAt, size: 10)
         }
         .frame(maxWidth: .infinity, alignment: .leading)

         HStack(alignment: .center, spacing: 9) {
            statusIcon(size: 19, frame: 32)

            VStack(alignment: .leading, spacing: 2) {
               Text(context.state.title)
                  .font(WidgetTypography.title(19, relativeTo: .headline))
                  .foregroundStyle(.white)
                  .lineLimit(1)
                  .minimumScaleFactor(0.82)

               Text(context.state.statusTitle)
                  .font(WidgetTypography.accent(10, relativeTo: .caption2))
                  .foregroundStyle(context.state.accentColor)
                  .textCase(.uppercase)
                  .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
         }
         .frame(maxWidth: .infinity, alignment: .leading)

         HStack(alignment: .center, spacing: 10) {
            Image(systemName: "arrow.up.right")
               .font(.system(size: 14, weight: .black, design: .rounded))
               .foregroundStyle(Color(hex: 0x101010))
               .frame(width: 32, height: 32)
               .background(context.state.accentColor, in: Circle())
               .accessibilityLabel("Open toDō")

            VStack(alignment: .leading, spacing: 3) {
               Text(String(localized: "Due"))
                  .font(WidgetTypography.accent(9, relativeTo: .caption2))
                  .foregroundStyle(context.state.accentColor)
                  .textCase(.uppercase)

               LiveActivityShortDueDateTimeText(
                  dueDate: context.state.dueDate,
                  dateSize: 13,
                  timeSize: 16,
                  spacing: 7
               )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
         }
         .padding(.horizontal, 10)
         .padding(.vertical, 8)
         .background(Color.white.opacity(0.10), in: .rect(cornerRadius: 18))
         .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
         activityGlassBackground(cornerRadius: 22)
      }
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
   }

   private var regularWidthLayout: some View {
      VStack(alignment: .leading, spacing: 14) {
         HStack(alignment: .center, spacing: 10) {
            statusIcon(size: 24, frame: 40)

            VStack(alignment: .leading, spacing: 4) {
               Text(context.state.title)
                  .font(.custom("BebasNeue-Regular", size: 25, relativeTo: .title3))
                  .foregroundStyle(.white)
                  .lineLimit(1)
                  .minimumScaleFactor(0.74)
                  .frame(maxWidth: .infinity, alignment: .leading)

               Text(context.state.statusTitle)
                  .font(.custom("Jura-SemiBold", size: 12, relativeTo: .caption))
                  .foregroundStyle(context.state.accentColor)
                  .textCase(.uppercase)
                  .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            Image(systemName: "arrow.up.right")
               .font(.system(size: 20, weight: .black, design: .rounded))
               .foregroundStyle(Color(hex: 0x101010))
               .frame(width: 44, height: 44)
               .background(context.state.accentColor, in: Circle())
               .accessibilityLabel("Open toDō")
         }
         .frame(maxWidth: .infinity, alignment: .leading)

         HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
               Text(String(localized: "Due"))
                  .font(.custom("Jura-SemiBold", size: 11, relativeTo: .caption2))
                  .foregroundStyle(context.state.accentColor)
                  .textCase(.uppercase)

               LiveActivityShortDueDateTimeText(
                  dueDate: context.state.dueDate,
                  dateSize: 18,
                  timeSize: 24,
                  spacing: 10
               )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
               RoundedRectangle(cornerRadius: 22, style: .continuous)
                  .fill(Color.white.opacity(0.10))
                  .overlay(alignment: .leading) {
                     RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(context.state.accentColor)
                        .frame(width: 4)
                  }
            }

            VStack(alignment: .leading, spacing: 5) {
               Text(String(localized: "Updated"))
                  .font(.custom("Jura-SemiBold", size: 11, relativeTo: .caption2))
                  .foregroundStyle(Color(hex: 0xF4F1E8, opacity: 0.58))
                  .textCase(.uppercase)
                  .lineLimit(1)

               LiveActivityUpdatedText(updatedAt: context.state.updatedAt, size: 14)
                  .foregroundStyle(Color(hex: 0xF4F1E8, opacity: 0.78))
                  .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.07), in: .rect(cornerRadius: 22))
         }
         .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 22)
      .padding(.vertical, 16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
         activityGlassBackground(cornerRadius: 28)
      }
      .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
   }

   private func statusIcon(size: CGFloat, frame: CGFloat) -> some View {
      Image(systemName: context.state.statusSystemImage)
         .font(.system(size: size, weight: .semibold))
         .foregroundStyle(context.state.accentColor)
         .frame(width: frame, height: frame)
         .background(Color.white.opacity(0.11), in: Circle())
         .overlay(Circle().stroke(context.state.accentColor.opacity(0.38), lineWidth: 1))
   }

   private var lockScreenBackground: some ShapeStyle {
      LinearGradient(
         colors: [
            Color(hex: 0x15191F),
            context.state.backgroundAccentColor.opacity(0.72),
            Color(hex: 0x07080A)
         ],
         startPoint: .topLeading,
         endPoint: .bottomTrailing
      )
   }

   @ViewBuilder
   private func activityGlassBackground(cornerRadius: CGFloat) -> some View {
      let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

      if #available(iOSApplicationExtension 26.0, *) {
         shape
            .fill(Color.white.opacity(0.08))
            .overlay {
               shape
                  .stroke(Color.white.opacity(0.32), lineWidth: 1)
            }
            .glassEffect(
               .regular.tint(Color.white.opacity(0.12)),
               in: .rect(cornerRadius: cornerRadius)
            )
      } else {
         shape
            .fill(lockScreenBackground)
            .overlay {
               shape
                  .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
      }
   }

   private func statusGlow(size: CGFloat) -> some View {
      Circle()
         .fill(
            RadialGradient(
               colors: [
                  context.state.accentColor.opacity(0.18),
                  context.state.accentColor.opacity(0.04),
                  .clear
               ],
               center: .center,
               startRadius: 0,
               endRadius: size / 2
            )
         )
         .frame(width: size, height: size)
         .allowsHitTesting(false)
   }
}

private struct ToDoWatchLiveActivityView: View {
   let context: ActivityViewContext<ToDoLiveActivityAttributes>

   var body: some View {
      VStack(alignment: .leading, spacing: 5) {
         HStack(alignment: .center, spacing: 6) {
            Image(systemName: context.state.statusSystemImage)
               .font(.system(size: 12, weight: .black, design: .rounded))
               .foregroundStyle(Color(hex: 0x101010))
               .frame(width: 20, height: 20)
               .background(context.state.accentColor, in: Circle())

            Text(context.state.title)
               .font(.custom("BebasNeue-Regular", size: 14, relativeTo: .headline))
               .foregroundStyle(Color(hex: 0xF4F1E8))
               .lineLimit(1)
               .minimumScaleFactor(0.64)
         }
         .frame(maxWidth: .infinity, alignment: .leading)

         HStack(alignment: .center, spacing: 7) {
            VStack(alignment: .leading, spacing: 1) {
               Text(context.state.watchStatusText)
                  .font(.custom("Jura-SemiBold", size: 8, relativeTo: .caption2))
                  .foregroundStyle(context.state.accentColor)
                  .textCase(.uppercase)
                  .lineLimit(1)

               LiveActivityWatchDueText(dueDate: context.state.dueDate)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.up.right")
               .font(.system(size: 13, weight: .black, design: .rounded))
               .foregroundStyle(Color(hex: 0x101010))
               .frame(width: 28, height: 28)
               .background(context.state.accentColor, in: Circle())
               .accessibilityLabel("Open toDō")
         }
         .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 9)
      .padding(.vertical, 7)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .containerBackground(for: .widget) {
         watchActivityBackground
      }
      .widgetURL(context.attributes.deepLinkURL)
   }

   private var watchActivityBackground: LinearGradient {
      LinearGradient(
         colors: [
            Color(hex: 0x181A1B),
            Color(hex: 0x101214),
            context.state.backgroundAccentColor.opacity(0.42)
         ],
         startPoint: .topLeading,
         endPoint: .bottomTrailing
      )
   }
}

private struct LiveActivityWatchDueText: View {
   let dueDate: Date?

   var body: some View {
      Text(dueText)
         .font(.system(size: 9, weight: .semibold, design: .rounded))
         .foregroundStyle(Color(hex: 0xD8D8D8))
         .lineLimit(1)
         .minimumScaleFactor(0.68)
   }

   private var dueText: String {
      guard let dueDate else { return String(localized: "No Due Date") }
      return WidgetFormatting.dateTimeString(dueDate)
   }
}

private struct ToDoDynamicIslandTitleRow: View {
   let context: ActivityViewContext<ToDoLiveActivityAttributes>

   var body: some View {
      HStack(alignment: .center, spacing: 8) {
         Image(systemName: context.state.statusSystemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(context.state.accentColor)
            .frame(width: 24, height: 24)
            .background(context.state.accentColor.opacity(0.18), in: Circle())

         Text(context.state.title)
            .font(.custom("BebasNeue-Regular", size: 17, relativeTo: .headline))
            .foregroundStyle(Color(hex: 0xF4F1E8))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 2)
   }
}

private struct LiveActivityDueDateTimeText: View {
   let dueDate: Date?
   let size: CGFloat

   var body: some View {
      if let dueDate {
         Text("\(String(localized: "Due")) \(WidgetFormatting.dateTimeString(dueDate))")
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(hex: 0xD8D8D8))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
      } else {
         Text(String(localized: "No Due Date"))
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(hex: 0xAFAFAF))
            .lineLimit(1)
      }
   }
}

private struct LiveActivityShortDueDateTimeText: View {
   let dueDate: Date?
   let dateSize: CGFloat
   let timeSize: CGFloat
   let spacing: CGFloat

   var body: some View {
      if let dueDate {
         HStack(alignment: .firstTextBaseline, spacing: spacing) {
            Text(LiveActivityShortDueFormatter.dateText(for: dueDate))
               .font(.system(size: dateSize, weight: .semibold, design: .rounded))
               .foregroundStyle(Color(hex: 0xF4F1E8, opacity: 0.76))
               .monospacedDigit()

            Text(LiveActivityShortDueFormatter.timeText(for: dueDate))
               .font(.system(size: timeSize, weight: .bold, design: .rounded))
               .foregroundStyle(Color(hex: 0xF4F1E8))
               .monospacedDigit()
         }
         .lineLimit(1)
         .minimumScaleFactor(0.78)
      } else {
         Text("--")
            .font(.system(size: timeSize, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: 0xAFAFAF))
            .monospacedDigit()
      }
   }
}

private struct LiveActivityCompactDueDateText: View {
   let dueDate: Date?
   let size: CGFloat

   var body: some View {
      Text(dueDate.map(LiveActivityShortDueFormatter.compactDateText(for:)) ?? "--")
         .font(.system(size: size, weight: .semibold, design: .rounded))
         .monospacedDigit()
         .lineLimit(1)
         .minimumScaleFactor(0.72)
   }
}

private struct LiveActivityShortDueTimeText: View {
   let dueDate: Date?
   let size: CGFloat

   var body: some View {
      Text(dueDate.map(LiveActivityShortDueFormatter.timeText(for:)) ?? "--")
         .font(.system(size: size, weight: .semibold, design: .rounded))
         .monospacedDigit()
         .lineLimit(1)
         .minimumScaleFactor(0.72)
   }
}

private enum LiveActivityShortDueFormatter {
   static func dateText(for date: Date) -> String {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.dateFormat = "M/d/yy"
      return formatter.string(from: date)
   }

   static func timeText(for date: Date) -> String {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.dateFormat = Calendar.autoupdatingCurrent.component(.minute, from: date) == 0 ? "ha" : "h:mma"
      return formatter.string(from: date).lowercased()
   }

   static func compactDateText(for date: Date) -> String {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.dateFormat = "M/d"
      return formatter.string(from: date)
   }
}

private struct LiveActivityUpdatedText: View {
   let updatedAt: Date
   let size: CGFloat

   var body: some View {
      Text("\(String(localized: "Updated")) \(formattedUpdatedText)")
         .font(.system(size: size, weight: .semibold, design: .rounded))
         .foregroundStyle(Color(hex: 0xF4F1E8, opacity: 0.68))
         .lineLimit(1)
         .minimumScaleFactor(0.74)
   }

   private var formattedUpdatedText: String {
      "\(LiveActivityShortDueFormatter.dateText(for: updatedAt)) @ \(LiveActivityShortDueFormatter.timeText(for: updatedAt))"
   }
}

private struct LiveActivityAnimatedCountdownView: View {
   let dueDate: Date?
   let isOverdue: Bool
   let size: CGFloat
   let weight: Font.Weight

   var body: some View {
      Group {
         if let dueDate {
            if isOverdue {
               Text(timerInterval: dueDate...Date.distantFuture, countsDown: false)
            } else {
               Text(timerInterval: Date.now...dueDate, countsDown: true)
            }
         } else {
            Text("--")
         }
      }
      .font(.system(size: size, weight: weight, design: .rounded))
      .monospacedDigit()
      .foregroundStyle(Color(hex: 0xAFAFAF))
   }
}

private struct LiveActivitySegmentedCountdownView: View {
   let dueDate: Date?
   let isOverdue: Bool
   let valueSize: CGFloat
   let labelSize: CGFloat
   let spacing: CGFloat

   var body: some View {
      TimelineView(.periodic(from: .now, by: 1)) { timeline in
         if let dueDate {
            let components = countdownComponents(now: timeline.date, dueDate: dueDate)
            HStack(alignment: .firstTextBaseline, spacing: spacing) {
               countdownMetric(value: "\(components.days)", label: String(localized: "days"))
               countdownSeparator
               countdownMetric(value: twoDigit(components.hours), label: String(localized: "hours"))
               countdownSeparator
               countdownMetric(value: twoDigit(components.minutes), label: String(localized: "minutes"))
               countdownSeparator
               countdownMetric(value: twoDigit(components.seconds), label: String(localized: "seconds"))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.72)
         } else {
            Text("--")
               .font(.system(size: valueSize, weight: .bold, design: .rounded))
               .monospacedDigit()
         }
      }
   }

   private var countdownSeparator: some View {
      Text(":")
         .font(.system(size: max(valueSize - 4, 10), weight: .bold, design: .rounded))
         .foregroundStyle(Color(hex: 0xF4F1E8, opacity: 0.58))
         .baselineOffset(labelSize + 1)
   }

   private func countdownMetric(value: String, label: String) -> some View {
      VStack(spacing: 1) {
         Text(value)
            .font(.system(size: valueSize, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: 0xF4F1E8))
            .monospacedDigit()

         Text(label)
            .font(.system(size: labelSize, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(hex: 0xF4F1E8, opacity: 0.64))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
      }
      .frame(minWidth: max(valueSize * 1.25, 26), alignment: .center)
   }

   private func countdownComponents(now: Date, dueDate: Date) -> CountdownComponents {
      let interval = max(isOverdue ? now.timeIntervalSince(dueDate) : dueDate.timeIntervalSince(now), 0)
      let totalSeconds = Int(interval.rounded(.down))
      let days = totalSeconds / 86_400
      let hours = (totalSeconds % 86_400) / 3_600
      let minutes = (totalSeconds % 3_600) / 60
      let seconds = totalSeconds % 60
      return CountdownComponents(days: days, hours: hours, minutes: minutes, seconds: seconds)
   }

   private func twoDigit(_ value: Int) -> String {
      String(format: "%02d", value)
   }

   private struct CountdownComponents {
      let days: Int
      let hours: Int
      let minutes: Int
      let seconds: Int
   }
}

private struct LiveActivityDueTimeView: View {
   let dueDate: Date?
   let isOverdue: Bool

   var body: some View {
      if let dueDate {
         if !isOverdue, dueDate > .now {
            Text(timerInterval: Date.now...dueDate, countsDown: true)
         } else {
            Text(dueDate, style: .time)
         }
      } else {
         Text("--")
      }
   }
}

private struct LiveActivityCompactCountdownView: View {
   let dueDate: Date?
   let isOverdue: Bool

   var body: some View {
      TimelineView(.periodic(from: .now, by: 1)) { timeline in
         Text(countdownText(now: timeline.date))
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
      }
   }

   private func countdownText(now: Date) -> String {
      guard let dueDate else { return "--" }

      let interval = max(isOverdue ? now.timeIntervalSince(dueDate) : dueDate.timeIntervalSince(now), 0)
      let totalSeconds = Int(interval.rounded(.down))
      let hours = totalSeconds / 3600
      let minutes = (totalSeconds % 3600) / 60
      let seconds = totalSeconds % 60

      if hours > 0 {
         return String(format: "%d:%02d", hours, minutes)
      }
      return String(format: "%d:%02d", minutes, seconds)
   }
}

private extension ToDoLiveActivityAttributes.ContentState {
   var statusTitle: String {
      isOverdue ? String(localized: "Overdue") : String(localized: "Time-Sensitive")
   }

   var statusSystemImage: String {
      isOverdue ? "exclamationmark.circle.fill" : "clock.fill"
   }

   var accentColor: Color {
      isOverdue ? Color(hex: 0xFF3B30) : Color(hex: 0xF0B42D)
   }

   var backgroundAccentColor: Color {
      isOverdue ? Color(hex: 0x4A0505) : Color(hex: 0x05356F)
   }

   var watchStatusText: String {
      isOverdue ? String(localized: "Overdue") : String(localized: "Due Soon")
   }
}

extension ToDoLiveActivityAttributes {
   var deepLinkURL: URL? {
      var components = URLComponents()
      components.scheme = "todo"
      components.host = "todo"

      var queryItems: [URLQueryItem] = []
      if let toDoLocalIdentifier {
         queryItems.append(URLQueryItem(name: "localIdentifier", value: toDoLocalIdentifier))
      }
      if let toDoCloudIdentifier {
         queryItems.append(URLQueryItem(name: "cloudID", value: toDoCloudIdentifier))
      }

      components.queryItems = queryItems.isEmpty ? nil : queryItems
      return components.url
   }

   fileprivate static var preview: ToDoLiveActivityAttributes {
      ToDoLiveActivityAttributes(
         toDoIdentifier: "preview",
         toDoLocalIdentifier: "preview",
         toDoCloudIdentifier: nil,
         createdAt: .now
      )
   }
}

extension ToDoLiveActivityAttributes.ContentState {
   fileprivate static var activePreview: ToDoLiveActivityAttributes.ContentState {
      ToDoLiveActivityAttributes.ContentState(
         title: "Review launch checklist",
         dueDate: .now.addingTimeInterval(1800),
         isOverdue: false,
         isTimeSensitive: true,
         updatedAt: .now
      )
   }

   fileprivate static var overduePreview: ToDoLiveActivityAttributes.ContentState {
      ToDoLiveActivityAttributes.ContentState(
         title: "Send vendor update",
         dueDate: .now.addingTimeInterval(-600),
         isOverdue: true,
         isTimeSensitive: true,
         updatedAt: .now
      )
   }
}

#Preview("Lock Screen", as: .content, using: ToDoLiveActivityAttributes.preview) {
   ToDoWidgetLiveActivity()
} contentStates: {
   ToDoLiveActivityAttributes.ContentState.activePreview
   ToDoLiveActivityAttributes.ContentState.overduePreview
}
