import AppIntents
import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

struct ToDoWidgetLiveActivity: Widget {
   var body: some WidgetConfiguration {
      ActivityConfiguration(for: ToDoLiveActivityAttributes.self) { context in
         ToDoLiveActivitySurfaceView(context: context)
            .widgetURL(context.attributes.deepLinkURL)
            .activitySystemActionForegroundColor(Color(hex: 0xE9A700))
      } dynamicIsland: { context in
         DynamicIsland {
            DynamicIslandExpandedRegion(.center) {
               ToDoDynamicIslandTitleRow(context: context)
            }

            DynamicIslandExpandedRegion(.bottom) {
               VStack(spacing: 3) {
                  LiveActivityDueDateTimeText(dueDate: context.state.dueDate, size: 13)
                     .frame(maxWidth: .infinity, alignment: .leading)

                  LiveActivityAnimatedCountdownView(
                     dueDate: context.state.dueDate,
                     isOverdue: context.state.isOverdue,
                     size: 18,
                     weight: .semibold
                  )
                  .frame(maxWidth: .infinity, alignment: .center)
               }
            }
         } compactLeading: {
            Image(systemName: context.state.statusSystemImage)
               .foregroundStyle(context.state.accentColor)
         } compactTrailing: {
            LiveActivityCompactCountdownView(dueDate: context.state.dueDate, isOverdue: context.state.isOverdue)
               .foregroundStyle(Color(hex: 0xEBEBEB))
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
      switch activityFamily {
      case .small:
         ToDoWatchLiveActivityView(context: context)
      default:
         ToDoLiveActivityLockScreenView(context: context)
      }
   }
}

private struct ToDoLiveActivityLockScreenView: View {
   @Environment(\.horizontalSizeClass) private var horizontalSizeClass

   let context: ActivityViewContext<ToDoLiveActivityAttributes>

   var body: some View {
      if usesRegularWidthLayout {
         regularWidthLayout
      } else {
         compactWidthLayout
      }
   }

   private var usesRegularWidthLayout: Bool {
      horizontalSizeClass == .regular
   }

   private var compactWidthLayout: some View {
      VStack(alignment: .leading, spacing: 8) {
         HStack(alignment: .center, spacing: 8) {
            statusIcon(size: 20, frame: 28)

            VStack(alignment: .leading, spacing: 2) {
               Text(context.state.title)
                  .font(.system(size: 18, weight: .semibold, design: .rounded))
                  .foregroundStyle(.white)
                  .lineLimit(1)
                  .minimumScaleFactor(0.82)

               LiveActivityDueDateTimeText(dueDate: context.state.dueDate, size: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
         }
         .frame(maxWidth: .infinity, alignment: .leading)

         LiveActivityAnimatedCountdownView(
            dueDate: context.state.dueDate,
            isOverdue: context.state.isOverdue,
            size: 17,
            weight: .semibold
         )
         .frame(maxWidth: .infinity, alignment: .center)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .frame(minWidth: 220, idealWidth: 280, maxWidth: 360, alignment: .leading)
   }

   private var regularWidthLayout: some View {
      VStack(alignment: .leading, spacing: 12) {
         HStack(alignment: .center, spacing: 10) {
            statusIcon(size: 22, frame: 32)

            VStack(alignment: .leading, spacing: 3) {
               Text(context.state.title)
                  .font(.custom("CalSans-Regular", size: 22, relativeTo: .title3))
                  .foregroundStyle(.white)
                  .lineLimit(1)
                  .minimumScaleFactor(0.78)
                  .frame(maxWidth: .infinity, alignment: .leading)

               Text(context.state.statusTitle)
                  .font(.custom("CarbonPlusBold", size: 12, relativeTo: .caption))
                  .foregroundStyle(context.state.accentColor)
                  .textCase(.uppercase)
                  .lineLimit(1)

               LiveActivityDueDateTimeText(dueDate: context.state.dueDate, size: 15)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
         }
         .frame(maxWidth: .infinity, alignment: .leading)

         LiveActivityAnimatedCountdownView(
            dueDate: context.state.dueDate,
            isOverdue: context.state.isOverdue,
            size: 22,
            weight: .semibold
         )
         .frame(maxWidth: .infinity, alignment: .center)
      }
      .padding(.horizontal, 22)
      .padding(.vertical, 16)
      .frame(maxWidth: .infinity, alignment: .leading)
   }

   private func statusIcon(size: CGFloat, frame: CGFloat) -> some View {
      Image(systemName: context.state.statusSystemImage)
         .font(.system(size: size, weight: .semibold))
         .foregroundStyle(context.state.accentColor)
         .frame(width: frame, height: frame)
   }
}

private struct ToDoWatchLiveActivityView: View {
   let context: ActivityViewContext<ToDoLiveActivityAttributes>

   var body: some View {
      VStack(alignment: .leading, spacing: 8) {
         HStack(alignment: .center, spacing: 7) {
            Image(systemName: context.state.statusSystemImage)
               .font(.system(size: 17, weight: .bold))
               .foregroundStyle(context.state.accentColor)
               .frame(width: 22, height: 22)

            Text(context.state.title)
               .font(.custom("CalSans-Regular", size: 18, relativeTo: .headline))
               .foregroundStyle(Color(hex: 0xEBEBEB))
               .lineLimit(2)
               .minimumScaleFactor(0.78)
         }

         HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
               Text(context.state.watchStatusText)
                  .font(.custom("CarbonPlusBold", size: 10, relativeTo: .caption2))
                  .foregroundStyle(context.state.accentColor)
                  .textCase(.uppercase)

               LiveActivityDueDateTimeText(dueDate: context.state.dueDate, size: 10)
            }

            Spacer(minLength: 4)

            LiveActivityAnimatedCountdownView(
               dueDate: context.state.dueDate,
               isOverdue: context.state.isOverdue,
               size: 12,
               weight: .semibold
            )
               .foregroundStyle(Color(hex: 0xEBEBEB))
         }

         Button(intent: CompleteWidgetToDoIntent(
            toDoID: context.attributes.toDoLocalIdentifier ?? context.attributes.toDoIdentifier,
            cloudID: context.attributes.toDoCloudIdentifier.flatMap(UUID.init(uuidString:))
         )) {
            Image(systemName: "checkmark")
               .font(.system(size: 12, weight: .bold))
               .foregroundStyle(Color(hex: 0x101010))
               .frame(width: 24, height: 24)
               .background(context.state.accentColor, in: Circle())
         }
         .buttonStyle(.plain)
         .accessibilityLabel("Mark Done")
         .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
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

         Text(context.state.title)
            .font(.custom("CalSans-Regular", size: 17, relativeTo: .headline))
            .foregroundStyle(Color(hex: 0xEBEBEB))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
         .frame(maxWidth: .infinity, alignment: .leading)
         .clipped()
      }
      .padding(.horizontal, 2)
   }
}

private struct LiveActivityDueDateTimeText: View {
   let dueDate: Date?
   let size: CGFloat

   var body: some View {
      if let dueDate {
         Text("Due \(dueDate.formatted(date: .abbreviated, time: .shortened))")
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(hex: 0xD8D8D8))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
      } else {
         Text("No Due Date")
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(hex: 0xAFAFAF))
            .lineLimit(1)
      }
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

private struct LiveActivitySegmentedCountdownView: View {
   let dueDate: Date?
   let isOverdue: Bool
   let size: CGFloat

   var body: some View {
      TimelineView(.periodic(from: .now, by: 1)) { timeline in
         let components = countdownComponents(now: timeline.date)
         HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(components.hours)
               .foregroundStyle(.white)
            Text(":")
               .foregroundStyle(Color(hex: 0xAFAFAF))
            Text(components.minutes)
               .foregroundStyle(.white)
            Text(":")
               .foregroundStyle(Color(hex: 0xAFAFAF))
            Text(components.seconds)
               .foregroundStyle(Color(hex: 0xAFAFAF))
         }
         .font(.system(size: size, weight: .bold, design: .rounded))
         .monospacedDigit()
         .frame(maxWidth: .infinity, alignment: .center)
      }
   }

   private func countdownComponents(now: Date) -> (hours: String, minutes: String, seconds: String) {
      guard let dueDate else {
         return ("--", "--", "--")
      }

      let interval = max(isOverdue ? now.timeIntervalSince(dueDate) : dueDate.timeIntervalSince(now), 0)
      let totalSeconds = Int(interval.rounded(.down))
      let hours = totalSeconds / 3600
      let minutes = (totalSeconds % 3600) / 60
      let seconds = totalSeconds % 60

      return (
         String(format: "%02d", hours),
         String(format: "%02d", minutes),
         String(format: "%02d", seconds)
      )
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
      isOverdue ? "Overdue" : "Time-Sensitive"
   }

   var shortStatusTitle: String {
      isOverdue ? "Due" : "Now"
   }

   var statusSystemImage: String {
      isOverdue ? "exclamationmark.circle.fill" : "clock.fill"
   }

   var accentColor: Color {
      isOverdue ? Color(hex: 0xD40000) : Color(hex: 0xE9A700)
   }

   var watchStatusText: String {
      isOverdue ? "Overdue" : "Due Soon"
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
