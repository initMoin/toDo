import SwiftUI

struct SmallToDoWidgetView: View {
   let entry: ToDoWidgetEntry

   var body: some View {
      WidgetChrome {
         VStack(alignment: .leading, spacing: 7) {
            WidgetHeader(title: "ToDō", count: entry.filteredCount)

            if entry.filteredItems.isEmpty {
               Spacer(minLength: 0)
               WidgetEmptyState()
               Spacer(minLength: 0)
            } else {
               VStack(alignment: .leading, spacing: 6) {
                  ForEach(entry.filteredItems.prefix(2)) { item in
                     ToDoWidgetRowView(item: item, titleSize: 15, showsTag: false, isCompact: true)
                  }
               }
            }
         }
         .padding(11)
      }
   }
}
