import SwiftUI
import MapKit
import CoreLocation

public struct LocationsView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingAddLocationSheet = false
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.locations.isEmpty {
                    emptyStateView
                } else {
                    locationsList
                }
            }
            .navigationTitle("Office Geofences")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddLocationSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddLocationSheet) {
                AddOfficeLocationSheet(viewModel: viewModel)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 54))
                .foregroundColor(.blue)
            
            Text("No Office Geofences")
                .font(.title2.bold())
            
            Text("Search your office address or tap on the map to draw and track your workplace area.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showingAddLocationSheet = true
            } label: {
                Label("Search & Add Workplace", systemImage: "magnifyingglass")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var locationsList: some View {
        List {
            Section {
                Text("When inside any active geofence, your hours are automatically tracked.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(viewModel.locations) { loc in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: loc.isPolygon ? "square.dashed.inset.filled" : "building.2.crop.circle.fill")
                            .font(.title2)
                            .foregroundColor(loc.isPolygon ? .indigo : .blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc.name)
                                .font(.headline)
                            
                            if loc.isPolygon {
                                Text("Custom Painted Shape (\(loc.polygonCoordinates.count) corner points)")
                                    .font(.caption)
                                    .foregroundColor(.indigo)
                            } else {
                                Text("Radius: \(Int(loc.radiusMeters)) meters")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { loc.isActive },
                            set: { newValue in
                                var updated = loc
                                updated.isActive = newValue
                                viewModel.updateLocation(updated)
                            }
                        ))
                        .labelsHidden()
                    }
                    
                    Text(String(format: "Coordinates: %.4f, %.4f", loc.latitude, loc.longitude))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let loc = viewModel.locations[index]
                    viewModel.deleteLocation(id: loc.id)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

public struct AddOfficeLocationSheet: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var searchService = LocationSearchService()
    
    @State private var name: String = ""
    @State private var coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    @State private var radiusMeters: Double = 150.0
    @State private var polygonPoints: [CoordinatePoint] = []
    @State private var shapeMode: GeofenceShapeMode = .polygon
    @State private var isSatellite: Bool = true // Default to satellite so roofs/buildings are visible
    @State private var showingSearchResults: Bool = false
    
    private let presetRadii: [Double] = [25, 50, 100, 200, 400]
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. Search Bar
                searchHeader
                
                // 2. Mode Selector: Draw Area vs Circle
                Picker("Boundary Type", selection: $shapeMode) {
                    ForEach(GeofenceShapeMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 6)
                
                // 3. Autocomplete Dropdown or Interactive Map
                if showingSearchResults && !searchService.searchResults.isEmpty {
                    searchResultsList
                } else {
                    mapAndControlsView
                }
            }
            .navigationTitle("Add Office Geofence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLocation()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (shapeMode == .polygon && polygonPoints.count < 3))
                }
            }
            .onAppear {
                initializeUserLocation()
            }
        }
    }
    
    // MARK: - Search Header
    
    private var searchHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search office name or address...", text: $searchService.searchQuery)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onSubmit {
                        showingSearchResults = false
                    }
                    .onChange(of: searchService.searchQuery) { query in
                        showingSearchResults = !query.isEmpty
                    }
                
                if !searchService.searchQuery.isEmpty {
                    Button {
                        searchService.searchQuery = ""
                        showingSearchResults = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Search Results
    
    private var searchResultsList: some View {
        List(searchService.searchResults) { item in
            Button {
                selectSearchResult(item)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Map & Controls
    
    private var mapAndControlsView: some View {
        VStack(spacing: 0) {
            // Interactive Map
            ZStack(alignment: .topTrailing) {
                InteractiveGeofenceMapView(
                    coordinate: $coordinate,
                    radiusMeters: $radiusMeters,
                    polygonPoints: $polygonPoints,
                    shapeMode: shapeMode,
                    isSatellite: isSatellite
                )
                
                // Map control buttons
                VStack(spacing: 10) {
                    Button {
                        isSatellite.toggle()
                    } label: {
                        Image(systemName: isSatellite ? "globe.americas.fill" : "map.fill")
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                    
                    Button {
                        useCurrentLocation()
                    } label: {
                        Image(systemName: "location.fill")
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                }
                .padding()
            }
            .frame(maxHeight: .infinity)
            
            // Bottom Configuration Drawer
            VStack(alignment: .leading, spacing: 12) {
                // Name Input
                HStack {
                    Text("Name:")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                    TextField("e.g. Headquarters, Building A", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                if shapeMode == .polygon {
                    // Polygon Controls
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Drawn Area:")
                                .font(.subheadline.bold())
                            
                            if polygonPoints.count >= 3 {
                                Text("\(polygonPoints.count) corners defined (Shape ready)")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            } else {
                                Text("Tap \(3 - polygonPoints.count) more point\(3 - polygonPoints.count == 1 ? "" : "s") to form a shape")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                            
                            Spacer()
                        }
                        
                        HStack(spacing: 10) {
                            Button {
                                if !polygonPoints.isEmpty {
                                    polygonPoints.removeLast()
                                }
                            } label: {
                                Label("Undo", systemImage: "arrow.uturn.backward")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                            }
                            .disabled(polygonPoints.isEmpty)
                            
                            Button {
                                polygonPoints.removeAll()
                            } label: {
                                Label("Clear", systemImage: "trash")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.red)
                                    .cornerRadius(8)
                            }
                            .disabled(polygonPoints.isEmpty)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "hand.tap.fill")
                                .foregroundColor(.indigo)
                            Text("Tap the corners of your office building on the satellite map to trace its exact boundaries.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    // Circle Radius Slider
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Geofence Area Radius")
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(Int(radiusMeters)) meters")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        
                        Slider(value: $radiusMeters, in: 15...1000, step: 5)
                        
                        HStack(spacing: 8) {
                            ForEach(presetRadii, id: \.self) { r in
                                Button {
                                    radiusMeters = r
                                } label: {
                                    Text("\(Int(r))m")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(radiusMeters == r ? Color.blue : Color(.systemGray5))
                                        .foregroundColor(radiusMeters == r ? .white : .primary)
                                        .cornerRadius(6)
                                }
                            }
                        }
                        
                        if radiusMeters < 50 {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.orange)
                                Text("Radii under 50m may be affected by indoor GPS drift.")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                            .padding(.top, 2)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16, corners: [.topLeft, .topRight])
            .shadow(color: Color.black.opacity(0.06), radius: 8, y: -2)
        }
    }
    
    // MARK: - Actions
    
    private func selectSearchResult(_ item: SearchResultItem) {
        searchService.resolveLocation(for: item) { resolvedCoord, title in
            if let coord = resolvedCoord {
                self.coordinate = coord
                self.name = title
                self.searchService.searchQuery = ""
                self.showingSearchResults = false
                
                // If in polygon mode, seed the first point around the resolved place
                if self.shapeMode == .polygon && self.polygonPoints.isEmpty {
                    self.polygonPoints.append(CoordinatePoint(latitude: coord.latitude, longitude: coord.longitude))
                }
            }
        }
    }
    
    private func initializeUserLocation() {
        LocationManager.shared.requestPermissions()
        LocationManager.shared.requestCurrentLocationOnce()
        if let userCoord = LocationManager.shared.currentLocation?.coordinate {
            self.coordinate = userCoord
        }
    }
    
    private func useCurrentLocation() {
        if let current = LocationManager.shared.currentLocation {
            coordinate = current.coordinate
            if name.isEmpty {
                name = "My Office Location"
            }
            if shapeMode == .polygon {
                polygonPoints.append(CoordinatePoint(latitude: current.coordinate.latitude, longitude: current.coordinate.longitude))
            }
        }
    }
    
    private func saveLocation() {
        let isPoly = (shapeMode == .polygon && polygonPoints.count >= 3)
        let locCenter = isPoly ? (polygonPoints.first?.coordinate ?? coordinate) : coordinate
        
        let newLocation = OfficeLocation(
            id: UUID(),
            name: name.isEmpty ? "Office Area" : name,
            latitude: locCenter.latitude,
            longitude: locCenter.longitude,
            radiusMeters: radiusMeters,
            isActive: true,
            polygonCoordinates: isPoly ? polygonPoints : []
        )
        viewModel.addLocation(newLocation)
    }
}

// Extension to round specific corners of a view
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
