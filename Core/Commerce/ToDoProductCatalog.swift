import Foundation

#if !os(watchOS)
import StoreKit
import SwiftUI
#endif

enum ToDoProductCatalog {
    enum ProductID: String, CaseIterable, Sendable {
        case plusMonthly = "dev.iamshift.todo.plus.monthly"
        case plusYearly = "dev.iamshift.todo.plus.yearly"
        case plusLifetime = "dev.iamshift.todo.plus.lifetime"
        case appreciationCoffee = "dev.iamshift.todo.appreciation.coffee"
        case appreciationLunch = "dev.iamshift.todo.appreciation.lunch"
        case appreciationPatron = "dev.iamshift.todo.appreciation.patron"
        case appreciationFounding = "dev.iamshift.todo.appreciation.founding"

        var isPlus: Bool {
            switch self {
            case .plusMonthly, .plusYearly, .plusLifetime:
                true
            default:
                false
            }
        }

        var isRepeatableAppreciation: Bool {
            switch self {
            case .appreciationCoffee, .appreciationLunch, .appreciationPatron:
                true
            default:
                false
            }
        }
    }

    static let allProductIDs = Set(ProductID.allCases.map(\.rawValue))
    static let plusProductIDs: Set<String> = [
        ProductID.plusMonthly.rawValue,
        ProductID.plusYearly.rawValue,
        ProductID.plusLifetime.rawValue,
    ]
    static let introductoryOfferProductIDs: Set<String> = [
        ProductID.plusMonthly.rawValue,
        ProductID.plusYearly.rawValue,
    ]
    static let restorableProductIDs: Set<String> = plusProductIDs.union([
        ProductID.appreciationFounding.rawValue,
    ])
    static let appreciationProductIDs: [String] = [
        ProductID.appreciationCoffee.rawValue,
        ProductID.appreciationLunch.rawValue,
        ProductID.appreciationPatron.rawValue,
        ProductID.appreciationFounding.rawValue,
    ]
}

extension ToDoProductCatalog.ProductID: Identifiable {
    var id: String { rawValue }
}

#if !os(watchOS)
/// Presents Apple's own offer-code sheet without introducing a UIKit/AppKit bridge.
/// StoreKit transaction updates remain the source of truth after the sheet closes.
struct ToDoOfferCodeRedemptionModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onCompletion: @MainActor () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 27.0, *) {
            content.offerCodeRedemption(options: [], isPresented: $isPresented) { _ in
                onCompletion()
            }
        } else {
            content.offerCodeRedemption(isPresented: $isPresented) { _ in
                onCompletion()
            }
        }
        #elseif os(macOS)
        if #available(macOS 27.0, *) {
            content.offerCodeRedemption(options: [], isPresented: $isPresented) { _ in
                onCompletion()
            }
        } else {
            content.offerCodeRedemption(isPresented: $isPresented) { _ in
                onCompletion()
            }
        }
        #else
        content
        #endif
    }
}
#endif

nonisolated enum ToDoCollaborationRole: String, CaseIterable, Codable, Sendable {
    case owner
    case user
}

struct ToDoCapabilities: Equatable, Sendable {
    enum AccessLevel: String, Equatable, Sendable {
        case free
        case plus
        case legacy
    }

    static let freeInvitationLimit = 2

    let accessLevel: AccessLevel
    let hasWebAccess: Bool
    let outgoingInvitationLimit: Int?
    let canJoinUnlimitedSharedLists: Bool
    let availableRoles: Set<ToDoCollaborationRole>

    static let free = ToDoCapabilities(
        accessLevel: .free,
        hasWebAccess: false,
        outgoingInvitationLimit: freeInvitationLimit,
        canJoinUnlimitedSharedLists: true,
        availableRoles: [.owner, .user]
    )

    static let plus = ToDoCapabilities(
        accessLevel: .plus,
        hasWebAccess: true,
        outgoingInvitationLimit: nil,
        canJoinUnlimitedSharedLists: true,
        availableRoles: [.owner, .user]
    )

    // Legacy access is intentionally distinct from purchased toDō+. It shares
    // today's capabilities but remains the durable override for future paid gates.
    static let legacy = ToDoCapabilities(
        accessLevel: .legacy,
        hasWebAccess: true,
        outgoingInvitationLimit: nil,
        canJoinUnlimitedSharedLists: true,
        availableRoles: [.owner, .user]
    )

    var includesFuturePaidFeatures: Bool {
        accessLevel == .legacy
    }
}
