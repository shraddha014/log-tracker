import Foundation
import CoreLocation

public final class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject, @unchecked Sendable {
    public static let shared = LocationManager()
    
    private let clManager = CLLocationManager()
    
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var currentLocation: CLLocation?
    @Published public var isMonitoringGeofences: Bool = false
    
    public var onRegionEntered: ((OfficeLocation) -> Void)?
    public var onRegionExited: ((OfficeLocation) -> Void)?
    
    private var registeredLocations: [UUID: OfficeLocation] = [:]
    
    public override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyBest
        clManager.distanceFilter = 10
        self.authorizationStatus = clManager.authorizationStatus
    }
    
    public func requestPermissions() {
        if clManager.authorizationStatus == .notDetermined {
            clManager.requestAlwaysAuthorization()
        } else if clManager.authorizationStatus == .authorizedWhenInUse {
            clManager.requestAlwaysAuthorization()
        }
    }
    
    public func requestCurrentLocationOnce() {
        clManager.requestLocation()
    }
    
    // MARK: - Geofence Synchronization
    
    public func syncGeofences(locations: [OfficeLocation]) {
        registeredLocations.removeAll()
        for loc in locations {
            registeredLocations[loc.id] = loc
        }
        
        let activeLocations = locations.filter { $0.isActive }
        let activeIds = Set(activeLocations.map { $0.id.uuidString })
        
        for monitored in clManager.monitoredRegions {
            if !activeIds.contains(monitored.identifier) {
                clManager.stopMonitoring(for: monitored)
            }
        }
        
        for loc in activeLocations.prefix(20) {
            let region = loc.circularRegion
            clManager.startMonitoring(for: region)
        }
        
        isMonitoringGeofences = !activeLocations.isEmpty
    }
    
    // MARK: - CLLocationManagerDelegate
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = latest
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationManager] Location update error: \(error.localizedDescription)")
    }
    
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion,
              let uuid = UUID(uuidString: circularRegion.identifier),
              let office = registeredLocations[uuid] else {
            return
        }
        
        DispatchQueue.main.async {
            self.onRegionEntered?(office)
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion,
              let uuid = UUID(uuidString: circularRegion.identifier),
              let office = registeredLocations[uuid] else {
            return
        }
        
        DispatchQueue.main.async {
            self.onRegionExited?(office)
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("[LocationManager] Monitoring failed for region: \(region?.identifier ?? "unknown"), error: \(error)")
    }
}
