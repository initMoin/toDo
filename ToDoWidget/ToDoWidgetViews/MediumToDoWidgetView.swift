import SwiftUI

struct MediumToDoWidgetView: View {
   let entry: ToDoWidgetEntry

   var body: some View {
      WidgetChrome {
         VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: "ToDō", count: entry.filteredCount)

            if entry.filteredItems.isEmpty {
               Spacer(minLength: 0)
               WidgetEmptyState()
               Spacer(minLength: 0)
            } else {
               WidgetScrollableToDoList(
                  items: entry.filteredItems,
                  maxVisibleItems: 2,
                  titleSize: 16,
                  showsTag: true,
                  isCompact: false,
                  showsExpandedDetails: false
               )
            }
         }
         .padding(12)
      }
   }
}
