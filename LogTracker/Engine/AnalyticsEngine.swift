import Foundation

public struct DailyHoursSummary: Identifiable, Equatable, Sendable {
    public var id: Date { date }
    public var date: Date
    public var netHours: Double
    public var grossHours: Double
    public var breakHours: Double
    public var isWeekday: Bool
    public var isPtoOrHoliday: Bool
    public var ptoTitle: String?
    
    public init(
        date: Date,
        netHours: Double,
        grossHours: Double,
        breakHours: Double,
        isWeekday: Bool,
        isPtoOrHoliday: Bool,
        ptoTitle: String? = nil
    ) {
        self.date = date
        self.netHours = netHours
        self.grossHours = grossHours
        self.breakHours = breakHours
        self.isWeekday = isWeekday
        self.isPtoOrHoliday = isPtoOrHoliday
        self.ptoTitle = ptoTitle
    }
}

public struct WeeklyHoursSummary: Identifiable, Equatable, Sendable {
    public var id: Int { weekIndex }
    public var weekIndex: Int
    public var startOfWeek: Date
    public var endOfWeek: Date
    public var totalNetHours: Double
    public var eligibleWorkdays: Int
    public var averageDailyHours: Double {
        eligibleWorkdays > 0 ? totalNetHours / Double(eligibleWorkdays) : 0.0
    }
}

public struct TrailingAverageResult: Equatable, Sendable {
    public var trailingAverage: Double
    public var totalNetHours: Double
    public var standardWorkdaysCount: Int
    public var ptoHolidayDeductions: Int
    public var effectiveWorkdays: Int
    public var targetHoursPerDay: Double
    public var warningHoursPerDay: Double
    
    public var isBelowWarning: Bool {
        trailingAverage < warningHoursPerDay
    }
    
    public var isBelowTarget: Bool {
        trailingAverage < targetHoursPerDay
    }
    
    public var hoursNeededToReachWarning: Double {
        let desiredTotal = Double(effectiveWorkdays) * warningHoursPerDay
        return max(0, desiredTotal - totalNetHours)
    }
    
    public var hoursNeededToReachTarget: Double {
        let desiredTotal = Double(effectiveWorkdays) * targetHoursPerDay
        return max(0, desiredTotal - totalNetHours)
    }
    
    public var statusDescription: String {
        if trailingAverage >= warningHoursPerDay {
            return "Good Standing"
        } else if trailingAverage >= targetHoursPerDay {
            return "Attention Needed"
        } else {
            return "Below Minimum"
        }
    }
}

public struct AnalyticsEngine: Sendable {
    public var calendar: Calendar
    
    public init(calendar: Calendar = .current) {
        var cal = calendar
        cal.firstWeekday = 2
        self.calendar = cal
    }
    
    public func trailingWindow(weeks: Int = 8, referenceDate: Date = Date()) -> (start: Date, end: Date) {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let currentWeekday = calendar.component(.weekday, from: startOfToday)
        let daysSinceMonday = (currentWeekday + 5) % 7
        
        guard let currentWeekMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfToday),
              let windowStartMonday = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: currentWeekMonday),
              let endOfCurrentWeek = calendar.date(byAdding: .day, value: 7, to: currentWeekMonday) else {
            return (startOfToday, startOfToday)
        }
        
        return (windowStartMonday, endOfCurrentWeek)
    }
    
    public func allWeekdaysInWindow(startDate: Date, endDate: Date) -> [Date] {
        var weekdays: [Date] = []
        var currentDate = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        
        while currentDate < end {
            let weekday = calendar.component(.weekday, from: currentDate)
            if weekday != 1 && weekday != 7 {
                weekdays.append(currentDate)
            }
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
        return weekdays
    }
    
    public func calculateTrailingAverage(
        sessions: [WorkSession],
        holidaysAndPTO: [HolidayOrPTO],
        settings: UserSettings = UserSettings(),
        referenceDate: Date = Date()
    ) -> TrailingAverageResult {
        let (windowStart, windowEnd) = trailingWindow(weeks: settings.trailingWeeksCount, referenceDate: referenceDate)
        let weekdays = allWeekdaysInWindow(startDate: windowStart, endDate: windowEnd)
        let totalStandardWeekdays = weekdays.count
        
        let holidayDates = Set(holidaysAndPTO.map { calendar.startOfDay(for: $0.date) })
        let ptoWeekdaysCount = weekdays.filter { holidayDates.contains($0) }.count
        let effectiveWorkdays = max(1, totalStandardWeekdays - ptoWeekdaysCount)
        
        let windowSessions = sessions.filter { session in
            let sessionDate = session.dayDate(calendar: calendar)
            return sessionDate >= windowStart && sessionDate < windowEnd
        }
        
        let totalNetHours = windowSessions.reduce(0.0) { total, session in
            total + session.netWorkHours(at: referenceDate)
        }
        
        let trailingAvg = totalNetHours / Double(effectiveWorkdays)
        
        return TrailingAverageResult(
            trailingAverage: trailingAvg,
            totalNetHours: totalNetHours,
            standardWorkdaysCount: totalStandardWeekdays,
            ptoHolidayDeductions: ptoWeekdaysCount,
            effectiveWorkdays: effectiveWorkdays,
            targetHoursPerDay: settings.targetHoursPerDay,
            warningHoursPerDay: settings.warningHoursPerDay
        )
    }
    
    public func generateDailySummaries(
        sessions: [WorkSession],
        holidaysAndPTO: [HolidayOrPTO],
        weeks: Int = 8,
        referenceDate: Date = Date()
    ) -> [DailyHoursSummary] {
        let (windowStart, windowEnd) = trailingWindow(weeks: weeks, referenceDate: referenceDate)
        var summaries: [DailyHoursSummary] = []
        
        let ptoMap = Dictionary(
            uniqueKeysWithValues: holidaysAndPTO.map { (calendar.startOfDay(for: $0.date), $0) }
        )
        
        let sessionsByDay = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.clockInTime)
        }
        
        var currentDate = calendar.startOfDay(for: windowStart)
        let end = calendar.startOfDay(for: windowEnd)
        
        while currentDate < end {
            let weekday = calendar.component(.weekday, from: currentDate)
            let isWeekday = (weekday != 1 && weekday != 7)
            let pto = ptoMap[currentDate]
            
            let daySessions = sessionsByDay[currentDate] ?? []
            let gross = daySessions.reduce(0.0) { $0 + ($1.grossDuration(at: referenceDate) / 3600.0) }
            let breaks = daySessions.reduce(0.0) { $0 + ($1.totalBreakDuration(at: referenceDate) / 3600.0) }
            let net = max(0, gross - breaks)
            
            summaries.append(DailyHoursSummary(
                date: currentDate,
                netHours: net,
                grossHours: gross,
                breakHours: breaks,
                isWeekday: isWeekday,
                isPtoOrHoliday: pto != nil,
                ptoTitle: pto?.title
            ))
            
            guard let next = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = next
        }
        
        return summaries
    }
    
    public func generateBaselineSessions(
        averageHours: Double,
        referenceDate: Date = Date()
    ) -> [WorkSession] {
        guard averageHours > 0 else { return [] }
        let (windowStart, windowEnd) = trailingWindow(weeks: 8, referenceDate: referenceDate)
        let weekdays = allWeekdaysInWindow(startDate: windowStart, endDate: windowEnd)
        
        var sessions: [WorkSession] = []
        let secondsPerDay = averageHours * 3600.0
        
        for weekday in weekdays {
            let clockIn = weekday.addingTimeInterval(3600 * 9)
            let clockOut = clockIn.addingTimeInterval(secondsPerDay)
            
            let session = WorkSession(
                id: UUID(),
                clockInTime: clockIn,
                clockOutTime: clockOut,
                breaks: [],
                isAutoLogged: false,
                locationId: nil,
                notes: "Initial Baseline Setup"
            )
            sessions.append(session)
        }
        
        return sessions.sorted { $0.clockInTime > $1.clockInTime }
    }
}
