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

enum AppThemeOption: String, CaseIterable, Identifiable {
    case classic
    case coastal
    case ember
    case orchard
    case midnight
    case shift

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic:
            return String(localized: "Classic")
        case .coastal:
            return String(localized: "Coastal")
        case .ember:
            return String(localized: "Ember")
        case .orchard:
            return String(localized: "Orchard")
        case .midnight:
            return String(localized: "Midnight")
        case .shift:
            return String(localized: "shift")
        }
    }

    var subtitle: String {
        switch self {
        case .classic:
            return String(localized: "The original toDō yellow and blue.")
        case .coastal:
            return String(localized: "Blue-green focus with a sunlit accent.")
        case .ember:
            return String(localized: "Warm, loud, and built for urgency.")
        case .orchard:
            return String(localized: "Fresh greens with a calm workday feel.")
        case .midnight:
            return String(localized: "Deep blue accents with electric highlights.")
        case .shift:
            return String(localized: "Bold red, dark ink, clean white, and electric lime.")
        }
    }

    var palette: AppThemePalette {
        switch self {
        case .classic:
            return .assetBacked
        case .coastal:
            return AppThemePalette(
                main: Color(red: 0.08, green: 0.55, blue: 0.68),
                secondary: Color(red: 0.07, green: 0.38, blue: 0.64),
                tertiary: Color(red: 0.98, green: 0.73, blue: 0.18),
                destructive: Color(red: 0.88, green: 0.20, blue: 0.24),
                actionPrimary: Color(red: 0.05, green: 0.47, blue: 0.68),
                onAction: .white,
                iconAccent: Color(red: 0.05, green: 0.47, blue: 0.68)
            )
        case .ember:
            return AppThemePalette(
                main: Color(red: 0.93, green: 0.31, blue: 0.12),
                secondary: Color(red: 0.98, green: 0.58, blue: 0.16),
                tertiary: Color(red: 0.35, green: 0.12, blue: 0.08),
                destructive: Color(red: 0.78, green: 0.05, blue: 0.07),
                actionPrimary: Color(red: 0.93, green: 0.31, blue: 0.12),
                onAction: .white,
                iconAccent: Color(red: 0.82, green: 0.22, blue: 0.10)
            )
        case .orchard:
            return AppThemePalette(
                main: Color(red: 0.20, green: 0.56, blue: 0.28),
                secondary: Color(red: 0.56, green: 0.69, blue: 0.24),
                tertiary: Color(red: 0.95, green: 0.65, blue: 0.18),
                destructive: Color(red: 0.75, green: 0.14, blue: 0.16),
                actionPrimary: Color(red: 0.14, green: 0.48, blue: 0.28),
                onAction: .white,
                iconAccent: Color(red: 0.14, green: 0.48, blue: 0.28)
            )
        case .midnight:
            return AppThemePalette(
                main: Color(red: 0.18, green: 0.23, blue: 0.72),
                secondary: Color(red: 0.17, green: 0.65, blue: 0.88),
                tertiary: Color(red: 0.90, green: 0.78, blue: 0.23),
                destructive: Color(red: 0.95, green: 0.18, blue: 0.29),
                actionPrimary: Color(red: 0.22, green: 0.31, blue: 0.86),
                onAction: .white,
                iconAccent: Color(red: 0.22, green: 0.31, blue: 0.86)
            )
        case .shift:
            return AppThemePalette(
                main: AppThemePalette.color(hex: 0xB50000),
                secondary: Color("shiftThemeSecondary"),
                tertiary: AppThemePalette.color(hex: 0xC6F91F),
                destructive: AppThemePalette.color(hex: 0xB50000),
                actionPrimary: AppThemePalette.color(hex: 0xB50000),
                onAction: AppThemePalette.color(hex: 0xFCFCFC),
                iconAccent: AppThemePalette.color(hex: 0xB50000)
            )
        }
    }
}

struct AppThemePalette {
    let main: Color
    let secondary: Color
    let tertiary: Color
    let destructive: Color
    let actionPrimary: Color
    let onAction: Color
    let iconAccent: Color

    static let assetBacked = AppThemePalette(
        main: Color("appBrandMain"),
        secondary: Color("appBrandSecondary"),
        tertiary: Color("appBrandTertiary"),
        destructive: Color("appBrandDestructive"),
        actionPrimary: Color("appActionPrimary"),
        onAction: Color("appOnAction"),
        iconAccent: Color("appActionPrimary")
    )

    static func color(hex: Int) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

enum AppColor {
    private static var selectedTheme: AppThemeOption {
        let rawValue = UserDefaults.standard.string(forKey: AppPreferences.Keys.appTheme)
        return rawValue.flatMap(AppThemeOption.init(rawValue:)) ?? .classic
    }

    private static var palette: AppThemePalette {
        selectedTheme.palette
    }

    static var main: Color { palette.main }
    static var secondary: Color { palette.secondary }
    static let white = Color("brandWhitish")
    static let black = Color("brandDarkish")
    static var tertiary: Color { palette.tertiary }
    static var destructive: Color { palette.destructive }

    static var actionPrimary: Color { palette.actionPrimary }
    static var actionSecondary: Color { secondary }
    static var actionSuccess: Color { tertiary }
    static var actionNeutral: Color { secondary }
    static var actionDestructive: Color { destructive }
    static var onAction: Color { palette.onAction }
    static func brandYellowForeground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? black : white
    }

    static let textPrimary = Color("appTextPrimary")
    static let textSecondary = Color("appTextSecondary")

    static let surface = Color("appSurface")
    static let surfaceElevated = Color("appSurfaceElevated")
    static let surfaceMuted = Color("appSurfaceMuted")
    static let border = Color("appBorder")
    static var iconCircle: Color { palette.iconAccent }
    static var iconAccent: Color { palette.iconAccent }
    static let shadow = Color("appShadow")

    static func headerForeground(for colorScheme: ColorScheme) -> Color {
        selectedTheme == .classic && colorScheme == .dark ? black : white
    }

    static func headerControlForeground(for colorScheme: ColorScheme) -> Color {
        selectedTheme == .classic ? main : white
    }

    static func headerControlBackground(for colorScheme: ColorScheme) -> Color {
        if selectedTheme == .classic {
            return colorScheme == .dark ? black : white
        }

        return white.opacity(0.18)
    }
}

enum AppTypography {
    private static let brandFontName = "CalSans-Regular"
    private static let displayFontName = "BebasNeue-Regular"
    private static let uiFamilyName = "Jura"
    private static let aleoFamilyName = "Aleo"

    static func brand(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .largeTitle) -> Font {
        .custom(brandFontName, size: size, relativeTo: textStyle)
    }

    static func display(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .title2) -> Font {
        .custom(displayFontName, size: size, relativeTo: textStyle)
    }

    static func button(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .headline) -> Font {
        .custom(displayFontName, size: size, relativeTo: textStyle)
    }

    static func title(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .largeTitle) -> Font {
        .custom(uiFamilyName, size: size, relativeTo: textStyle)
            .weight(.bold)
    }

    static func headline(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .headline) -> Font {
        .custom(uiFamilyName, size: size, relativeTo: textStyle)
            .weight(.semibold)
    }

    static func subtitle(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .subheadline) -> Font {
        .custom(uiFamilyName, size: size, relativeTo: textStyle)
            .weight(.medium)
    }

    static func body(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(uiFamilyName, size: size, relativeTo: textStyle)
            .weight(.regular)
    }

    static func bodyStrong(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(uiFamilyName, size: size, relativeTo: textStyle)
            .weight(.semibold)
    }

    static func badge(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .caption) -> Font {
        .custom(uiFamilyName, size: size, relativeTo: textStyle)
            .weight(.bold)
    }

    static func longForm(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(aleoFamilyName, size: size, relativeTo: textStyle)
            .weight(.regular)
            .italic()
    }

    static func userEntry(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(aleoFamilyName, size: size, relativeTo: textStyle)
            .weight(.medium)
    }
}

extension Font {
    static func appBrand(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .largeTitle) -> Font {
        AppTypography.brand(size, relativeTo: textStyle)
    }

    static func appDisplay(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .title2) -> Font {
        AppTypography.display(size, relativeTo: textStyle)
    }

    static func appButton(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .headline) -> Font {
        AppTypography.button(size, relativeTo: textStyle)
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

    static func appBadge(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .caption) -> Font {
        AppTypography.badge(size, relativeTo: textStyle)
    }

    static func appSubtitle(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .subheadline) -> Font {
        AppTypography.subtitle(size, relativeTo: textStyle)
    }

    static func appAccent(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        AppTypography.subtitle(size, relativeTo: textStyle)
    }

    static func appLongForm(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        AppTypography.longForm(size, relativeTo: textStyle)
    }

    static func appUserEntry(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        AppTypography.userEntry(size, relativeTo: textStyle)
    }
}

extension View {
    func appBaseTypography() -> some View {
        modifier(AppThemeRefreshModifier())
    }

    func appNavigationChrome() -> some View {
        self
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
    }

    func settingsNativeNavigationTitle(_ title: String, colorScheme: ColorScheme, background: Color) -> some View {
        self
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
               ToolbarItem(placement: .principal) {
                    Text(LocalizedStringKey(title))
                        .font(.appTitle(33, relativeTo: .title))
                        .foregroundStyle(AppColor.headerForeground(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .accessibilityAddTraits(.isHeader)
                }
            }
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

    @ViewBuilder
    func appInteractiveCircleGlass(tint: Color) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(), in: .circle)
        } else {
            self
        }
    }

    @ViewBuilder
    func appInteractiveCapsuleGlass(tint: Color) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(), in: .capsule)
        } else {
            self
        }
    }

    @ViewBuilder
    func appInteractiveRoundedGlass(tint: Color, cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            self
        }
    }
}

private struct AppThemeRefreshModifier: ViewModifier {
    @AppStorage(AppPreferences.Keys.appTheme) private var appThemeRaw = AppThemeOption.classic.rawValue

    func body(content: Content) -> some View {
        content
            .font(.appBody(17))
            .environment(\.appThemeRefreshToken, appThemeRaw)
    }
}

private struct AppThemeRefreshTokenKey: EnvironmentKey {
    static let defaultValue = AppThemeOption.classic.rawValue
}

private extension EnvironmentValues {
    var appThemeRefreshToken: String {
        get { self[AppThemeRefreshTokenKey.self] }
        set { self[AppThemeRefreshTokenKey.self] = newValue }
    }
}

struct AppLargeScreenTitle: View {
    let title: String

    var body: some View {
        Text(LocalizedStringKey(title))
            .font(.appTitle(34, relativeTo: .largeTitle))
            .foregroundStyle(AppColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 0)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

struct AppSettingsDetailHeader<Trailing: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.settingsDetailPresentation) private var settingsDetailPresentation
    let title: String
    let background: Color
    private let trailing: Trailing

    init(
        title: String,
        background: Color = AppColor.main,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.background = background
        self.trailing = trailing()
    }

    var body: some View {
        if settingsDetailPresentation == .sidePanel {
            HStack(spacing: 10) {
                Capsule()
                    .fill(AppColor.main)
                    .frame(width: 5, height: 28)

                Text(LocalizedStringKey(title))
                    .font(.appTitle(24, relativeTo: .title2))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)

                Spacer(minLength: 0)

                trailing
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .background(AppColor.surface)
            .accessibilityAddTraits(.isHeader)
        } else {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 14) {
                    Text(LocalizedStringKey(title))
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
    }

    private var headerForeground: Color {
        AppColor.headerForeground(for: colorScheme)
    }
}

extension AppSettingsDetailHeader where Trailing == EmptyView {
    init(
        title: String,
        background: Color = AppColor.main
    ) {
        self.init(
            title: title,
            background: background
        ) {
            EmptyView()
        }
    }
}

struct AppCircleActionButtonStyle: ButtonStyle {
    let intent: AppActionIntent
    var size: CGFloat = 34
    var tint: Color? = nil
    var foreground: Color? = nil
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let foreground: Color = {
            guard isEnabled else { return AppColor.textSecondary }
            return self.foreground ?? AppColor.black
        }()

        let background: Color = {
            guard isEnabled else { return AppColor.iconCircle.opacity(0.28) }
//            return configuration.isPressed ? intent.pressedBackground : AppColor.iconCircle
           return tint ?? AppColor.main
        }()

        return configuration.label
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background {
                if #unavailable(iOS 26.0) {
                    Circle()
                        .fill(background)
                }
            }
            .appInteractiveCircleGlass(tint: background)
            .overlay {
                if #unavailable(iOS 26.0) {
                    Circle()
                        .stroke(AppColor.border, lineWidth: 1)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(AppAnimation.easeFast, value: configuration.isPressed)
    }
}

struct AppOutlinedIconButtonStyle: ButtonStyle {
    let tint: Color
    var size: CGFloat = 34
    var symbolSize: CGFloat = 16
    var lineWidth: CGFloat = 2.2
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let resolvedTint = isEnabled ? tint : tint.opacity(0.68)
        return configuration.label
            .font(.system(size: symbolSize, weight: .black, design: .rounded))
            .foregroundStyle(resolvedTint)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.clear))
            .overlay(
                Circle()
                    .stroke(resolvedTint, lineWidth: lineWidth)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(isEnabled ? 1 : 0.74)
            .animation(AppAnimation.easeFast, value: configuration.isPressed)
            .animation(AppAnimation.easeFast, value: isEnabled)
    }
}

struct AppSemanticTextButtonStyle: ButtonStyle {
    let intent: AppActionIntent

    func makeBody(configuration: Configuration) -> some View {
        let foreground = configuration.isPressed ? AppColor.onAction : intent.textForeground
        let background = configuration.isPressed ? intent.pressedBackground : Color.clear
        return configuration.label
            .font(.appButton(15, relativeTo: .subheadline))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                if #unavailable(iOS 26.0) {
                    Capsule()
                        .fill(background)
                }
            }
            .appInteractiveCapsuleGlass(tint: background)
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
            .background {
                if #unavailable(iOS 26.0) {
                    Circle()
                        .fill(background)
                }
            }
            .appInteractiveCircleGlass(tint: background)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(AppAnimation.easeFast, value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.4)
    }
}
