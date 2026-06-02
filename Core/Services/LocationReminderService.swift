import Combine
import CoreLocation
import Foundation
import SwiftData
import UserNotifications

@MainActor
final class LocationReminderService: NSObject, ObservableObject {
   static let shared = LocationReminderService()

   enum TriggerKind: String {
      case arriving
      case leaving
   }

   private let manager = CLLocationManager()
   private let notificationCenter = UNUserNotificationCenter.current()

   @Published private(set) var authorizationStatus: CLAuthorizationStatus
   @Published private(set) var currentLocation: CLLocation?

   private var modelContainer: ModelContainer?
   private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

   private override init() {
      authorizationStatus = manager.authorizationStatus
      super.init()
      manager.delegate = self
   }

   func configure(modelContainer: ModelContainer) {
      self.modelContainer = modelContainer
      syncMonitoringFromStore()
   }

   func requestLocationReminderAuthorization() {
      switch manager.authorizationStatus {
      case .notDetermined:
         manager.requestWhenInUseAuthorization()
      case .authorizedWhenInUse:
         manager.requestAlwaysAuthorization()
      case .authorizedAlways, .denied, .restricted:
         break
      @unknown default:
         break
      }
   }

   var canMonitorLocationReminders: Bool {
      authorizationStatus == .authorizedAlways
   }

   var locationReminderStatusMessage: String {
      switch authorizationStatus {
      case .authorizedAlways:
         return String(localized: "Ready. Arrival and leaving reminders can work when toDō is not open.")
      case .authorizedWhenInUse:
         return String(localized: "Allow Always Location access so arrival and leaving reminders can work after toDō is closed.")
      case .notDetermined:
         return String(localized: "iOS will ask for location access. Choose Always for reliable arrival and leaving reminders.")
      case .denied, .restricted:
         return String(localized: "Location access is off. Enable Always Location access in Settings to use place-based reminders.")
      @unknown default:
         return String(localized: "Location access is unavailable.")
      }
   }

   func requestCurrentLocation() async -> CLLocation? {
      switch manager.authorizationStatus {
      case .notDetermined:
         manager.requestWhenInUseAuthorization()
      case .restricted, .denied:
         return nil
      case .authorizedAlways, .authorizedWhenInUse:
         break
      @unknown default:
         return nil
      }

      return await withCheckedContinuation { continuation in
         locationContinuation = continuation
         manager.requestLocation()
      }
   }

   func syncMonitoringFromStore() {
      guard let modelContainer else { return }
      let context = ModelContext(modelContainer)

      do {
         let toDos = try context.fetch(FetchDescriptor<ToDo>())
         syncMonitoring(for: toDos)
      } catch {
         AppLog.error("Failed to sync location reminders: \(error)", logger: AppLog.location)
      }
   }

   func syncMonitoring(for toDos: [ToDo]) {
      stopAllToDoMonitoring()

      guard canMonitorLocationReminders else {
         return
      }

      for toDo in toDos where toDo.isActive && toDo.hasLocationReminder {
         syncMonitoring(for: toDo)
      }
   }

   func syncMonitoring(for toDo: ToDo) {
      let identifier = persistentIdentifierString(for: toDo)
      stopMonitoring(toDoIdentifier: identifier)

      guard canMonitorLocationReminders,
            toDo.isActive,
            let latitude = toDo.locationReminderLatitude,
            let longitude = toDo.locationReminderLongitude else {
         return
      }

      do {
         try startMonitoring(
            toDoIdentifier: identifier,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            radius: toDo.resolvedLocationReminderRadius,
            triggerKind: TriggerKind(rawValue: toDo.locationReminderTrigger.rawValue) ?? .arriving,
            title: toDo.task
         )
      } catch {
         AppLog.error("Failed to start location reminder: \(error)", logger: AppLog.location)
      }
   }

   func startMonitoring(
      toDoIdentifier: String,
      coordinate: CLLocationCoordinate2D,
      radius: CLLocationDistance = 150,
      triggerKind: TriggerKind,
      title: String
   ) throws {
      guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }

      let clampedRadius = min(max(radius, 100), manager.maximumRegionMonitoringDistance)
      let region = CLCircularRegion(
         center: coordinate,
         radius: clampedRadius,
         identifier: regionIdentifier(toDoIdentifier: toDoIdentifier, triggerKind: triggerKind)
      )
      region.notifyOnEntry = triggerKind == .arriving
      region.notifyOnExit = triggerKind == .leaving

      manager.startMonitoring(for: region)
   }

   func stopMonitoring(toDoIdentifier: String) {
      for region in manager.monitoredRegions where region.identifier.contains(toDoIdentifier) {
         manager.stopMonitoring(for: region)
      }
   }

   private func stopAllToDoMonitoring() {
      for region in manager.monitoredRegions where region.identifier.hasPrefix("todo.location.") {
         manager.stopMonitoring(for: region)
      }
   }

   private func regionIdentifier(toDoIdentifier: String, triggerKind: TriggerKind) -> String {
      "todo.location.\(triggerKind.rawValue).\(toDoIdentifier)"
   }

   private func persistentIdentifierString(for toDo: ToDo) -> String {
      String(describing: toDo.id)
   }

   private func toDoIdentifier(from regionIdentifier: String) -> String? {
      let components = regionIdentifier.split(separator: ".", maxSplits: 3).map(String.init)
      guard components.count == 4,
            components[0] == "todo",
            components[1] == "location" else {
         return nil
      }

      return components[3]
   }

   private func triggerKind(from regionIdentifier: String) -> TriggerKind? {
      let components = regionIdentifier.split(separator: ".", maxSplits: 3).map(String.init)
      guard components.count >= 3 else { return nil }
      return TriggerKind(rawValue: components[2])
   }

   private func deliverLocationReminder(for regionIdentifier: String) async {
      guard let modelContainer,
            let toDoIdentifier = toDoIdentifier(from: regionIdentifier) else { return }

      let context = ModelContext(modelContainer)

      do {
         let toDos = try context.fetch(FetchDescriptor<ToDo>())
         guard let toDo = toDos.first(where: { persistentIdentifierString(for: $0) == toDoIdentifier }),
               toDo.isActive else {
            return
         }

         let trigger = triggerKind(from: regionIdentifier) ?? .arriving
         let place = toDo.locationReminderLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
         let title = trigger == .arriving ? "toDō: arrived" : "toDō: leaving"
         let bodyBase = toDo.task.trimmingCharacters(in: .whitespacesAndNewlines)
         let body = bodyBase.isEmpty
            ? "Open toDō to review this location reminder."
            : place?.isEmpty == false ? "\(bodyBase) near \(place!)" : bodyBase
	         let content = NotificationContentBuilder.content(
	            for: .reminder,
            title: title,
            body: body,
            isTimeSensitive: toDo.reminderIntent == .timeSensitive,
            isQuiet: toDo.reminderIntent == .soft,
            soundOption: preferredSoundOption
         )

         content.userInfo = [
            "schemaVersion": 1,
            "type": RemoteNotificationType.reminder.rawValue,
            "todoIdentifier": toDoIdentifier,
            "isRecurring": false,
            "isTimeSensitive": toDo.reminderIntent == .timeSensitive
         ]

         if let cloudID = toDo.cloudID {
            content.userInfo["todoCloudIdentifier"] = cloudID.uuidString
         }

         let request = UNNotificationRequest(
            identifier: "todo.location.\(toDoIdentifier).\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
         )
	         try await notificationCenter.add(request)
	      } catch {
	         AppLog.error("Failed to deliver location reminder: \(error)", logger: AppLog.location)
      }
   }

   private var preferredSoundOption: AppPreferences.NotificationSoundOption {
      let rawValue = UserDefaults.standard.string(forKey: AppPreferences.Keys.notificationSoundOption)
      return rawValue.flatMap(AppPreferences.NotificationSoundOption.init(rawValue:)) ?? .defaultSound
   }
}

extension LocationReminderService: CLLocationManagerDelegate {
   nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
      let status = manager.authorizationStatus
      Task { @MainActor in
         authorizationStatus = status
         if status == .authorizedAlways {
            syncMonitoringFromStore()
         }
      }
   }

   nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
      let location = locations.last
      Task { @MainActor in
         currentLocation = location
         locationContinuation?.resume(returning: location)
         locationContinuation = nil
      }
   }

   nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
      Task { @MainActor in
         locationContinuation?.resume(returning: nil)
         locationContinuation = nil
      }
   }

   nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
      handle(region: region)
   }

   nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
      handle(region: region)
   }

   private nonisolated func handle(region: CLRegion) {
      let regionIdentifier = region.identifier
      guard regionIdentifier.hasPrefix("todo.location.") else { return }
      Task { @MainActor in
         await LocationReminderService.shared.deliverLocationReminder(for: regionIdentifier)
      }
   }
}
