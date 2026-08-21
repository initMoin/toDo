import WidgetKit

struct ToDoWidgetProvider: AppIntentTimelineProvider {
   func placeholder(in context: Context) -> ToDoWidgetEntry {
      ToDoWidgetEntry(date: .now, configuration: ConfigurationAppIntent(), snapshot: .placeholder)
   }

   func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> ToDoWidgetEntry {
      ToDoWidgetEntry(
         date: .now,
         configuration: configuration,
         snapshot: WidgetToDoService().snapshot() ?? .empty
      )
   }

   func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<ToDoWidgetEntry> {
      let snapshot = WidgetToDoService().snapshot() ?? .empty
      let refreshInterval: TimeInterval = snapshot.items.isEmpty ? 300 : 900
      let nextRefresh = Date().addingTimeInterval(refreshInterval)
      return Timeline(
         entries: [ToDoWidgetEntry(date: .now, configuration: configuration, snapshot: snapshot)],
         policy: .after(nextRefresh)
      )
   }
}
