import Combine
import SwiftUI

@MainActor
final class HapticFeedbackService: ObservableObject {
   enum Event {
      case selection
      case reveal
      case taskCompleted
      case taskReopened
      case saved
      case restored
      case warning
      case destructive
   }

   static let shared = HapticFeedbackService()

   @Published private(set) var selectionTrigger = 0
   @Published private(set) var revealTrigger = 0
   @Published private(set) var successTrigger = 0
   @Published private(set) var reopenTrigger = 0
   @Published private(set) var warningTrigger = 0

   private init() {}

   static func play(_ event: Event) {
      shared.play(event)
   }

   private func play(_ event: Event) {
      switch event {
      case .selection:
         selectionTrigger += 1
      case .reveal:
         revealTrigger += 1
      case .taskCompleted, .saved, .restored:
         successTrigger += 1
      case .taskReopened:
         reopenTrigger += 1
      case .warning, .destructive:
         warningTrigger += 1
      }
   }
}

private struct AppHapticFeedbackHost: ViewModifier {
   @ObservedObject private var haptics = HapticFeedbackService.shared

   func body(content: Content) -> some View {
      content
         .sensoryFeedback(.selection, trigger: haptics.selectionTrigger)
         .sensoryFeedback(.impact(weight: .light, intensity: 0.55), trigger: haptics.revealTrigger)
         .sensoryFeedback(.success, trigger: haptics.successTrigger)
         .sensoryFeedback(.impact(weight: .medium, intensity: 0.7), trigger: haptics.reopenTrigger)
         .sensoryFeedback(.warning, trigger: haptics.warningTrigger)
   }
}

extension View {
   func appHapticFeedbackHost() -> some View {
      modifier(AppHapticFeedbackHost())
   }
}
