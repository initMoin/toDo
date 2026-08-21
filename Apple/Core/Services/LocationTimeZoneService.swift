import Foundation
import CoreLocation
import Combine
import MapKit

@MainActor
final class LocationTimeZoneService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func requestLocationTimeZoneAccess() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        #if os(macOS)
        case .authorizedAlways:
            manager.requestLocation()
        #else
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        #endif
        case .restricted, .denied:
            break
        @unknown default:
            break
        }
    }
}

extension LocationTimeZoneService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        Task { @MainActor in
            authorizationStatus = status
            #if os(macOS)
            if status == .authorizedAlways {
                self.manager.requestLocation()
            }
            #else
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                self.manager.requestLocation()
            }
            #endif
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            await updateTimeZone(from: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
}

private extension LocationTimeZoneService {
    func updateTimeZone(from location: CLLocation) async {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return
        }
        request.preferredLocale = .current

        do {
            let mapItems = try await request.mapItems
            if let timeZoneIdentifier = mapItems.first?.timeZone?.identifier {
                UserDefaults.standard.set(timeZoneIdentifier, forKey: AppPreferences.Keys.locationTimeZoneIdentifier)
            }
        } catch {
            return
        }
    }
}
