import Foundation

enum TagSortOption: String, CaseIterable, Identifiable {
    case name
    case created
    case linked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name:
            return "Name"
        case .created:
            return "Created"
        case .linked:
            return "Linked"
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
            return isAscending ? "A to Z" : "Z to A"
        case .created:
            return isAscending ? "Oldest to Newest" : "Newest to Oldest"
        case .linked:
            return isAscending ? "Least to Most" : "Most to Least"
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
}
