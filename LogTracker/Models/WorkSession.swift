import Foundation

public struct WorkSession: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var clockInTime: Date
    public var clockOutTime: Date?
    public var breaks: [BreakSession]
    public var isAutoLogged: Bool
    public var locationId: UUID?
    public var notes: String
    
    public init(
        id: UUID = UUID(),
        clockInTime: Date = Date(),
        clockOutTime: Date? = nil,
        breaks: [BreakSession] = [],
        isAutoLogged: Bool = false,
        locationId: UUID? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.clockInTime = clockInTime
        self.clockOutTime = clockOutTime
        self.breaks = breaks
        self.isAutoLogged = isAutoLogged
        self.locationId = locationId
        self.notes = notes
    }
    
    public var isActive: Bool {
        clockOutTime == nil
    }
    
    public var activeBreak: BreakSession? {
        breaks.first(where: { $0.isActive })
    }
    
    public var isOnBreak: Bool {
        activeBreak != nil
    }
    
    /// Total duration from clock-in to clock-out (or current time if ongoing)
    public func grossDuration(at referenceDate: Date = Date()) -> TimeInterval {
        let end = clockOutTime ?? referenceDate
        guard end >= clockInTime else { return 0 }
        return end.timeIntervalSince(clockInTime)
    }
    
    /// Sum of all break durations
    public func totalBreakDuration(at referenceDate: Date = Date()) -> TimeInterval {
        breaks.reduce(0) { total, currentBreak in
            total + currentBreak.duration(at: referenceDate)
        }
    }
    
    /// Gross duration minus total break duration
    public func netWorkDuration(at referenceDate: Date = Date()) -> TimeInterval {
        max(0, grossDuration(at: referenceDate) - totalBreakDuration(at: referenceDate))
    }
    
    /// Net work duration in hours
    public func netWorkHours(at referenceDate: Date = Date()) -> Double {
        netWorkDuration(at: referenceDate) / 3600.0
    }
    
    /// Date truncated to start of day for grouping
    public func dayDate(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: clockInTime)
    }
}
