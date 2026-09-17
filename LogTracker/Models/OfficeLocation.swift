import Foundation
import CoreLocation

public struct CoordinatePoint: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var latitude: Double
    public var longitude: Double
    
    public init(id: UUID = UUID(), latitude: Double, longitude: Double) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
    }
    
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

public struct OfficeLocation: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var radiusMeters: Double
    public var isActive: Bool
    public var dateCreated: Date
    public var polygonCoordinates: [CoordinatePoint]
    
    public init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 200.0,
        isActive: Bool = true,
        dateCreated: Date = Date(),
        polygonCoordinates: [CoordinatePoint] = []
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.isActive = isActive
        self.dateCreated = dateCreated
        self.polygonCoordinates = polygonCoordinates
    }
    
    public var isPolygon: Bool {
        polygonCoordinates.count >= 3
    }
    
    public var coordinate: CLLocationCoordinate2D {
        if isPolygon {
            return boundingCenter
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// Bounding centroid for polygon mode
    public var boundingCenter: CLLocationCoordinate2D {
        guard isPolygon else {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        let totalLat = polygonCoordinates.reduce(0.0) { $0 + $1.latitude }
        let totalLng = polygonCoordinates.reduce(0.0) { $0 + $1.longitude }
        let count = Double(polygonCoordinates.count)
        return CLLocationCoordinate2D(latitude: totalLat / count, longitude: totalLng / count)
    }
    
    /// Bounding radius enclosing all polygon vertices (plus small buffer)
    public var effectiveBoundingRadius: Double {
        guard isPolygon else {
            return radiusMeters
        }
        let center = boundingCenter
        let centerLoc = CLLocation(latitude: center.latitude, longitude: center.longitude)
        
        let maxDist = polygonCoordinates.reduce(0.0) { currentMax, point in
            let loc = CLLocation(latitude: point.latitude, longitude: point.longitude)
            return max(currentMax, centerLoc.distance(from: loc))
        }
        // Add 25m buffer to ensure the hardware bounding circle safely encloses the drawn boundary
        return max(50.0, maxDist + 25.0)
    }
    
    public var circularRegion: CLCircularRegion {
        let center = isPolygon ? boundingCenter : CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let radius = isPolygon ? effectiveBoundingRadius : radiusMeters
        
        let region = CLCircularRegion(
            center: center,
            radius: radius,
            identifier: id.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }
    
    /// Checks if a given GPS coordinate is strictly inside this office location.
    /// For circle mode: uses distance <= radius.
    /// For polygon mode: uses ray-casting point-in-polygon algorithm to eliminate false alarms.
    public func contains(coordinate target: CLLocationCoordinate2D) -> Bool {
        guard isPolygon else {
            let centerLoc = CLLocation(latitude: latitude, longitude: longitude)
            let targetLoc = CLLocation(latitude: target.latitude, longitude: target.longitude)
            return targetLoc.distance(from: centerLoc) <= radiusMeters
        }
        
        // Ray-casting algorithm
        var inside = false
        let n = polygonCoordinates.count
        var j = n - 1
        for i in 0..<n {
            let pi = polygonCoordinates[i]
            let pj = polygonCoordinates[j]
            
            let intersect = ((pi.latitude > target.latitude) != (pj.latitude > target.latitude)) &&
                (target.longitude < (pj.longitude - pi.longitude) * (target.latitude - pi.latitude) / (pj.latitude - pi.latitude) + pi.longitude)
            
            if intersect {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}
