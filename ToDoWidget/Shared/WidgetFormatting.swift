import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct WidgetFormatting {
   static func compactDue(_ date: Date?) -> String? {
      guard let date else { return nil }
      let calendar = Calendar.current
      let time = date.formatted(date: .omitted, time: .shortened)
      if calendar.isDateInToday(date) { return "Today • \(time)" }
      if calendar.isDateInTomorrow(date) { return "Tomorrow • \(time)" }
      let weekday = date.formatted(.dateTime.weekday(.abbreviated))
      return "\(weekday) • \(time)"
   }

   static func tagSummary(for item: ToDoWidgetItem) -> String? {
      guard let first = item.tagNames.first else { return nil }
      let additionalCount = max(item.tagNames.count - 1, 0)
      return additionalCount > 0 ? "#\(first) +\(additionalCount)" : "#\(first)"
   }
}

enum WidgetPalette {
   static let main = Color(light: 0xE9A700, dark: 0xFFCC36)
   static let secondary = Color(light: 0x006CE7, dark: 0x67A9FF)
   static let tertiary = Color(light: 0x62C400, dark: 0x8FE35B)
   static let destructive = Color(light: 0xD40000, dark: 0xFF0A12)
   static let onDestructive = Color(light: 0xFFFFFF, dark: 0xFFFFFF)
   static let textPrimary = Color(light: 0x393939, dark: 0xF5F2EA)
   static let textSecondary = Color(light: 0x393939, dark: 0xF5F2EA, lightOpacity: 0.62, darkOpacity: 0.68)
   static let surface = Color(light: 0xFFFFFF, dark: 0x111316)
   static let surfaceElevated = Color(light: 0xF7F6F2, dark: 0x1A1D21)
   static let surfaceMuted = Color(light: 0x393939, dark: 0xF5F2EA, lightOpacity: 0.08, darkOpacity: 0.1)
   static let border = Color(light: 0x393939, dark: 0xF5F2EA, lightOpacity: 0.22, darkOpacity: 0.18)
   static let onAction = Color(light: 0xFFFFFF, dark: 0x111316)
}

enum WidgetTypography {
   static func title(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .headline) -> Font {
      .custom("CalSans-Regular", size: size, relativeTo: textStyle)
   }

   static func body(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
      .custom("Jura-Light", size: size, relativeTo: textStyle)
   }

   static func bodyStrong(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
      .custom("Jura-Regular", size: size, relativeTo: textStyle)
   }

   static func accent(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .subheadline) -> Font {
      .custom("Jura-Bold", size: size, relativeTo: textStyle)
   }
}

extension Color {
   init(hex: UInt, opacity: Double = 1) {
      self.init(
         .sRGB,
         red: Double((hex >> 16) & 0xff) / 255,
         green: Double((hex >> 8) & 0xff) / 255,
         blue: Double(hex & 0xff) / 255,
         opacity: opacity
      )
   }

   init(light: UInt, dark: UInt, lightOpacity: Double = 1, darkOpacity: Double = 1) {
      #if canImport(UIKit)
      self.init(uiColor: UIColor { traits in
         let hex = traits.userInterfaceStyle == .dark ? dark : light
         let opacity = traits.userInterfaceStyle == .dark ? darkOpacity : lightOpacity
         return UIColor(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: CGFloat(opacity)
         )
      })
      #else
      self.init(hex: light, opacity: lightOpacity)
      #endif
   }
}
