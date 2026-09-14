import Foundation

public enum ClockingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic = "Automatic"
    case interactivePrompt = "Notification Prompt"
    
    public var id: String { rawValue }
    
    public var description: String {
        switch self {
        case .automatic:
            return "Automatically clocks you in on arrival and clocks you out on departure."
        case .interactivePrompt:
            return "Sends an interactive notification when you arrive or leave, asking you to confirm clock-in/out."
        }
    }
}

public struct UserSettings: Codable, Equatable, Sendable {
    public var clockingMode: ClockingMode
    public var targetHoursPerDay: Double
    public var warningHoursPerDay: Double
    public var trailingWeeksCount: Int
    public var dailyCheckHour: Int
    public var dailyCheckMinute: Int
    public var enableDailyAlerts: Bool
    public var enableArrivalDepartureAlerts: Bool
    public var debounceMinutes: Int
    public var hasCompletedOnboarding: Bool
    public var initialBaselineAverage: Double?
    
    public init(
        clockingMode: ClockingMode = .automatic,
        targetHoursPerDay: Double = 4.0,
        warningHoursPerDay: Double = 4.5,
        trailingWeeksCount: Int = 8,
        dailyCheckHour: Int = 17,
        dailyCheckMinute: Int = 0,
        enableDailyAlerts: Bool = true,
        enableArrivalDepartureAlerts: Bool = true,
        debounceMinutes: Int = 3,
        hasCompletedOnboarding: Bool = false,
        initialBaselineAverage: Double? = nil
    ) {
        self.clockingMode = clockingMode
        self.targetHoursPerDay = targetHoursPerDay
        self.warningHoursPerDay = warningHoursPerDay
        self.trailingWeeksCount = trailingWeeksCount
        self.dailyCheckHour = dailyCheckHour
        self.dailyCheckMinute = dailyCheckMinute
        self.enableDailyAlerts = enableDailyAlerts
        self.enableArrivalDepartureAlerts = enableArrivalDepartureAlerts
        self.debounceMinutes = debounceMinutes
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.initialBaselineAverage = initialBaselineAverage
    }
}
