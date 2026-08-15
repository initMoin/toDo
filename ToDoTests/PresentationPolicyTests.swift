import CoreGraphics
import Testing
@testable import ToDo

@Suite("Presentation policies")
struct PresentationPolicyTests {
   @Test func macWindowClassesCoverNarrowStandardAndWideWindows() {
      #expect(AppAdaptiveLayout.macWindowClass(for: 760) == .narrow)
      #expect(AppAdaptiveLayout.macWindowClass(for: 980) == .standard)
      #expect(AppAdaptiveLayout.macWindowClass(for: 1_280) == .wide)
   }

   @Test func macWindowEnvelopeBalancesFlexibilityAndComposition() {
      #expect(AppAdaptiveLayout.macMinimumWindowWidth == 760)
      #expect(AppAdaptiveLayout.macIdealWindowWidth == 980)
      #expect(AppAdaptiveLayout.macMaximumWindowWidth == 1_280)
      #expect(AppAdaptiveLayout.macMinimumWindowHeight == 560)
      #expect(AppAdaptiveLayout.macIdealWindowHeight == 700)
      #expect(AppAdaptiveLayout.macMaximumWindowHeight == 900)
   }

   @Test func macWindowPaddingPreservesMoreSpaceAtNarrowWidths() {
      #expect(AppAdaptiveLayout.macHorizontalPadding(for: 760) == 18)
      #expect(AppAdaptiveLayout.macHorizontalPadding(for: 980) == 24)
      #expect(AppAdaptiveLayout.macHorizontalPadding(for: 1_280) == 30)
   }

   @Test func sideBySideLayoutUsesTheSharedBreakpoint() {
      #expect(!AppAdaptiveLayout.usesSideBySideLayout(for: 999))
      #expect(AppAdaptiveLayout.usesSideBySideLayout(for: 1_000))
   }

   @Test func navigationDirectionDistinguishesForwardAndBackwardTravel() {
      #expect(AppNavigationDirection.forward != .backward)
   }
}
