import Foundation

public final class StorageManager: @unchecked Sendable {
    public static let shared = StorageManager()
    
    private let fileManager = FileManager.default
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    private let queue = DispatchQueue(label: "com.logtracker.storage", qos: .userInitiated)
    
    private var storageDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("LogTrackerData", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    public init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.jsonEncoder = encoder
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.jsonDecoder = decoder
    }
    
    // MARK: - Generic Persistence
    
    private func fileURL(for filename: String) -> URL {
        storageDirectory.appendingPathComponent(filename)
    }
    
    public func save<T: Encodable>(_ object: T, filename: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try self.jsonEncoder.encode(object)
                let url = self.fileURL(for: filename)
                try data.write(to: url, options: [.atomicWrite])
            } catch {
                print("[StorageManager] Error saving \(filename): \(error)")
            }
        }
    }
    
    public func load<T: Decodable>(_ type: T.Type, filename: String) -> T? {
        let url = fileURL(for: filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try jsonDecoder.decode(type, from: data)
        } catch {
            print("[StorageManager] Error loading \(filename): \(error)")
            return nil
        }
    }
    
    // MARK: - Specific Domain Helpers
    
    public func saveWorkSessions(_ sessions: [WorkSession]) {
        save(sessions, filename: "work_sessions.json")
    }
    
    public func loadWorkSessions() -> [WorkSession] {
        load([WorkSession].self, filename: "work_sessions.json") ?? []
    }
    
    public func saveLocations(_ locations: [OfficeLocation]) {
        save(locations, filename: "office_locations.json")
    }
    
    public func loadLocations() -> [OfficeLocation] {
        load([OfficeLocation].self, filename: "office_locations.json") ?? []
    }
    
    public func saveHolidaysAndPTO(_ pto: [HolidayOrPTO]) {
        save(pto, filename: "holidays_pto.json")
    }
    
    public func loadHolidaysAndPTO() -> [HolidayOrPTO] {
        load([HolidayOrPTO].self, filename: "holidays_pto.json") ?? []
    }
    
    public func saveSettings(_ settings: UserSettings) {
        save(settings, filename: "user_settings.json")
    }
    
    public func loadSettings() -> UserSettings {
        load(UserSettings.self, filename: "user_settings.json") ?? UserSettings()
    }
    
    // MARK: - CSV Export
    
    public func generateSessionsCSV(sessions: [WorkSession]) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        
        var csv = "Session ID,Date,Clock In,Clock Out,Gross Hours,Break Hours,Net Work Hours,Breaks Count,Auto Logged,Notes\n"
        
        let sorted = sessions.sorted { $0.clockInTime > $1.clockInTime }
        
        for s in sorted {
            let clockInStr = dateFormatter.string(from: s.clockInTime)
            let clockOutStr = s.clockOutTime.map { dateFormatter.string(from: $0) } ?? "Active"
            let grossHours = String(format: "%.2f", s.grossDuration() / 3600.0)
            let breakHours = String(format: "%.2f", s.totalBreakDuration() / 3600.0)
            let netHours = String(format: "%.2f", s.netWorkHours())
            let dateStr = DateFormatter.localizedString(from: s.clockInTime, dateStyle: .short, timeStyle: .none)
            let cleanNotes = s.notes.replacingOccurrences(of: "\"", with: "\"\"")
            
            csv += "\"\(s.id.uuidString)\",\"\(dateStr)\",\"\(clockInStr)\",\"\(clockOutStr)\",\(grossHours),\(breakHours),\(netHours),\(s.breaks.count),\(s.isAutoLogged),\"\(cleanNotes)\"\n"
        }
        
        return csv
    }
}
