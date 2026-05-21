import SwiftUI
import WidgetKit

struct AccessoryInlineToDoWidgetView: View {
   let entry: ToDoWidgetEntry

   var body: some View {
      Text(inlineText)
         .widgetURL(WidgetDeepLinkRouter.listURL)
   }

   private var inlineText: String {
      if entry.filteredCount == 0 {
         return "ToDō clear"
      }

      if entry.snapshot.overdueCount > 0 {
         return "ToDō \(entry.snapshot.overdueCount) overdue"
      }

      if entry.snapshot.dueTodayCount > 0 {
         return "ToDō \(entry.snapshot.dueTodayCount) today"
      }

      return "ToDō \(entry.filteredCount)"
   }
}

struct AccessoryCircularToDoWidgetView: View {
   let entry: ToDoWidgetEntry

   var body: some View {
      ZStack {
         AccessoryWidgetBackground()

         VStack(spacing: 2) {
            Text("\(entry.filteredCount)")
               .font(.system(size: 18, weight: .bold, design: .rounded))
               .minimumScaleFactor(0.72)

            Image(systemName: accessoryIcon)
               .font(.system(size: 11, weight: .semibold))
         }
         .foregroundStyle(.primary)
      }
      .widgetURL(WidgetDeepLinkRouter.listURL)
   }

   private var accessoryIcon: String {
      if entry.snapshot.overdueCount > 0 {
         return "exclamationmark"
      }

      if entry.snapshot.timeSensitiveCount > 0 {
         return "clock.badge.exclamationmark"
      }

      return "checkmark"
   }
}

struct AccessoryRectangularToDoWidgetView: View {
   let entry: ToDoWidgetEntry

   var body: some View {
      VStack(alignment: .leading, spacing: 4) {
         HStack(spacing: 6) {
            Text("ToDō")
               .font(.system(size: 13, weight: .bold, design: .rounded))

            Spacer(minLength: 0)

            Text("\(entry.filteredCount)")
               .font(.system(size: 13, weight: .bold, design: .rounded))
         }

         if let firstItem = entry.filteredItems.first {
            Text(firstItem.missive)
               .font(.system(size: 12, weight: .semibold, design: .rounded))
               .lineLimit(1)

            Text(detailText(for: firstItem))
               .font(.system(size: 10, weight: .medium, design: .rounded))
               .foregroundStyle(.secondary)
               .lineLimit(1)
         } else {
            Text("No active ToDos")
               .font(.system(size: 12, weight: .semibold, design: .rounded))
               .lineLimit(1)

            Text("Clear for now")
               .font(.system(size: 10, weight: .medium, design: .rounded))
               .foregroundStyle(.secondary)
               .lineLimit(1)
         }
      }
      .widgetURL(entry.filteredItems.first.map(WidgetDeepLinkRouter.toDoURL(for:)) ?? WidgetDeepLinkRouter.listURL)
   }

   private func detailText(for item: ToDoWidgetItem) -> String {
      if item.isOverdue {
         return "Overdue"
      }

      if item.isDueToday {
         return item.due?.formatted(date: .omitted, time: .shortened) ?? "Due today"
      }

      if let due = item.due {
         return due.formatted(date: .abbreviated, time: .shortened)
      }

      if let tag = item.tagNames.first {
         return "#\(tag)"
      }

      return "Active"
   }
}
