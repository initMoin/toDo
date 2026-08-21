import Foundation
import Combine
import Network
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

   /// Starts a low-overhead sync measurement. The operation name is always a
   /// fixed developer-controlled label, so no user data enters the metric.
   static func beginSyncMeasurement(_ operation: StaticString) -> Date {
      let startedAt = Date()
      sync.debug("sync.start \(operation, privacy: .public)")
      return startedAt
   }

   static func endSyncMeasurement(
      _ operation: StaticString,
      startedAt: Date,
      outcome: StaticString
   ) {
      let duration = max(0, Date().timeIntervalSince(startedAt))
      sync.info(
         "sync.end \(operation, privacy: .public) outcome=\(outcome, privacy: .public) duration_ms=\(duration * 1000, format: .fixed(precision: 1), privacy: .public)"
      )
   }

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

/// Tracks the system's current network path without making the UI perform
/// reachability requests. A constrained path is usable, but online work may
/// take longer or be deferred by the system.
@MainActor
final class ToDoConnectivityMonitor: ObservableObject {
   enum Status: Equatable {
      case unknown
      case online
      case constrained
      case offline
   }

   static let shared = ToDoConnectivityMonitor()

   @Published private(set) var status: Status = .unknown

   private let monitor = NWPathMonitor()
   private let queue = DispatchQueue(
      label: "dev.iamshift.toDo.connectivity",
      qos: .utility
   )

   private init() {
      monitor.pathUpdateHandler = { [weak self] path in
         let nextStatus: Status
         if path.status != .satisfied {
            nextStatus = .offline
         } else if path.isConstrained {
            nextStatus = .constrained
         } else {
            nextStatus = .online
         }

         Task { @MainActor [weak self] in
            self?.status = nextStatus
         }
      }
      monitor.start(queue: queue)
   }

   deinit {
      monitor.cancel()
   }

   var isAvailable: Bool {
      status == .online || status == .constrained
   }

   var isLimited: Bool {
      status == .constrained
   }

   var bannerText: String? {
      switch status {
      case .offline:
         return String(localized: "Offline. Sync and online features are paused.")
      case .constrained:
         return String(localized: "Connection is limited. Online features may be delayed.")
      case .unknown, .online:
         return nil
      }
   }
}
