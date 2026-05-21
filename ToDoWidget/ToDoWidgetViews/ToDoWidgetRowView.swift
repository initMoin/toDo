import AppIntents
import SwiftUI

struct ToDoWidgetRowView: View {
   let item: ToDoWidgetItem
   let titleSize: CGFloat
   let showsTag: Bool
   let isCompact: Bool
   var showsExpandedDetails: Bool = false

   var body: some View {
      VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
         HStack(alignment: .center, spacing: rowSpacing) {
            Image(systemName: "circle")
               .font(WidgetTypography.title(iconSize, relativeTo: .headline))
               .foregroundStyle(controlColor)
               .frame(width: iconFrame, height: iconFrame)
               .accessibilityLabel("Mark \(item.missive) done")

            HStack(alignment: .firstTextBaseline, spacing: 8) {
               Text(item.missive)
                  .font(WidgetTypography.title(titleSize, relativeTo: .headline))
                  .foregroundStyle(primaryTextColor)
                  .lineLimit(showsExpandedDetails ? 2 : 1)
                  .frame(maxWidth: .infinity, alignment: .leading)

               if showsTag, let tag = WidgetFormatting.tagSummary(for: item) {
                  Text(tag)
                     .font(WidgetTypography.accent(isCompact ? 10 : 12, relativeTo: .caption))
                     .foregroundStyle(tagTextColor)
                     .padding(.horizontal, isCompact ? 6 : 8)
                     .padding(.vertical, isCompact ? 2 : 3)
                     .background(tagBackgroundColor, in: Capsule())
                     .lineLimit(1)
                     .fixedSize(horizontal: true, vertical: false)
               }
            }
         }

         if hasMetadata {
            HStack(spacing: isCompact ? 8 : 12) {
               if let due = WidgetFormatting.compactDue(item.due) {
                  Label {
                     Text(due)
                  } icon: {
                     Image(systemName: "calendar")
                  }
                  .labelStyle(.titleAndIcon)
               }

               if item.isTimeSensitive {
                  Image(systemName: "clock.fill")
                     .foregroundStyle(timeSensitiveIndicatorColor)
                     .accessibilityLabel("Time-sensitive reminder")
               }
            }
            .font(WidgetTypography.body(isCompact ? 10 : 12, relativeTo: .caption))
            .foregroundStyle(metadataColor)
            .lineLimit(1)
            .padding(.leading, iconFrame + rowSpacing)
         }

         if showsExpandedDetails, let tag = WidgetFormatting.tagSummary(for: item), !showsTag {
            Text(tag)
               .font(WidgetTypography.accent(11, relativeTo: .caption))
               .foregroundStyle(tagTextColor)
               .padding(.horizontal, 8)
               .padding(.vertical, 3)
               .background(tagBackgroundColor, in: Capsule())
               .lineLimit(1)
               .padding(.leading, iconFrame + rowSpacing)
         }
      }
      .padding(.vertical, isCompact ? 5 : (showsExpandedDetails ? 9 : 6))
      .contentShape(Rectangle())
   }

   private var hasMetadata: Bool {
      item.due != nil || item.isTimeSensitive
   }

   private var iconSize: CGFloat {
      isCompact ? 17 : min(max(titleSize - 1, 18), 20)
   }

   private var iconFrame: CGFloat {
      isCompact ? 19 : 22
   }

   private var rowSpacing: CGFloat {
      isCompact ? 9 : 12
   }

   private var primaryTextColor: Color {
      WidgetPalette.textPrimary
   }

   private var metadataColor: Color {
      WidgetPalette.textSecondary
   }

   private var tagTextColor: Color {
      item.isOverdue ? WidgetPalette.onDestructive : WidgetPalette.textPrimary
   }

   private var tagBackgroundColor: Color {
      item.isOverdue ? WidgetPalette.destructive : WidgetPalette.surfaceMuted
   }

   private var timeSensitiveIndicatorColor: Color {
      WidgetPalette.destructive
   }

   private var controlColor: Color {
      return WidgetPalette.secondary
   }
}
