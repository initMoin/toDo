import SwiftUI
import WidgetKit

struct WidgetChrome<Content: View>: View {
   let content: Content

   init(@ViewBuilder content: () -> Content) {
      self.content = content()
   }

   var body: some View {
      content
         .containerBackground(for: .widget) {
            WidgetSurfaceBackground()
         }
   }
}

private struct WidgetSurfaceBackground: View {
   var body: some View {
      WidgetPalette.surface
   }
}

struct WidgetHeader: View {
   @Environment(\.widgetFamily) private var family
   let title: String
   let count: Int

   var body: some View {
      HStack(alignment: .center, spacing: 10) {
         VStack(alignment: .leading, spacing: 4) {
            titleText

            Rectangle()
               .fill(WidgetPalette.main)
               .frame(width: accentWidth, height: 3)
               .clipShape(Capsule())
         }

         Spacer(minLength: 6)

         Text("\(count)")
            .font(WidgetTypography.title(countSize, relativeTo: .title3))
            .foregroundStyle(WidgetPalette.secondary)
            .monospacedDigit()
            .frame(minWidth: countBadgeSize, minHeight: countBadgeSize)
            .accessibilityLabel("\(count) incomplete ToDos")
      }
      .padding(.horizontal, headerHorizontalPadding)
      .padding(.vertical, headerVerticalPadding)
   }

   private var titleText: some View {
      HStack(spacing: 0) {
         Text("ToD")
            .foregroundStyle(WidgetPalette.textPrimary)
         Text("ō")
            .foregroundStyle(WidgetPalette.main)
      }
      .font(WidgetTypography.title(titleSize, relativeTo: .title2))
      .lineLimit(1)
      .accessibilityLabel("ToDō")
   }

   private var titleSize: CGFloat {
      switch family {
      case .systemSmall:
         return 23
      case .systemMedium:
         return 26
      default:
         return 28
      }
   }

   private var countSize: CGFloat {
      switch family {
      case .systemSmall:
         return 17
      case .systemMedium:
         return 21
      default:
         return 23
      }
   }

   private var countBadgeSize: CGFloat {
      family == .systemSmall ? 22 : 28
   }

   private var accentWidth: CGFloat {
      family == .systemSmall ? 28 : 34
   }

   private var headerHorizontalPadding: CGFloat {
      0
   }

   private var headerVerticalPadding: CGFloat {
      0
   }
}

struct WidgetEmptyState: View {
   var body: some View {
      VStack(alignment: .leading, spacing: 6) {
         Text("Clear")
            .font(WidgetTypography.title(24, relativeTo: .title3))
            .foregroundStyle(WidgetPalette.textPrimary)
         Text("No pending ToDos.")
            .font(WidgetTypography.bodyStrong(12, relativeTo: .caption))
            .foregroundStyle(WidgetPalette.textSecondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.top, 4)
   }
}

struct WidgetScrollableToDoList: View {
   let items: [ToDoWidgetItem]
   let maxVisibleItems: Int
   let titleSize: CGFloat
   let showsTag: Bool
   let isCompact: Bool
   var showsExpandedDetails: Bool = false

   var body: some View {
      VStack(alignment: .leading, spacing: showsExpandedDetails ? 10 : 7) {
         ForEach(items.prefix(maxVisibleItems)) { item in
            ToDoWidgetRowView(
               item: item,
               titleSize: titleSize,
               showsTag: showsTag,
               isCompact: isCompact,
               showsExpandedDetails: showsExpandedDetails
            )
         }
      }
   }
}
