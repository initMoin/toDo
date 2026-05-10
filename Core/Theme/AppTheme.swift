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
    // Core palette
    static let main = Color(red: 233 / 255, green: 167 / 255, blue: 0 / 255)       // #E9A700
    static let secondary = Color(red: 0 / 255, green: 108 / 255, blue: 231 / 255)   // #006CE7
    static let white = Color(red: 235 / 255, green: 235 / 255, blue: 235 / 255)     // #EBEBEB
    static let black = Color(red: 57 / 255, green: 57 / 255, blue: 57 / 255)        // #393939
    static let tertiary = Color(red: 98 / 255, green: 196 / 255, blue: 0 / 255)     // #62C400
    static let destructive = Color(red: 212 / 255, green: 0 / 255, blue: 0 / 255)   // #D40000

    static let actionPrimary = black
    static let actionSecondary = secondary
    static let actionSuccess = tertiary
    static let actionNeutral = secondary
    static let actionDestructive = destructive
    static let onAction = white

    static let textPrimary = black
    static let textSecondary = black.opacity(0.62)

    static let surface = white
    static let surfaceMuted = black.opacity(0.08)
    static let border = black.opacity(0.22)
    static let iconCircle = black
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
