import Foundation
import LogTrackerCore

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    if actual != expected {
        print("❌ Assertion Failed: Expected \(expected), but got \(actual). \(message) at line \(line)")
        exit(1)
    }
}

func assertDoubleEqual(_ actual: Double, _ expected: Double, accuracy: Double = 0.01, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    if abs(actual - expected) > accuracy {
        print("❌ Assertion Failed: Expected \(expected) (±\(accuracy)), but got \(actual). \(message) at line \(line)")
        exit(1)
    }
}

print("========================================")
print("  Running LogTrackerCore Verification  ")
print("========================================")

// TEST 1: Work Session & Coffee Break Tracking
print("\n[TEST 1] WorkSession with Coffee Break Duration...")
do {
    let baseDate = Date(timeIntervalSince1970: 1700000000)
    let clockIn = baseDate
    let clockOut = baseDate.addingTimeInterval(3600 * 5) // 5 gross hours
    
    let break1 = BreakSession(
        id: UUID(),
        startTime: baseDate.addingTimeInterval(3600 * 2),
        endTime: baseDate.addingTimeInterval(3600 * 2.5),
        category: .coffee,
        note: "Espresso break"
    )
    
    let break2 = BreakSession(
        id: UUID(),
        startTime: baseDate.addingTimeInterval(3600 * 3.5),
        endTime: baseDate.addingTimeInterval(3600 * 3.75),
        category: .personal,
        note: "Walk"
    )
    
    let session = WorkSession(
        clockInTime: clockIn,
        clockOutTime: clockOut,
        breaks: [break1, break2]
    )
    
    assertDoubleEqual(session.grossDuration(), 5 * 3600, "Gross duration must be 5 hours")
    assertDoubleEqual(session.totalBreakDuration(), 45 * 60, "Break duration must be 45 minutes")
    assertDoubleEqual(session.netWorkDuration(), (5 * 3600) - (45 * 60), "Net duration must subtract breaks")
    assertDoubleEqual(session.netWorkHours(), 4.25, "Net work hours must be 4.25 hours")
    print("  ✅ Passed: Gross=5.0h, Breaks=0.75h (Coffee+Personal), Net=4.25h")
}

// TEST 2: 8-Week Window & 40 Standard Weekdays
print("\n[TEST 2] Trailing 8-Week Window Weekday Count...")
do {
    let engine = AnalyticsEngine()
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    let refDate = calendar.date(from: DateComponents(year: 2023, month: 11, day: 17))!
    
    let (start, end) = engine.trailingWindow(weeks: 8, referenceDate: refDate)
    let weekdays = engine.allWeekdaysInWindow(startDate: start, endDate: end)
    
    assertEqual(weekdays.count, 40, "8 weeks must have exactly 40 weekdays (Monday to Friday)")
    print("  ✅ Passed: Exactly 40 Mon-Fri workdays in 8-week window")
}

// TEST 3: Trailing Average Calculation (Target & Buffer)
print("\n[TEST 3] Trailing Average Math without PTO (4.5h target)...")
do {
    let engine = AnalyticsEngine()
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    let refDate = calendar.date(from: DateComponents(year: 2023, month: 11, day: 17))!
    
    let (start, end) = engine.trailingWindow(weeks: 8, referenceDate: refDate)
    let weekdays = engine.allWeekdaysInWindow(startDate: start, endDate: end)
    
    var sessions: [WorkSession] = []
    for day in weekdays {
        let session = WorkSession(
            clockInTime: day.addingTimeInterval(3600 * 9),
            clockOutTime: day.addingTimeInterval(3600 * 13.5) // 4.5h per day
        )
        sessions.append(session)
    }
    
    let result = engine.calculateTrailingAverage(
        sessions: sessions,
        holidaysAndPTO: [],
        settings: UserSettings(targetHoursPerDay: 4.0, warningHoursPerDay: 4.5),
        referenceDate: refDate
    )
    
    assertEqual(result.standardWorkdaysCount, 40)
    assertEqual(result.ptoHolidayDeductions, 0)
    assertEqual(result.effectiveWorkdays, 40)
    assertDoubleEqual(result.totalNetHours, 180.0)
    assertDoubleEqual(result.trailingAverage, 4.5)
    assertEqual(result.isBelowWarning, false)
    assertEqual(result.isBelowTarget, false)
    print("  ✅ Passed: 180.0h / 40 days = 4.50h/day (On Buffer, No Alerts)")
}

// TEST 4: Trailing Average with PTO / Holiday Exclusions
print("\n[TEST 4] Trailing Average with PTO Deductions (Denominator Reduction)...")
do {
    let engine = AnalyticsEngine()
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    let refDate = calendar.date(from: DateComponents(year: 2023, month: 11, day: 17))!
    
    let (start, end) = engine.trailingWindow(weeks: 8, referenceDate: refDate)
    let weekdays = engine.allWeekdaysInWindow(startDate: start, endDate: end)
    
    let pto1 = HolidayOrPTO(date: weekdays[0], type: .pto, title: "Thanksgiving")
    let pto2 = HolidayOrPTO(date: weekdays[1], type: .holiday, title: "Day After")
    let holidays = [pto1, pto2]
    
    var sessions: [WorkSession] = []
    for day in weekdays.dropFirst(2) {
        let session = WorkSession(
            clockInTime: day.addingTimeInterval(3600 * 9),
            clockOutTime: day.addingTimeInterval(3600 * 13) // 4.0h
        )
        sessions.append(session)
    }
    
    let result = engine.calculateTrailingAverage(
        sessions: sessions,
        holidaysAndPTO: holidays,
        settings: UserSettings(targetHoursPerDay: 4.0, warningHoursPerDay: 4.5),
        referenceDate: refDate
    )
    
    assertEqual(result.standardWorkdaysCount, 40)
    assertEqual(result.ptoHolidayDeductions, 2)
    assertEqual(result.effectiveWorkdays, 38)
    assertDoubleEqual(result.totalNetHours, 152.0)
    assertDoubleEqual(result.trailingAverage, 4.0)
    assertEqual(result.isBelowWarning, true)
    assertEqual(result.isBelowTarget, false)
    assertDoubleEqual(result.hoursNeededToReachWarning, 19.0)
    print("  ✅ Passed: 152.0h / 38 effective days = 4.00h/day (Warns: Need 19.0h to hit 4.5h buffer)")
}

// TEST 5: CSV Export Formatting
print("\n[TEST 5] CSV Export formatting...")
do {
    let storage = StorageManager()
    let session = WorkSession(
        clockInTime: Date(timeIntervalSince1970: 1700000000),
        clockOutTime: Date(timeIntervalSince1970: 1700014400),
        breaks: [],
        isAutoLogged: true,
        notes: "Office Day"
    )
    
    let csv = storage.generateSessionsCSV(sessions: [session])
    if !csv.contains("Session ID,Date,Clock In,Clock Out,Gross Hours,Break Hours,Net Work Hours") {
        print("❌ CSV missing header")
        exit(1)
    }
    if !csv.contains("Office Day") || !csv.contains("4.00") {
        print("❌ CSV missing session row data")
        exit(1)
    }
    print("  ✅ Passed: CSV successfully formatted with headers and session data")
}

// TEST 6: Onboarding Baseline Backfill & Trailing Average Initialization
print("\n[TEST 6] Onboarding Baseline Backfill (e.g. 4.3h target)...")
do {
    let engine = AnalyticsEngine()
    let baselineInput = 4.3
    let generatedSessions = engine.generateBaselineSessions(averageHours: baselineInput)
    
    assertEqual(generatedSessions.count, 40, "Backfill must generate 40 workdays for past 8 weeks")
    
    let result = engine.calculateTrailingAverage(
        sessions: generatedSessions,
        holidaysAndPTO: [],
        settings: UserSettings(targetHoursPerDay: 4.0, warningHoursPerDay: 4.5)
    )
    
    assertDoubleEqual(result.trailingAverage, baselineInput, accuracy: 0.01, "Trailing average must match onboarding input")
    assertEqual(result.isBelowTarget, false)
    assertEqual(result.isBelowWarning, true) // 4.3 is below 4.5 buffer
    print("  ✅ Passed: 40 sessions backfilled. Trailing average initialized to exactly \(baselineInput)h/day")
}

print("\n🎉 ALL LOG TRACKER UNIT TESTS PASSED SUCCESSFULLY! 🎉\n")
