import Foundation

enum TagSortOption: String, CaseIterable, Identifiable {
    case name
    case created
    case linked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name:
            return String(localized: "Name")
        case .created:
            return String(localized: "Created")
        case .linked:
            return String(localized: "Linked")
        }
    }

    var defaultAscending: Bool {
        switch self {
        case .name:
            return true
        case .created:
            return false
        case .linked:
            return true
        }
    }

    func directionTitle(isAscending: Bool) -> String {
        switch self {
        case .name:
            return isAscending ? String(localized: "A to Z") : String(localized: "Z to A")
        case .created:
            return isAscending ? String(localized: "Oldest to Newest") : String(localized: "Newest to Oldest")
        case .linked:
            return isAscending ? String(localized: "Least to Most") : String(localized: "Most to Least")
        }
    }

    func arrowSystemImage(isAscending: Bool) -> String {
        isAscending == defaultAscending ? "arrowshape.down.circle.fill" : "arrowshape.up.circle.fill"
    }

    static func resolvedOption(from rawValue: String) -> TagSortOption {
        switch rawValue {
        case TagSortOption.name.rawValue:
            return .name
        case TagSortOption.created.rawValue:
            return .created
        case TagSortOption.linked.rawValue, "mostLinked", "leastLinked":
            return .linked
        default:
            return .name
        }
    }

    static func resolvedDirection(from rawValue: String, storedDirection: Bool?) -> Bool {
        switch rawValue {
        case "mostLinked":
            return false
        case "leastLinked":
            return true
        default:
            return storedDirection ?? resolvedOption(from: rawValue).defaultAscending
        }
    }

    static func sortedTags(
        _ tags: [Tag],
        option: TagSortOption,
        isAscending: Bool,
        linkedCount: (Tag) -> Int = { $0.linkedTaskCount }
    ) -> [Tag] {
        tags.sorted { lhs, rhs in
            switch option {
            case .name:
                let compare = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if compare == .orderedSame {
                    return lhs.createdAt > rhs.createdAt
                }
                return isAscending ? compare == .orderedAscending : compare == .orderedDescending
            case .created:
                if lhs.createdAt == rhs.createdAt {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return isAscending ? lhs.createdAt < rhs.createdAt : lhs.createdAt > rhs.createdAt
            case .linked:
                let leftCount = linkedCount(lhs)
                let rightCount = linkedCount(rhs)
                if leftCount == rightCount {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return isAscending ? leftCount < rightCount : leftCount > rightCount
            }
        }
    }
}
