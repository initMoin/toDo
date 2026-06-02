import Foundation

enum AppLocalization {
    nonisolated static var languageCode: String {
        Bundle.main.preferredLocalizations.first
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"
    }

    nonisolated static var isArabic: Bool {
        languageCode == "ar"
    }

    nonisolated static var isUrdu: Bool {
        languageCode == "ur"
    }

    nonisolated static var displayLocale: Locale {
        switch languageCode {
        case "ar":
            return Locale(identifier: "ar_SA@numbers=arab")
        case "ur":
            return Locale(identifier: "ur_PK@numbers=arabext")
        case "hi":
            return Locale(identifier: "hi_IN@numbers=deva")
        case "th":
            return Locale(identifier: "th_TH@numbers=thai")
        case "es":
            return Locale(identifier: "es_ES")
        case "it":
            return Locale(identifier: "it_IT")
        case "ja":
            return Locale(identifier: "ja_JP")
        case "ms":
            return Locale(identifier: "ms_MY")
        case "zh-Hans":
            return Locale(identifier: "zh_Hans_CN")
        default:
            return Locale(identifier: languageCode)
        }
    }

    nonisolated static var displayCalendar: Calendar {
        var calendar = Calendar(identifier: isArabic ? .islamicUmmAlQura : .gregorian)
        calendar.locale = displayLocale
        calendar.timeZone = .current
        return calendar
    }

    nonisolated static func dateTimeString(_ date: Date) -> String {
        formatted(date, dateStyle: .medium, timeStyle: .short)
    }

    nonisolated static func dateString(_ date: Date) -> String {
        formatted(date, dateStyle: .medium, timeStyle: .none)
    }

    nonisolated static func completeDateString(_ date: Date) -> String {
        formatted(date, dateStyle: .full, timeStyle: .none)
    }

    nonisolated static func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = displayLocale
        formatter.calendar = displayCalendar
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }

    nonisolated static func dayNumberString(_ date: Date) -> String {
        let number = displayCalendar.component(.day, from: date)
        return numberString(number)
    }

    nonisolated static func numberString(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = displayLocale
        formatter.numberStyle = .none
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    nonisolated static func decimalString(_ number: Double, maximumFractionDigits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.locale = displayLocale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    nonisolated static func localizedCount(_ count: Int, singularKey: String, pluralKey: String) -> String {
        String(
            format: String(localized: String.LocalizationValue(count == 1 ? singularKey : pluralKey)),
            numberString(count)
        )
    }

    private nonisolated static func formatted(_ date: Date, dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.locale = displayLocale
        formatter.calendar = displayCalendar
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }
}

enum AppTimeSource: String, CaseIterable, Identifiable {
    case location
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .location:
            return String(localized: "Location")
        case .system:
            return String(localized: "Device")
        }
    }
}

enum AppTimePreferences {
    nonisolated static let appleParkTimeZoneIdentifier = "America/Los_Angeles"
    nonisolated static let appleParkLabel = "Apple Park"

    nonisolated static func resolvedTimeSource(from rawValue: String) -> AppTimeSource {
        AppTimeSource(rawValue: rawValue) ?? .location
    }

    nonisolated static func resolvedTimeZone(sourceRawValue: String, locationTimeZoneIdentifier: String) -> TimeZone {
        switch resolvedTimeSource(from: sourceRawValue) {
        case .system:
            return .current
        case .location:
            return TimeZone(identifier: locationTimeZoneIdentifier)
                ?? TimeZone(identifier: appleParkTimeZoneIdentifier)
                ?? .current
        }
    }

    nonisolated static func dateString(now: Date = .now, sourceRawValue: String, locationTimeZoneIdentifier: String) -> String {
        var calendar = AppLocalization.displayCalendar
        calendar.timeZone = resolvedTimeZone(sourceRawValue: sourceRawValue, locationTimeZoneIdentifier: locationTimeZoneIdentifier)

        let formatter = DateFormatter()
        formatter.locale = AppLocalization.displayLocale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: now)
    }
}
