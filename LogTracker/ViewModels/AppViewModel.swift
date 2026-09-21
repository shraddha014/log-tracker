import Foundation
import Combine
import CoreLocation

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public var sessions: [WorkSession] = []
    @Published public var locations: [OfficeLocation] = []
    @Published public var holidaysAndPTO: [HolidayOrPTO] = []
    @Published public var settings: UserSettings = UserSettings()
    
    @Published public var activeSession: WorkSession?
    @Published public var trailingResult: TrailingAverageResult
    @Published public var now: Date = Date()
    
    private let storage = StorageManager.shared
    private let locationManager = LocationManager.shared
    private let notificationManager = NotificationManager.shared
    private let analyticsEngine = AnalyticsEngine()
    
    private var tickerTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        // Load persisted state
        let loadedSettings = storage.loadSettings()
        let loadedLocations = storage.loadLocations()
        let loadedHolidays = storage.loadHolidaysAndPTO()
        let loadedSessions = storage.loadWorkSessions()
        
        self.settings = loadedSettings
        self.locations = loadedLocations
        self.holidaysAndPTO = loadedHolidays
        self.sessions = loadedSessions
        
        // Find active session if any
        self.activeSession = loadedSessions.first(where: { $0.isActive })
        
        // Compute initial trailing result
        self.trailingResult = analyticsEngine.calculateTrailingAverage(
            sessions: loadedSessions,
            holidaysAndPTO: loadedHolidays,
            settings: loadedSettings
        )
        
        setupTimer()
        setupLocationCallbacks()
        setupNotificationCallbacks()
        syncGeofences()
    }
    
    // MARK: - Live Timer Ticker
    
    private func setupTimer() {
        tickerTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] currentDate in
                self?.now = currentDate
            }
    }
    
    // MARK: - Geofencing & Notification Wiring
    
    private func syncGeofences() {
        locationManager.syncGeofences(locations: locations)
    }
    
    private func setupLocationCallbacks() {
        locationManager.onRegionEntered = { [weak self] office in
            guard let self = self else { return }
            self.handleGeofenceArrival(office: office)
        }
        
        locationManager.onRegionExited = { [weak self] office in
            guard let self = self else { return }
            self.handleGeofenceDeparture(office: office)
        }
    }
    
    private func setupNotificationCallbacks() {
        notificationManager.onClockInActionRequested = { [weak self] in
            Task { @MainActor in
                self?.clockIn(isAuto: false)
            }
        }
        
        notificationManager.onClockOutActionRequested = { [weak self] in
            Task { @MainActor in
                self?.clockOut()
            }
        }
    }
    
    private func handleGeofenceArrival(office: OfficeLocation) {
        if settings.clockingMode == .automatic {
            if activeSession == nil {
                clockIn(locationId: office.id, isAuto: true)
                notificationManager.sendAutoClockedInNotice(locationName: office.name)
            }
        } else {
            notificationManager.sendArrivalPrompt(locationName: office.name)
        }
    }
    
    private func handleGeofenceDeparture(office: OfficeLocation) {
        if settings.clockingMode == .automatic {
            if let active = activeSession {
                let netHours = active.netWorkHours()
                clockOut()
                notificationManager.sendAutoClockedOutNotice(locationName: office.name, netHours: netHours)
            }
        } else {
            if activeSession != nil {
                notificationManager.sendDeparturePrompt(locationName: office.name)
            }
        }
    }
    
    // MARK: - Clock In / Clock Out
    
    public func clockIn(locationId: UUID? = nil, isAuto: Bool = false) {
        guard activeSession == nil else { return }
        
        let newSession = WorkSession(
            id: UUID(),
            clockInTime: Date(),
            clockOutTime: nil,
            breaks: [],
            isAutoLogged: isAuto,
            locationId: locationId,
            notes: ""
        )
        
        sessions.insert(newSession, at: 0)
        activeSession = newSession
        persistSessions()
        recalculateTrailingAverage()
    }
    
    public func clockOut() {
        guard var current = activeSession else { return }
        
        // If currently in a break, close the break first
        if let activeBreakIndex = current.breaks.firstIndex(where: { $0.isActive }) {
            current.breaks[activeBreakIndex].endTime = Date()
        }
        
        current.clockOutTime = Date()
        
        if let idx = sessions.firstIndex(where: { $0.id == current.id }) {
            sessions[idx] = current
        }
        
        activeSession = nil
        persistSessions()
        recalculateTrailingAverage()
        
        // Check if trailing average triggers a notification
        notificationManager.checkAndNotifyTrailingAverage(result: trailingResult)
    }
    
    // MARK: - Breaks
    
    public func startBreak(category: BreakCategory = .coffee, note: String = "") {
        guard var current = activeSession, !current.isOnBreak else { return }
        
        let newBreak = BreakSession(
            id: UUID(),
            startTime: Date(),
            endTime: nil,
            category: category,
            note: note
        )
        current.breaks.append(newBreak)
        
        activeSession = current
        if let idx = sessions.firstIndex(where: { $0.id == current.id }) {
            sessions[idx] = current
        }
        persistSessions()
    }
    
    public func endBreak() {
        guard var current = activeSession,
              let activeBreakIndex = current.breaks.firstIndex(where: { $0.isActive }) else { return }
        
        current.breaks[activeBreakIndex].endTime = Date()
        
        activeSession = current
        if let idx = sessions.firstIndex(where: { $0.id == current.id }) {
            sessions[idx] = current
        }
        persistSessions()
    }
    
    // MARK: - Session CRUD
    
    public func addManualSession(_ session: WorkSession) {
        sessions.append(session)
        sessions.sort { $0.clockInTime > $1.clockInTime }
        if session.isActive {
            activeSession = session
        }
        persistSessions()
        recalculateTrailingAverage()
    }
    
    public func updateSession(_ session: WorkSession) {
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx] = session
            if activeSession?.id == session.id {
                activeSession = session.isActive ? session : nil
            }
            persistSessions()
            recalculateTrailingAverage()
        }
    }
    
    public func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        if activeSession?.id == id {
            activeSession = nil
        }
        persistSessions()
        recalculateTrailingAverage()
    }
    
    // MARK: - Locations CRUD
    
    public func addLocation(_ location: OfficeLocation) {
        locations.append(location)
        storage.saveLocations(locations)
        syncGeofences()
    }
    
    public func updateLocation(_ location: OfficeLocation) {
        if let idx = locations.firstIndex(where: { $0.id == location.id }) {
            locations[idx] = location
            storage.saveLocations(locations)
            syncGeofences()
        }
    }
    
    public func deleteLocation(id: UUID) {
        locations.removeAll { $0.id == id }
        storage.saveLocations(locations)
        syncGeofences()
    }
    
    // MARK: - Holidays & PTO CRUD
    
    public func addHolidayOrPTO(_ item: HolidayOrPTO) {
        holidaysAndPTO.append(item)
        storage.saveHolidaysAndPTO(holidaysAndPTO)
        recalculateTrailingAverage()
    }
    
    public func deleteHolidayOrPTO(id: UUID) {
        holidaysAndPTO.removeAll { $0.id == id }
        storage.saveHolidaysAndPTO(holidaysAndPTO)
        recalculateTrailingAverage()
    }
    
    // MARK: - Onboarding
    
    public func completeOnboarding(initialAverage: Double?) {
        var updatedSettings = settings
        updatedSettings.hasCompletedOnboarding = true
        updatedSettings.initialBaselineAverage = initialAverage
        
        if let avg = initialAverage, avg > 0 {
            let baselineSessions = analyticsEngine.generateBaselineSessions(averageHours: avg, weeks: settings.trailingWeeksCount)
            // Backfill initial past data so user starts with their real-world average
            if self.sessions.isEmpty {
                self.sessions = baselineSessions
                storage.saveWorkSessions(self.sessions)
            }
        }
        
        updateSettings(updatedSettings)
        recalculateTrailingAverage()
    }
    
    // MARK: - Settings
    
    public func updateSettings(_ newSettings: UserSettings) {
        self.settings = newSettings
        storage.saveSettings(newSettings)
        recalculateTrailingAverage()
    }
    
    // MARK: - Calculations & Exports
    
    public func recalculateTrailingAverage() {
        trailingResult = analyticsEngine.calculateTrailingAverage(
            sessions: sessions,
            holidaysAndPTO: holidaysAndPTO,
            settings: settings,
            referenceDate: Date()
        )
    }
    
    public func getDailySummaries(weeks: Int? = nil) -> [DailyHoursSummary] {
        analyticsEngine.generateDailySummaries(
            sessions: sessions,
            holidaysAndPTO: holidaysAndPTO,
            weeks: weeks ?? settings.trailingWeeksCount,
            referenceDate: Date()
        )
    }
    
    public func exportCSVData() -> String {
        storage.generateSessionsCSV(sessions: sessions)
    }
    
    private func persistSessions() {
        storage.saveWorkSessions(sessions)
    }
}
