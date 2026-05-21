import Foundation

#if os(iOS)
import UIKit
#endif

@MainActor
enum HapticFeedbackService {
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

   static func play(_ event: Event) {
#if os(iOS)
      switch event {
      case .selection:
         let generator = UISelectionFeedbackGenerator()
         generator.prepare()
         generator.selectionChanged()
      case .reveal:
         let generator = UIImpactFeedbackGenerator(style: .light)
         generator.prepare()
         generator.impactOccurred(intensity: 0.55)
      case .taskCompleted, .saved, .restored:
         let generator = UINotificationFeedbackGenerator()
         generator.prepare()
         generator.notificationOccurred(.success)
      case .taskReopened:
         let generator = UIImpactFeedbackGenerator(style: .medium)
         generator.prepare()
         generator.impactOccurred(intensity: 0.7)
      case .warning:
         let generator = UINotificationFeedbackGenerator()
         generator.prepare()
         generator.notificationOccurred(.warning)
      case .destructive:
         let generator = UINotificationFeedbackGenerator()
         generator.prepare()
         generator.notificationOccurred(.warning)
      }
#endif
   }
}
