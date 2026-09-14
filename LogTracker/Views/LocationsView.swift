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
                    VStack(spacing: 16) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 54))
                            .foregroundColor(.blue)
                        
                        Text("No Office Geofences")
                            .font(.title2.bold())
                        
                        Text("Add your office locations so the app can automatically detect when you arrive and leave.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Button {
                            showingAddLocationSheet = true
                        } label: {
                            Label("Add Workplace", systemImage: "plus")
                                .font(.headline)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            Text("When inside any active geofence, your hours are tracked according to your chosen clocking style.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ForEach(viewModel.locations) { loc in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "building.2.crop.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(loc.name)
                                            .font(.headline)
                                        Text("Radius: \(Int(loc.radiusMeters)) meters")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
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
}

public struct AddOfficeLocationSheet: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var latitude: Double = 37.7749
    @State private var longitude: Double = -122.4194
    @State private var radiusMeters: Double = 200.0
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Office Name") {
                    TextField("e.g. Headquarters, Downtown Office", text: $name)
                }
                
                Section("Quick Action") {
                    Button {
                        useCurrentLocation()
                    } label: {
                        Label("Use Current GPS Location", systemImage: "location.fill")
                    }
                }
                
                Section("Geofence Radius") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Radius")
                            Spacer()
                            Text("\(Int(radiusMeters)) meters")
                                .bold()
                        }
                        Slider(value: $radiusMeters, in: 50...1000, step: 25)
                    }
                }
                
                Section("Coordinates") {
                    HStack {
                        Text("Latitude")
                        Spacer()
                        TextField("Lat", value: $latitude, format: .number.precision(.fractionLength(4)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("Longitude")
                        Spacer()
                        TextField("Lng", value: $longitude, format: .number.precision(.fractionLength(4)))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section("Map Preview") {
                    Map(coordinateRegion: $region, annotationItems: [MapItem(id: "pin", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))]) { item in
                        MapMarker(coordinate: item.coordinate, tint: .blue)
                    }
                    .frame(height: 180)
                    .cornerRadius(10)
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
                        let newLocation = OfficeLocation(
                            id: UUID(),
                            name: name.isEmpty ? "Office (\(Int(latitude)), \(Int(longitude)))" : name,
                            latitude: latitude,
                            longitude: longitude,
                            radiusMeters: radiusMeters,
                            isActive: true
                        )
                        viewModel.addLocation(newLocation)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty && latitude == 0)
                }
            }
            .onAppear {
                useCurrentLocation()
            }
        }
    }
    
    private func useCurrentLocation() {
        LocationManager.shared.requestPermissions()
        LocationManager.shared.requestCurrentLocationOnce()
        
        if let current = LocationManager.shared.currentLocation {
            latitude = current.coordinate.latitude
            longitude = current.coordinate.longitude
            region.center = current.coordinate
        }
    }
}

private struct MapItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
}
