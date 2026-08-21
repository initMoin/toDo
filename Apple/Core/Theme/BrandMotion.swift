import SwiftUI

/// Uses the supplied visual references directly, with only a slow clipped pan so
/// the motion remains visible without changing the artwork's character.
struct ToDoBrandPlusMark: View {
    let font: Font
    let width: CGFloat
    let height: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init(font: Font, width: CGFloat, height: CGFloat) {
        self.font = font
        self.width = width
        self.height = height
    }

    var body: some View {
        referenceImage(named: "brandPlusReference")
            .mask {
                Text(verbatim: "+")
                    .font(font)
                    .fixedSize()
                    .frame(width: width, height: height)
            }
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func referenceImage(named name: String) -> some View {
        if reduceMotion || scenePhase != .active {
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: width * 1.45, height: height * 1.45)
        } else {
            TimelineView(.animation) { context in
                let phase = context.date.timeIntervalSinceReferenceDate / 4.0
                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width * 1.45, height: height * 1.45)
                    .scaleEffect(1.04 + CGFloat((sin(phase * 1.1) + 1) * 0.025))
                    .offset(
                        x: CGFloat(sin(phase * 1.7)) * width * 0.10,
                        y: CGFloat(cos(phase * 1.3)) * height * 0.10
                    )
            }
        }
    }
}

/// The supplied pixel-grid reference is used as the banner artwork. The dark
/// tint keeps the content readable while preserving the grid and color fields.
struct ToDoBrandRecognitionBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ToDoBrandMotionPalette.charcoal
                referenceImage(in: proxy.size)
                ToDoBrandMotionPalette.charcoal.opacity(0.28)
            }
            .clipped()
        }
    }

    @ViewBuilder
    private func referenceImage(in size: CGSize) -> some View {
        if reduceMotion || scenePhase != .active {
            Image("brandBannerReference")
                .resizable()
                .scaledToFill()
                .frame(width: size.width * 1.12, height: size.height * 1.12)
        } else {
            TimelineView(.animation) { context in
                let phase = context.date.timeIntervalSinceReferenceDate / 6.0
                Image("brandBannerReference")
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width * 1.12, height: size.height * 1.12)
                    .scaleEffect(1.02 + CGFloat((sin(phase * 0.8) + 1) * 0.018))
                    .offset(
                        x: CGFloat(sin(phase * 0.7)) * size.width * 0.035,
                        y: CGFloat(cos(phase * 0.55)) * size.height * 0.035
                    )
            }
        }
    }
}

private enum ToDoBrandMotionPalette {
    static let charcoal = Color(red: 0.2235, green: 0.2235, blue: 0.2235)
}
