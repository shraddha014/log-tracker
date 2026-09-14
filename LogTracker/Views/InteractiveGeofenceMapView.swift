import SwiftUI
import MapKit

public struct InteractiveGeofenceMapView: UIViewRepresentable {
    @Binding var coordinate: CLLocationCoordinate2D
    @Binding var radiusMeters: Double
    var isSatellite: Bool = false
    
    public init(coordinate: Binding<CLLocationCoordinate2D>, radiusMeters: Binding<Double>, isSatellite: Bool = false) {
        self._coordinate = coordinate
        self._radiusMeters = radiusMeters
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
        
        // Add tap gesture to drop/move pin
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        // Set initial region
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: max(500, radiusMeters * 3),
            longitudinalMeters: max(500, radiusMeters * 3)
        )
        mapView.setRegion(region, animated: false)
        
        context.coordinator.updateAnnotationAndOverlay(on: mapView)
        return mapView
    }
    
    public func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.mapType = isSatellite ? .hybrid : .standard
        
        // If coordinate or radius changed, update overlay & annotation
        let currentAnnotation = mapView.annotations.first { !($0 is MKUserLocation) }
        let coordinateChanged = currentAnnotation?.coordinate.latitude != coordinate.latitude ||
                                currentAnnotation?.coordinate.longitude != coordinate.longitude
        
        let currentCircle = mapView.overlays.compactMap { $0 as? MKCircle }.first
        let radiusChanged = currentCircle?.radius != radiusMeters
        
        if coordinateChanged || radiusChanged {
            context.coordinator.updateAnnotationAndOverlay(on: mapView)
            
            if coordinateChanged {
                let region = MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: max(500, radiusMeters * 3),
                    longitudinalMeters: max(500, radiusMeters * 3)
                )
                mapView.setRegion(region, animated: true)
            }
        }
    }
    
    public final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: InteractiveGeofenceMapView
        
        init(_ parent: InteractiveGeofenceMapView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let newCoordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            parent.coordinate = newCoordinate
            updateAnnotationAndOverlay(on: mapView)
        }
        
        func updateAnnotationAndOverlay(on mapView: MKMapView) {
            // Remove existing non-user annotations and circles
            let oldAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
            mapView.removeAnnotations(oldAnnotations)
            mapView.removeOverlays(mapView.overlays)
            
            // Add pin
            let pin = MKPointAnnotation()
            pin.coordinate = parent.coordinate
            pin.title = "Office Location"
            mapView.addAnnotation(pin)
            
            // Add geofence boundary circle
            let circle = MKCircle(center: parent.coordinate, radius: parent.radiusMeters)
            mapView.addOverlay(circle)
        }
        
        public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circleOverlay = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circleOverlay)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 2.5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !annotation.isKind(of: MKUserLocation.self) else { return nil }
            
            let identifier = "OfficePin"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = false
                view?.animatesWhenAdded = true
                view?.markerTintColor = .systemBlue
                view?.glyphImage = UIImage(systemName: "building.2.fill")
            } else {
                view?.annotation = annotation
            }
            return view
        }
    }
}
