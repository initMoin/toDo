import UIKit

// This bridge is the only UIKit/APNs boundary in the app. Notification state and routing
// stay in SwiftUI-facing services; UIKit is used here only for APNs registration callbacks.
final class PushNotificationAppDelegate: NSObject, UIApplicationDelegate {
   @MainActor
   static func registerForRemoteNotifications() {
      UIApplication.shared.registerForRemoteNotifications()
   }
   
   func application(
      _ application: UIApplication,
      didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
   ) {
      Task { @MainActor in
         NotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
         await SupabaseAuthStore.shared.syncCurrentDeviceTokenIfPossible()
      }
   }
   
   func application(
      _ application: UIApplication,
      didFailToRegisterForRemoteNotificationsWithError error: Error
   ) {
      Task { @MainActor in
         NotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
      }
   }
   
   func application(
      _ application: UIApplication,
      didReceiveRemoteNotification userInfo: [AnyHashable: Any],
      fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
   ) {
      Task {
         let result = await NotificationManager.shared.handleRemoteNotification(userInfo)
         completionHandler(map(result))
      }
   }
   
   private func map(_ result: NotificationManager.RemoteNotificationHandlingResult) -> UIBackgroundFetchResult {
      switch result {
      case .noData:
         return .noData
      case .newData:
         return .newData
      case .failed:
         return .failed
      }
   }
}

extension PushNotificationAppDelegate:
   UNUserNotificationCenterDelegate {
   
   func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse
   ) async {
      
      NotificationRouter.shared.route(
         notification: response.notification
      )
   }
}
