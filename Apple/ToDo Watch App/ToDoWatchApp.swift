import SwiftUI

@main
struct ToDoWatchApp: App {
   var body: some Scene {
      WindowGroup {
         ToDosView()
            .watchAccessibilityAdaptations()
      }
   }
}

private extension View {
   func watchAccessibilityAdaptations() -> some View {
      modifier(WatchAccessibilityAdaptationsModifier())
   }
}

private struct WatchAccessibilityAdaptationsModifier: ViewModifier {
   @Environment(\.accessibilityReduceMotion) private var reduceMotion

   func body(content: Content) -> some View {
      content
         .transaction { transaction in
            if reduceMotion {
               transaction.animation = nil
               transaction.disablesAnimations = true
            }
         }
   }
}
