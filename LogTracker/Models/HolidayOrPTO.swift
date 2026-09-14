import Foundation

public enum DayOffType: String, Codable, CaseIterable, Identifiable, Sendable {
    case pto = "Paid Time Off (PTO)"
    case holiday = "Public Holiday"
    case sick = "Sick Leave"
    case other = "Other Leave"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .pto: return "airplane"
        case .holiday: return "calendar.badge.clock"
        case .sick: return "cross.case.fill"
        case .other: return "bookmark.fill"
        }
    }
}

public struct HolidayOrPTO: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var date: Date
    public var type: DayOffType
    public var title: String
    
    public init(
        id: UUID = UUID(),
        date: Date,
        type: DayOffType = .pto,
        title: String = ""
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.type = type
        self.title = title.isEmpty ? type.rawValue : title
    }
}
