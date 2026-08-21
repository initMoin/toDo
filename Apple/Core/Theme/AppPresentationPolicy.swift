import CoreGraphics

nonisolated enum AppNavigationDirection: Equatable {
    case forward
    case backward
}

nonisolated enum AppAdaptiveWindowClass: Equatable {
    case narrow
    case standard
    case wide
}

nonisolated enum AppAdaptiveLayout {
    static let macMinimumWindowWidth: CGFloat = 760
    static let macIdealWindowWidth: CGFloat = 980
    static let macMaximumWindowWidth: CGFloat = 1_280
    static let macMinimumWindowHeight: CGFloat = 560
    static let macIdealWindowHeight: CGFloat = 700
    static let macMaximumWindowHeight: CGFloat = 900

    /// Below this width, primary actions stack to preserve complete labels and tap targets.
    static let narrowPhoneUpperBound: CGFloat = 360

    /// Side-by-side master/detail panes need enough room to remain independently legible.
    static let sideBySideMinimumWidth: CGFloat = 1_000

    static func macWindowClass(for width: CGFloat) -> AppAdaptiveWindowClass {
        if width < 860 { return .narrow }
        if width < 1_120 { return .standard }
        return .wide
    }

    static func macHorizontalPadding(for width: CGFloat) -> CGFloat {
        switch macWindowClass(for: width) {
        case .narrow:
            return 18
        case .standard:
            return 24
        case .wide:
            return 30
        }
    }

    static func usesSideBySideLayout(for width: CGFloat) -> Bool {
        width >= sideBySideMinimumWidth
    }
}
