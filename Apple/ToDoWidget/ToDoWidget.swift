import SwiftUI
import WidgetKit

struct ToDoWidget: Widget {
   let kind = ToDoWidgetSharedConstants.widgetKind

   var body: some WidgetConfiguration {
      AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: ToDoWidgetProvider()) { entry in
         ToDoWidgetEntryView(entry: entry)
      }
      .configurationDisplayName("toDō")
      .description("See and complete pending toDōs.")
      .supportedFamilies([
         .systemSmall,
         .systemMedium,
         .systemLarge,
         .accessoryInline,
         .accessoryCircular,
         .accessoryRectangular
      ])
      .contentMarginsDisabled()
   }
}

struct ToDoWidgetEntryView: View {
   @Environment(\.widgetFamily) private var family
   let entry: ToDoWidgetEntry

   var body: some View {
      switch family {
      case .accessoryInline:
         AccessoryInlineToDoWidgetView(entry: entry)
      case .accessoryCircular:
         AccessoryCircularToDoWidgetView(entry: entry)
      case .accessoryRectangular:
         AccessoryRectangularToDoWidgetView(entry: entry)
      case .systemSmall:
         SmallToDoWidgetView(entry: entry)
      case .systemLarge:
         LargeToDoWidgetView(entry: entry)
      default:
         MediumToDoWidgetView(entry: entry)
      }
   }
}

#Preview(as: .systemSmall) {
   ToDoWidget()
} timeline: {
   ToDoWidgetEntry(date: .now, configuration: ConfigurationAppIntent(), snapshot: .placeholder)
}
