import Foundation
import CoreLocation

public struct OfficeLocation: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var radiusMeters: Double
    public var isActive: Bool
    public var dateCreated: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 200.0,
        isActive: Bool = true,
        dateCreated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.isActive = isActive
        self.dateCreated = dateCreated
    }
    
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    public var circularRegion: CLCircularRegion {
        let region = CLCircularRegion(
            center: coordinate,
            radius: radiusMeters,
            identifier: id.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }
}
