import Foundation
import MapKit
import Combine

public struct SearchResultItem: Identifiable, Hashable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
}

public final class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published public var searchQuery: String = ""
    @Published public var searchResults: [SearchResultItem] = []
    @Published public var isSearching: Bool = false
    
    private let completer = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()
    
    public override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    self?.searchResults = []
                    self?.isSearching = false
                } else {
                    self?.isSearching = true
                    self?.completer.queryFragment = query
                }
            }
            .store(in: &cancellables)
    }
    
    public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.searchResults = completer.results.map {
                SearchResultItem(title: $0.title, subtitle: $0.subtitle)
            }
            self.isSearching = false
        }
    }
    
    public func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isSearching = false
        }
    }
    
    /// Resolves a selected search item into an exact coordinate
    public func resolveLocation(for item: SearchResultItem, completion: @escaping (CLLocationCoordinate2D?, String) -> Void) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(item.title), \(item.subtitle)"
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let mapItem = response?.mapItems.first else {
                completion(nil, item.title)
                return
            }
            completion(mapItem.placemark.coordinate, item.title)
        }
    }
}
