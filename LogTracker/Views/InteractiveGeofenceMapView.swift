import SwiftUI
import MapKit

public enum GeofenceShapeMode: String, CaseIterable, Identifiable {
    case polygon = "Draw Area (Custom Shape)"
    case circle = "Circle Radius"
    
    public var id: String { rawValue }
}

public struct InteractiveGeofenceMapView: UIViewRepresentable {
    @Binding var coordinate: CLLocationCoordinate2D
    @Binding var radiusMeters: Double
    @Binding var polygonPoints: [CoordinatePoint]
    var shapeMode: GeofenceShapeMode
    var isSatellite: Bool = false
    
    public init(
        coordinate: Binding<CLLocationCoordinate2D>,
        radiusMeters: Binding<Double>,
        polygonPoints: Binding<[CoordinatePoint]>,
        shapeMode: GeofenceShapeMode,
        isSatellite: Bool = false
    ) {
        self._coordinate = coordinate
        self._radiusMeters = radiusMeters
        self._polygonPoints = polygonPoints
        self.shapeMode = shapeMode
        self.isSatellite = isSatellite
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.mapType = isSatellite ? .hybrid : .standard
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        // Initial region
        let initialCoord = polygonPoints.first?.coordinate ?? coordinate
        let region = MKCoordinateRegion(
            center: initialCoord,
            latitudinalMeters: max(300, radiusMeters * 3),
            longitudinalMeters: max(300, radiusMeters * 3)
        )
        mapView.setRegion(region, animated: false)
        
        context.coordinator.refreshOverlaysAndAnnotations(on: mapView)
        return mapView
    }
    
    public func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.mapType = isSatellite ? .hybrid : .standard
        context.coordinator.parent = self
        context.coordinator.refreshOverlaysAndAnnotations(on: mapView)
    }
    
    public final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: InteractiveGeofenceMapView
        
        init(_ parent: InteractiveGeofenceMapView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let tappedCoord = mapView.convert(point, toCoordinateFrom: mapView)
            
            if parent.shapeMode == .polygon {
                // Add new polygon corner vertex
                let newPoint = CoordinatePoint(latitude: tappedCoord.latitude, longitude: tappedCoord.longitude)
                parent.polygonPoints.append(newPoint)
            } else {
                // Move circular center pin
                parent.coordinate = tappedCoord
            }
            refreshOverlaysAndAnnotations(on: mapView)
        }
        
        func refreshOverlaysAndAnnotations(on mapView: MKMapView) {
            let userLoc = mapView.userLocation
            let nonUserAnnotations = mapView.annotations.filter { $0 !== userLoc }
            mapView.removeAnnotations(nonUserAnnotations)
            mapView.removeOverlays(mapView.overlays)
            
            if parent.shapeMode == .polygon {
                // Render polygon vertices and shape
                if parent.polygonPoints.count >= 3 {
                    let coords = parent.polygonPoints.map { $0.coordinate }
                    let polygon = MKPolygon(coordinates: coords, count: coords.count)
                    mapView.addOverlay(polygon)
                } else if parent.polygonPoints.count == 2 {
                    let coords = parent.polygonPoints.map { $0.coordinate }
                    let polyline = MKPolyline(coordinates: coords, count: coords.count)
                    mapView.addOverlay(polyline)
                }
                
                // Add vertex annotations
                for (idx, pt) in parent.polygonPoints.enumerated() {
                    let pin = MKPointAnnotation()
                    pin.coordinate = pt.coordinate
                    pin.title = "Point \(idx + 1)"
                    mapView.addAnnotation(pin)
                }
            } else {
                // Circle mode: single center pin + circle overlay
                let pin = MKPointAnnotation()
                pin.coordinate = parent.coordinate
                pin.title = "Office Location"
                mapView.addAnnotation(pin)
                
                let circle = MKCircle(center: parent.coordinate, radius: parent.radiusMeters)
                mapView.addOverlay(circle)
            }
        }
        
        public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.25)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 2.5
                return renderer
            } else if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 2.5
                return renderer
            } else if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 2.0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            let identifier = "GeofenceMarker"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = false
            } else {
                view?.annotation = annotation
            }
            
            if parent.shapeMode == .polygon {
                view?.markerTintColor = .systemIndigo
                view?.glyphText = "•"
            } else {
                view?.markerTintColor = .systemBlue
                view?.glyphImage = UIImage(systemName: "building.2.fill")
            }
            return view
        }
    }
}
