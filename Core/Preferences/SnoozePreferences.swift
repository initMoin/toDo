import Foundation

enum SnoozeUnit: String, CaseIterable, Identifiable, Codable {
    case minutes
    case hours
    case days
    case weeks
    case months
    case years

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minutes: return "Minutes"
        case .hours: return "Hours"
        case .days: return "Days"
        case .weeks: return "Weeks"
        case .months: return "Months"
        case .years: return "Years"
        }
    }

    var singularTitle: String {
        switch self {
        case .minutes: return "Minute"
        case .hours: return "Hour"
        case .days: return "Day"
        case .weeks: return "Week"
        case .months: return "Month"
        case .years: return "Year"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .minutes: return .minute
        case .hours: return .hour
        case .days: return .day
        case .weeks: return .weekOfYear
        case .months: return .month
        case .years: return .year
        }
    }

    var defaultValues: [Int] {
        switch self {
        case .minutes: return [5, 15, 30]
        case .hours: return [1, 3, 6]
        case .days: return [1, 3, 6]
        case .weeks: return [1, 3, 6]
        case .months: return [1, 3, 6]
        case .years: return [1, 3, 6]
        }
    }

    func displayLabel(for value: Int) -> String {
        let unitLabel = value == 1 ? singularTitle.lowercased() : title.lowercased()
        return "\(value) \(unitLabel)"
    }
}

struct SnoozeOptionsStore: Codable, Equatable {
    var minutes: [Int]
    var hours: [Int]
    var days: [Int]
    var weeks: [Int]
    var months: [Int]
    var years: [Int]

    static let `default` = SnoozeOptionsStore(
        minutes: SnoozeUnit.minutes.defaultValues,
        hours: SnoozeUnit.hours.defaultValues,
        days: SnoozeUnit.days.defaultValues,
        weeks: SnoozeUnit.weeks.defaultValues,
        months: SnoozeUnit.months.defaultValues,
        years: SnoozeUnit.years.defaultValues
    )

    func values(for unit: SnoozeUnit) -> [Int] {
        switch unit {
        case .minutes: return minutes
        case .hours: return hours
        case .days: return days
        case .weeks: return weeks
        case .months: return months
        case .years: return years
        }
    }

    mutating func setValues(_ values: [Int], for unit: SnoozeUnit) {
        let normalized = values.filter { $0 > 0 }.uniquedAndSorted()
        switch unit {
        case .minutes: minutes = normalized
        case .hours: hours = normalized
        case .days: days = normalized
        case .weeks: weeks = normalized
        case .months: months = normalized
        case .years: years = normalized
        }
    }
}

enum SnoozePreferences {
    static let storageKey = "snoozeOptionsStorage"

    static var defaultEncodedString: String {
        encode(SnoozeOptionsStore.default)
    }

    static func decode(_ string: String) -> SnoozeOptionsStore {
        guard let data = string.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(SnoozeOptionsStore.self, from: data)
        else {
            return .default
        }

        var normalized = decoded
        for unit in SnoozeUnit.allCases {
            normalized.setValues(decoded.values(for: unit), for: unit)
        }
        return normalized
    }

    static func encode(_ store: SnoozeOptionsStore) -> String {
        guard let data = try? JSONEncoder().encode(store),
              let string = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return string
    }
}

private extension Array where Element == Int {
    func uniquedAndSorted() -> [Int] {
        Array(Set(self)).sorted()
    }
}
