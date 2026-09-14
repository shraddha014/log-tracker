import Foundation

public enum BreakCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case coffee = "Coffee Break"
    case lunch = "Lunch"
    case personal = "Personal"
    case other = "Other"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .coffee: return "cup.and.saucer.fill"
        case .lunch: return "fork.knife"
        case .personal: return "person.fill"
        case .other: return "ellipsis.circle"
        }
    }
}

public struct BreakSession: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var startTime: Date
    public var endTime: Date?
    public var category: BreakCategory
    public var note: String
    
    public init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        category: BreakCategory = .coffee,
        note: String = ""
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.category = category
        self.note = note
    }
    
    public var isActive: Bool {
        endTime == nil
    }
    
    public func duration(at referenceDate: Date = Date()) -> TimeInterval {
        let end = endTime ?? referenceDate
        guard end >= startTime else { return 0 }
        return end.timeIntervalSince(startTime)
    }
}
