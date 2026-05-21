import SwiftUI

enum AppAnimation {
    static let snappyFast = Animation.snappy(duration: 0.2)
    static let snappyStandard = Animation.snappy(duration: 0.24)
    static let snappySection = Animation.snappy(duration: 0.28)
    static let tagTransition = Animation.spring(response: 0.42, dampingFraction: 0.9, blendDuration: 0.12)
    static let easeFast = Animation.easeInOut(duration: 0.2)
    static let easeStandard = Animation.easeInOut(duration: 0.28)
}

enum AppActionIntent {
    case neutral
    case proceed
    case cancel

    var pressedBackground: Color {
        switch self {
        case .neutral:
            return AppColor.actionSecondary
        case .proceed:
            return AppColor.actionSecondary
        case .cancel:
            return AppColor.actionDestructive
        }
    }

    var textForeground: Color {
        AppColor.textPrimary
    }
}

enum AppColor {
    static let main = Color("appBrandMain")
    static let secondary = Color("appBrandSecondary")
    static let white = Color("brandWhitish")
    static let black = Color("brandDarkish")
    static let tertiary = Color("appBrandTertiary")
    static let destructive = Color("appBrandDestructive")

    static let actionPrimary = Color("appActionPrimary")
    static let actionSecondary = secondary
    static let actionSuccess = tertiary
    static let actionNeutral = secondary
    static let actionDestructive = destructive
    static let onAction = Color("appOnAction")

    static let textPrimary = Color("appTextPrimary")
    static let textSecondary = Color("appTextSecondary")

    static let surface = Color("appSurface")
    static let surfaceElevated = Color("appSurfaceElevated")
    static let surfaceMuted = Color("appSurfaceMuted")
    static let border = Color("appBorder")
    static let iconCircle = actionPrimary
    static let shadow = Color("appShadow")
}

enum AppTypography {
    private static let displayFontName = "CalSans-Regular"
    private static let bodyLightFontName = "CarbonPlusLight"
    private static let bodyRegularFontName = "CarbonPlusRegular"
    private static let subtitleBoldFontName = "CarbonPlusBold"

    static func title(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .largeTitle) -> Font {
        .custom(displayFontName, size: size, relativeTo: textStyle)
    }

    static func headline(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .headline) -> Font {
        .custom(displayFontName, size: size, relativeTo: textStyle)
    }

    static func subtitle(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .subheadline) -> Font {
        .custom(subtitleBoldFontName, size: size, relativeTo: textStyle)
    }

    static func body(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(bodyFontName(for: textStyle), size: size, relativeTo: textStyle)
    }

    static func bodyStrong(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(bodyRegularFontName, size: size, relativeTo: textStyle)
    }

    private static func bodyFontName(for textStyle: Font.TextStyle) -> String {
        switch textStyle {
        case .caption, .caption2, .footnote:
            return bodyRegularFontName
        default:
            return bodyLightFontName
        }
    }
}

extension Font {
    static func appDisplay(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .title2) -> Font {
        AppTypography.headline(size, relativeTo: textStyle)
    }

    static func appTitle(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .largeTitle) -> Font {
        AppTypography.title(size, relativeTo: textStyle)
    }

    static func appHeadline(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .headline) -> Font {
        AppTypography.headline(size, relativeTo: textStyle)
    }

    static func appBody(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        AppTypography.body(size, relativeTo: textStyle)
    }

    static func appBodyStrong(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        AppTypography.bodyStrong(size, relativeTo: textStyle)
    }

    static func appSubtitle(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .subheadline) -> Font {
        AppTypography.subtitle(size, relativeTo: textStyle)
    }

    static func appAccent(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        AppTypography.subtitle(size, relativeTo: textStyle)
    }
}

extension View {
    func appBaseTypography() -> some View {
        self.font(.appBody(17))
    }

    func appNavigationChrome() -> some View {
        self
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
    }

    func appListChrome() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(AppColor.surface)
    }

    func interactionDisabled(_ disabled: Bool) -> some View {
        self
            .disabled(disabled)
            .allowsHitTesting(!disabled)
    }
}

struct AppLargeScreenTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.appTitle(34, relativeTo: .largeTitle))
            .foregroundStyle(AppColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 0)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

struct AppSettingsDetailHeader<Trailing: View>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let backAccessibilityLabel: String
    let background: Color
    private let trailing: Trailing

    init(
        title: String,
        backAccessibilityLabel: String = "Go back to Settings",
        background: Color = AppColor.main,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.backAccessibilityLabel = backAccessibilityLabel
        self.background = background
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColor.main)
                        .frame(width: 36, height: 36)
                        .background(headerButtonBackground, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(backAccessibilityLabel)

                Text(title)
                    .font(.appTitle(28, relativeTo: .title))
                    .foregroundStyle(headerForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 0)

                trailing
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 14)
            .background(background)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerForeground: Color {
        colorScheme == .dark ? AppColor.black : AppColor.white
    }

    private var headerButtonBackground: Color {
        colorScheme == .dark ? AppColor.black : AppColor.white
    }
}

extension AppSettingsDetailHeader where Trailing == EmptyView {
    init(
        title: String,
        backAccessibilityLabel: String = "Go back to Settings",
        background: Color = AppColor.main
    ) {
        self.init(
            title: title,
            backAccessibilityLabel: backAccessibilityLabel,
            background: background
        ) {
            EmptyView()
        }
    }
}

struct AppCircleActionButtonStyle: ButtonStyle {
    let intent: AppActionIntent
    var size: CGFloat = 34
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let foreground: Color = {
            guard isEnabled else { return AppColor.textSecondary }
            return AppColor.onAction
        }()

        let background: Color = {
            guard isEnabled else { return AppColor.iconCircle.opacity(0.28) }
            return configuration.isPressed ? intent.pressedBackground : AppColor.iconCircle
        }()

        return configuration.label
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(background)
            )
            .overlay(
                Circle()
                    .stroke(AppColor.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(AppAnimation.easeFast, value: configuration.isPressed)
    }
}

struct AppSemanticTextButtonStyle: ButtonStyle {
    let intent: AppActionIntent

    func makeBody(configuration: Configuration) -> some View {
        let foreground = configuration.isPressed ? AppColor.onAction : intent.textForeground
        let background = configuration.isPressed ? intent.pressedBackground : Color.clear
        return configuration.label
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(background)
            )
            .animation(AppAnimation.easeFast, value: configuration.isPressed)
    }
}

struct AppToolbarToggleButtonStyle: ButtonStyle {
    var isToggled: Bool
    var size: CGFloat = 34
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let isActive = isToggled && isEnabled
        let isPressed = configuration.isPressed && isEnabled
        let foreground = AppColor.onAction
        let background: Color = {
            guard isEnabled else { return AppColor.iconCircle.opacity(0.3) }
            if isActive || isPressed { return AppColor.secondary }
            return AppColor.iconCircle
        }()

        return configuration.label
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(background)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(AppAnimation.easeFast, value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.4)
    }
}
