import Foundation

enum AppTimeSource: String, CaseIterable, Identifiable {
    case location
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .location:
            return "Location"
        case .system:
            return "System"
        }
    }
}

enum AppTimePreferences {
    static let appleParkTimeZoneIdentifier = "America/Los_Angeles"
    static let appleParkLabel = "Apple Park"

    static func resolvedTimeSource(from rawValue: String) -> AppTimeSource {
        AppTimeSource(rawValue: rawValue) ?? .location
    }

    static func resolvedTimeZone(sourceRawValue: String, locationTimeZoneIdentifier: String) -> TimeZone {
        switch resolvedTimeSource(from: sourceRawValue) {
        case .system:
            return .current
        case .location:
            return TimeZone(identifier: locationTimeZoneIdentifier)
                ?? TimeZone(identifier: appleParkTimeZoneIdentifier)
                ?? .current
        }
    }

    static func dateString(now: Date = .now, sourceRawValue: String, locationTimeZoneIdentifier: String) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted)
        style.timeZone = resolvedTimeZone(sourceRawValue: sourceRawValue, locationTimeZoneIdentifier: locationTimeZoneIdentifier)
        return now.formatted(style)
    }
}
