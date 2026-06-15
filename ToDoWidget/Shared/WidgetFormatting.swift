import Foundation
import SwiftUI

struct WidgetFormatting {
   static var displayLocale: Locale {
      let identifier = Locale.preferredLanguages.first ?? Locale.current.identifier
      if identifier.hasPrefix("ar") {
         return Locale(identifier: "ar_SA@numbers=arab")
      }
      if identifier.hasPrefix("ur") {
         return Locale(identifier: "ur_PK@numbers=arabext")
      }
      if identifier.hasPrefix("hi") {
         return Locale(identifier: "hi_IN@numbers=deva")
      }
      if identifier.hasPrefix("th") {
         return Locale(identifier: "th_TH@numbers=thai")
      }
      return Locale(identifier: identifier)
   }

   static var displayCalendar: Calendar {
      let identifier = Locale.preferredLanguages.first ?? Locale.current.identifier
      var calendar = Calendar(identifier: identifier.hasPrefix("ar") ? .islamicUmmAlQura : .gregorian)
      calendar.locale = displayLocale
      calendar.timeZone = .current
      return calendar
   }

   static func numberString(_ number: Int) -> String {
      let formatter = NumberFormatter()
      formatter.locale = displayLocale
      formatter.numberStyle = .none
      return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
   }

   static func dateTimeString(_ date: Date) -> String {
      formatted(date, dateStyle: .medium, timeStyle: .short)
   }

   static func timeString(_ date: Date) -> String {
      formatted(date, dateStyle: .none, timeStyle: .short)
   }

   static func compactDue(_ date: Date?) -> String? {
      guard let date else { return nil }
      let calendar = displayCalendar
      let time = timeString(date)
      if calendar.isDateInToday(date) { return "\(String(localized: "Today")) • \(time)" }
      if calendar.isDateInTomorrow(date) { return "\(String(localized: "Tomorrow")) • \(time)" }
      let weekday = weekdayString(date)
      return "\(weekday) • \(time)"
   }

   static func tagSummary(for item: ToDoWidgetItem) -> String? {
      guard let first = item.tagNames.first else { return nil }
      let additionalCount = max(item.tagNames.count - 1, 0)
      return additionalCount > 0 ? "#\(first) +\(numberString(additionalCount))" : "#\(first)"
   }

   private static func weekdayString(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.locale = displayLocale
      formatter.calendar = displayCalendar
      formatter.setLocalizedDateFormatFromTemplate("EEE")
      return formatter.string(from: date)
   }

   private static func formatted(_ date: Date, dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
      let formatter = DateFormatter()
      formatter.locale = displayLocale
      formatter.calendar = displayCalendar
      formatter.dateStyle = dateStyle
      formatter.timeStyle = timeStyle
      return formatter.string(from: date)
   }
}

enum WidgetPalette {
   static let main = Color("widgetBrandMain")
   static let secondary = Color("widgetBrandSecondary")
   static let tertiary = Color("widgetBrandTertiary")
   static let destructive = Color("widgetDestructive")
   static let onDestructive = Color("widgetOnDestructive")
   static let textPrimary = Color("widgetTextPrimary")
   static let textSecondary = Color("widgetTextSecondary")
   static let surface = Color("widgetSurface")
   static let surfaceElevated = Color("widgetSurfaceElevated")
   static let surfaceMuted = Color("widgetSurfaceMuted")
   static let border = Color("widgetBorder")
   static let onAction = Color("widgetOnAction")
}

enum WidgetTypography {
   static func brand(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .headline) -> Font {
      .custom("CalSans-Regular", size: size, relativeTo: textStyle)
   }

   static func title(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .headline) -> Font {
      .custom("BebasNeue-Regular", size: size, relativeTo: textStyle)
   }

   static func body(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
      .custom("Jura-SemiBold", size: size, relativeTo: textStyle)
   }

   static func bodyStrong(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
      .custom("Jura-SemiBold", size: size, relativeTo: textStyle)
   }

   static func accent(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .subheadline) -> Font {
      .custom("Jura-SemiBold", size: size, relativeTo: textStyle)
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
}
