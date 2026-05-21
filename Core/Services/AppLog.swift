import Foundation
import OSLog

enum AppLog {
   private static let subsystem = Bundle.main.bundleIdentifier ?? "dev.iamshift.toDo"

   static let app = Logger(subsystem: subsystem, category: "App")
   static let auth = Logger(subsystem: subsystem, category: "Auth")
   static let sync = Logger(subsystem: subsystem, category: "Sync")
   static let notifications = Logger(subsystem: subsystem, category: "Notifications")
   static let calendar = Logger(subsystem: subsystem, category: "Calendar")
   static let location = Logger(subsystem: subsystem, category: "Location")
   static let widget = Logger(subsystem: subsystem, category: "Widget")
   static let liveActivity = Logger(subsystem: subsystem, category: "LiveActivity")

   static func info(_ message: String, logger: Logger = app) {
      logger.info("\(message, privacy: .public)")
   }

   static func warning(_ message: String, logger: Logger = app) {
      logger.warning("\(message, privacy: .public)")
   }

   static func error(_ message: String, logger: Logger = app) {
      logger.error("\(message, privacy: .public)")
   }
}
