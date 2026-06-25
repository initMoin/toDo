import Combine
import SwiftUI
#if canImport(AudioToolbox)
import AudioToolbox
#endif

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
      case .taskCompleted:
         successTrigger += 1
         playCompletionSoundIfNeeded()
      case .saved, .restored:
         successTrigger += 1
      case .taskReopened:
         reopenTrigger += 1
      case .warning, .destructive:
         warningTrigger += 1
      }
   }

   private func playCompletionSoundIfNeeded() {
      let rawValue = UserDefaults.standard.string(forKey: AppPreferences.Keys.completionSoundOption)
      let option = AppPreferences.CompletionSoundOption(rawValue: rawValue ?? "") ?? .off
      guard let soundID = option.systemSoundID else { return }

      #if canImport(AudioToolbox)
      AudioServicesPlaySystemSound(SystemSoundID(soundID))
      #endif
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
