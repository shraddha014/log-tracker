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
    public var trailingWeeksCount: Int
    
    public init(
        trailingAverage: Double,
        totalNetHours: Double,
        standardWorkdaysCount: Int,
        ptoHolidayDeductions: Int,
        effectiveWorkdays: Int,
        targetHoursPerDay: Double,
        warningHoursPerDay: Double,
        trailingWeeksCount: Int = 8
    ) {
        self.trailingAverage = trailingAverage
        self.totalNetHours = totalNetHours
        self.standardWorkdaysCount = standardWorkdaysCount
        self.ptoHolidayDeductions = ptoHolidayDeductions
        self.effectiveWorkdays = effectiveWorkdays
        self.targetHoursPerDay = targetHoursPerDay
        self.warningHoursPerDay = warningHoursPerDay
        self.trailingWeeksCount = trailingWeeksCount
    }
    
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
        cal.firstWeekday = 2 // Monday is first weekday
        self.calendar = cal
    }
    
    /// Returns the rolling list of working days (Monday–Friday) ending on referenceDate (Today).
    /// If referenceDate is a weekday, it includes today plus the prior (count - 1) weekdays.
    /// If referenceDate is a weekend (Sat/Sun), it collects the most recent `count` weekdays ending on Friday.
    /// This strictly prevents future unworked days of the current week from counting as 0.0 hours.
    public func trailingWeekdays(count: Int = 40, referenceDate: Date = Date()) -> [Date] {
        var weekdays: [Date] = []
        var currentDate = calendar.startOfDay(for: referenceDate)
        
        while weekdays.count < count {
            let weekday = calendar.component(.weekday, from: currentDate)
            // 1 = Sunday, 7 = Saturday
            if weekday != 1 && weekday != 7 {
                weekdays.append(currentDate)
            }
            guard let prevDate = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
            currentDate = prevDate
        }
        
        // Return sorted chronologically (oldest to newest)
        return weekdays.reversed()
    }
    
    /// Returns the earliest date (start of day) of the configured trailing window.
    /// Any sessions clocked in before this timestamp are outside the rolling window.
    public func earliestWindowDate(weeks: Int = 8, referenceDate: Date = Date()) -> Date {
        let weekdays = trailingWeekdays(count: max(1, weeks * 5), referenceDate: referenceDate)
        return weekdays.first ?? calendar.startOfDay(for: referenceDate)
    }
    
    /// Filters work sessions, keeping only sessions that fall within the trailing window (or are currently active).
    /// All sessions older than the window boundary are pruned and discarded.
    public func pruneSessions(
        sessions: [WorkSession],
        weeks: Int = 8,
        referenceDate: Date = Date()
    ) -> [WorkSession] {
        let cutoff = earliestWindowDate(weeks: weeks, referenceDate: referenceDate)
        return sessions.filter { session in
            // Always keep active session even if clocked in before cutoff
            session.isActive || session.clockInTime >= cutoff
        }
    }
    
    /// Filters holidays and PTO entries, keeping only entries that fall on or after the earliest window date.
    public func pruneHolidays(
        holidaysAndPTO: [HolidayOrPTO],
        weeks: Int = 8,
        referenceDate: Date = Date()
    ) -> [HolidayOrPTO] {
        let cutoff = earliestWindowDate(weeks: weeks, referenceDate: referenceDate)
        return holidaysAndPTO.filter { pto in
            calendar.startOfDay(for: pto.date) >= cutoff
        }
    }
    
    /// Main calculation for the trailing average with PTO/Holiday exclusion.
    /// Accurately spans today + the previous 39 working days (40 workdays total).
    public func calculateTrailingAverage(
        sessions: [WorkSession],
        holidaysAndPTO: [HolidayOrPTO],
        settings: UserSettings = UserSettings(),
        referenceDate: Date = Date()
    ) -> TrailingAverageResult {
        let totalRequiredDays = settings.trailingWeeksCount * 5 // Typically 8 * 5 = 40 weekdays
        let weekdays = trailingWeekdays(count: totalRequiredDays, referenceDate: referenceDate)
        let totalStandardWeekdays = weekdays.count
        
        guard let windowStart = weekdays.first,
              let windowLastDay = weekdays.last,
              let windowEnd = calendar.date(byAdding: .day, value: 1, to: windowLastDay) else {
            return TrailingAverageResult(
                trailingAverage: 0,
                totalNetHours: 0,
                standardWorkdaysCount: 0,
                ptoHolidayDeductions: 0,
                effectiveWorkdays: 1,
                targetHoursPerDay: settings.targetHoursPerDay,
                warningHoursPerDay: settings.warningHoursPerDay
            )
        }
        
        let weekdaySet = Set(weekdays)
        
        // Set of PTO/Holiday dates matching any weekday in this 40-workday window
        let holidayDates = Set(holidaysAndPTO.map { calendar.startOfDay(for: $0.date) })
        let ptoWeekdaysCount = weekdays.filter { holidayDates.contains($0) }.count
        let effectiveWorkdays = max(1, totalStandardWeekdays - ptoWeekdaysCount)
        
        // Filter sessions that belong to the weekdays in this rolling 40-workday window
        let windowSessions = sessions.filter { session in
            let sessionDate = session.dayDate(calendar: calendar)
            return weekdaySet.contains(sessionDate) && sessionDate >= windowStart && sessionDate < windowEnd
        }
        
        // Sum net office hours
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
            warningHoursPerDay: settings.warningHoursPerDay,
            trailingWeeksCount: settings.trailingWeeksCount
        )
    }
    
    /// Generates daily summaries for each day in the rolling window (for charts & lists)
    public func generateDailySummaries(
        sessions: [WorkSession],
        holidaysAndPTO: [HolidayOrPTO],
        weeks: Int = 8,
        referenceDate: Date = Date()
    ) -> [DailyHoursSummary] {
        let weekdays = trailingWeekdays(count: weeks * 5, referenceDate: referenceDate)
        var summaries: [DailyHoursSummary] = []
        
        let ptoMap = Dictionary(
            uniqueKeysWithValues: holidaysAndPTO.map { (calendar.startOfDay(for: $0.date), $0) }
        )
        
        let sessionsByDay = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.clockInTime)
        }
        
        for currentDate in weekdays {
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
                isWeekday: true,
                isPtoOrHoliday: pto != nil,
                ptoTitle: pto?.title
            ))
        }
        
        return summaries
    }
    
    /// Generates past baseline sessions for the configured trailing window from a user-supplied target daily average.
    /// Spans today + the prior weekdays so the user's initial average exactly matches their input.
    public func generateBaselineSessions(
        averageHours: Double,
        weeks: Int = 8,
        referenceDate: Date = Date()
    ) -> [WorkSession] {
        guard averageHours > 0 else { return [] }
        let weekdays = trailingWeekdays(count: weeks * 5, referenceDate: referenceDate)
        
        var sessions: [WorkSession] = []
        let secondsPerDay = averageHours * 3600.0
        
        for weekday in weekdays {
            let clockIn = weekday.addingTimeInterval(3600 * 9) // 9:00 AM
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
