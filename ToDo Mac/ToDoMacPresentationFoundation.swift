import SwiftUI

enum ToDoMacScreen: Hashable {
    case home
    case allToDos
    case settings
    case stats
}

enum ToDoMacPresentationLayer {
    case screen
    case detail
}

struct ToDoMacAdaptiveMetrics: Equatable {
    let viewportWidth: CGFloat

    var horizontalPadding: CGFloat {
        AppAdaptiveLayout.macHorizontalPadding(for: viewportWidth)
    }

    var verticalPadding: CGFloat {
        AppAdaptiveLayout.macWindowClass(for: viewportWidth) == .narrow ? 18 : 24
    }

    /// Hidden-title-bar windows still need deliberate space below the traffic lights.
    var titleBarClearance: CGFloat {
        // Keep the header clear of the traffic lights without recreating the
        // large top gap that the earlier Mac home header did not have.
        AppAdaptiveLayout.macWindowClass(for: viewportWidth) == .narrow ? 30 : 34
    }

    var usesWideSplit: Bool {
        AppAdaptiveLayout.usesSideBySideLayout(for: viewportWidth)
    }

    func maximumStageWidth(for screen: ToDoMacScreen, hasFocusedPane: Bool) -> CGFloat {
        let availableWidth = max(viewportWidth - (horizontalPadding * 2), 0)
        let preferredWidth: CGFloat

        switch screen {
        case .home:
            // Home uses compact, content-sized metric cards but still benefits
            // from the wider Mac viewport. Capping it below the window width
            // preserves hierarchy without recreating the old large right gap.
            preferredWidth = 1_120
        case .allToDos:
            preferredWidth = hasFocusedPane && usesWideSplit ? 1_220 : 940
        case .settings, .stats:
            // These dashboards use their inner surfaces to create hierarchy,
            // so they should occupy the available Mac content viewport.
            return availableWidth
        }

        return min(preferredWidth, availableWidth)
    }
}

enum ToDoMacTransitionResolver {
    static func transition(
        direction: AppNavigationDirection,
        layer: ToDoMacPresentationLayer,
        reduceMotion: Bool
    ) -> AnyTransition {
        guard !reduceMotion else { return .opacity }

        // Use the same travel distance in both directions. A shorter removal
        // leaves the previous surface visibly hanging behind the incoming one.
        let insertionDistance: CGFloat = layer == .screen ? 112 : 92
        let removalDistance: CGFloat = insertionDistance

        switch direction {
        case .forward:
            return .asymmetric(
                insertion: .offset(x: insertionDistance),
                removal: .offset(x: -removalDistance)
            )
        case .backward:
            return .asymmetric(
                insertion: .offset(x: -removalDistance),
                removal: .offset(x: insertionDistance)
            )
        }
    }
}

struct ToDoMacPresentationNotice: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

struct ToDoMacAdaptiveStage<Content: View>: View {
    let metrics: ToDoMacAdaptiveMetrics
    let screen: ToDoMacScreen
    let hasFocusedPane: Bool
    private let content: Content

    init(
        metrics: ToDoMacAdaptiveMetrics,
        screen: ToDoMacScreen,
        hasFocusedPane: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.metrics = metrics
        self.screen = screen
        self.hasFocusedPane = hasFocusedPane
        self.content = content()
    }

    var body: some View {
        content
            .frame(
                maxWidth: metrics.maximumStageWidth(for: screen, hasFocusedPane: hasFocusedPane),
                alignment: .topLeading
            )
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.top, metrics.titleBarClearance)
            .padding(.bottom, metrics.verticalPadding)
            .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct ToDoMacTransientNotice: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.todoMacBodyStrong(14))
                .foregroundStyle(ToDoMacPalette.brandBlue)

            Text(message)
                .font(.todoMacBodyStrong(13))
                .foregroundStyle(ToDoMacPalette.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ToDoMacPalette.panel, in: Capsule())
        .overlay(Capsule().stroke(ToDoMacPalette.brandBlue.opacity(0.24), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}
