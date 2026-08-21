import SwiftUI

struct LargeToDoWidgetView: View {
   let entry: ToDoWidgetEntry

   var body: some View {
      WidgetChrome {
         VStack(alignment: .leading, spacing: 9) {
            WidgetHeader(title: "ToDō", count: entry.filteredCount)

            if entry.filteredItems.isEmpty {
               Spacer(minLength: 0)
               WidgetEmptyState()
               Spacer(minLength: 0)
            } else {
               WidgetScrollableToDoList(
                  items: entry.filteredItems,
                  maxVisibleItems: 3,
                  titleSize: 20,
                  showsTag: true,
                  isCompact: false,
                  showsExpandedDetails: true
               )
            }

            Spacer(minLength: 0)
         }
         .frame(maxHeight: .infinity, alignment: .top)
         .padding(13)
      }
   }
}
