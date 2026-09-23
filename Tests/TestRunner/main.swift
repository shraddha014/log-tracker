import Foundation
import CoreLocation
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

// TEST 2: Rolling 40 Weekdays Ending Today (No Future Days Counted)
print("\n[TEST 2] Rolling 40 Weekdays Ending Today (Mid-week test on Thursday)...")
do {
    let engine = AnalyticsEngine()
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    // Thursday, Nov 16, 2023
    let thursdayRef = calendar.date(from: DateComponents(year: 2023, month: 11, day: 16))!
    
    let weekdays = engine.trailingWeekdays(count: 40, referenceDate: thursdayRef)
    assertEqual(weekdays.count, 40, "Must collect exactly 40 weekdays")
    
    // Latest day must be Thursday itself (not Friday or future days)
    let latestDay = weekdays.last!
    let latestWeekday = calendar.component(.weekday, from: latestDay)
    assertEqual(latestWeekday, 5, "Latest day in window must be Thursday (weekday 5)")
    
    // Friday Nov 17 must NOT be in the window
    let friday = calendar.date(byAdding: .day, value: 1, to: thursdayRef)!
    let containsFriday = weekdays.contains(calendar.startOfDay(for: friday))
    assertEqual(containsFriday, false, "Future unworked Friday must NOT be in the 40-day window")
    
    print("  ✅ Passed: Exactly 40 workdays ending Thursday. Zero future days counted as 0 hours.")
}

// TEST 3: Trailing Average Calculation on Mid-Week Day (Consistent 4.5h)
print("\n[TEST 3] Trailing Average on Thursday with 4.5h/day...")
do {
    let engine = AnalyticsEngine()
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    let thursdayRef = calendar.date(from: DateComponents(year: 2023, month: 11, day: 16))!
    let weekdays = engine.trailingWeekdays(count: 40, referenceDate: thursdayRef)
    
    var sessions: [WorkSession] = []
    for day in weekdays {
        let session = WorkSession(
            clockInTime: day.addingTimeInterval(3600 * 9),
            clockOutTime: day.addingTimeInterval(3600 * 13.5) // 4.5h
        )
        sessions.append(session)
    }
    
    let result = engine.calculateTrailingAverage(
        sessions: sessions,
        holidaysAndPTO: [],
        settings: UserSettings(targetHoursPerDay: 4.0, warningHoursPerDay: 4.5),
        referenceDate: thursdayRef
    )
    
    assertEqual(result.standardWorkdaysCount, 40)
    assertEqual(result.effectiveWorkdays, 40)
    assertDoubleEqual(result.totalNetHours, 180.0)
    assertDoubleEqual(result.trailingAverage, 4.5)
    assertEqual(result.isBelowWarning, false)
    print("  ✅ Passed: On Thursday, average is 4.50h/day without being dragged down by Friday.")
}

// TEST 4: Trailing Average with PTO Deductions
print("\n[TEST 4] Trailing Average with PTO Deductions...")
do {
    let engine = AnalyticsEngine()
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    let refDate = calendar.date(from: DateComponents(year: 2023, month: 11, day: 16))!
    let weekdays = engine.trailingWeekdays(count: 40, referenceDate: refDate)
    
    let pto1 = HolidayOrPTO(date: weekdays[0], type: .pto, title: "Vacation")
    let pto2 = HolidayOrPTO(date: weekdays[1], type: .holiday, title: "Holiday")
    
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
        holidaysAndPTO: [pto1, pto2],
        settings: UserSettings(targetHoursPerDay: 4.0, warningHoursPerDay: 4.5),
        referenceDate: refDate
    )
    
    assertEqual(result.standardWorkdaysCount, 40)
    assertEqual(result.ptoHolidayDeductions, 2)
    assertEqual(result.effectiveWorkdays, 38)
    assertDoubleEqual(result.totalNetHours, 152.0)
    assertDoubleEqual(result.trailingAverage, 4.0)
    print("  ✅ Passed: 152h / 38 effective days = 4.00h/day (Deductions accurate)")
}

// TEST 5: Point-In-Polygon Geofence Verification (Eliminates Road False Alarms)
print("\n[TEST 5] Point-In-Polygon Geofence Verification...")
do {
    // Define an office building rectangular polygon (approx 100m x 100m)
    let p1 = CoordinatePoint(latitude: 37.774900, longitude: -122.419400) // SW corner
    let p2 = CoordinatePoint(latitude: 37.775800, longitude: -122.419400) // NW corner
    let p3 = CoordinatePoint(latitude: 37.775800, longitude: -122.418200) // NE corner
    let p4 = CoordinatePoint(latitude: 37.774900, longitude: -122.418200) // SE corner
    
    let office = OfficeLocation(
        name: "HQ Custom Building",
        latitude: 37.775350,
        longitude: -122.418800,
        polygonCoordinates: [p1, p2, p3, p4]
    )
    
    assertEqual(office.isPolygon, true, "Office must be in polygon mode")
    
    // Test point 1: Inside the building (desk location)
    let deskCoordinate = CLLocationCoordinate2D(latitude: 37.775300, longitude: -122.418800)
    let insideResult = office.contains(coordinate: deskCoordinate)
    assertEqual(insideResult, true, "Desk coordinate must be detected as INSIDE the office")
    
    // Test point 2: On the street 50m north outside the building boundary
    let highwayCoordinate = CLLocationCoordinate2D(latitude: 37.776500, longitude: -122.418800)
    let outsideResult = office.contains(coordinate: highwayCoordinate)
    assertEqual(outsideResult, false, "Highway outside building boundary must NOT trigger arrival")
    
    print("  ✅ Passed: Inside desk = TRUE. Passing on the road outside = FALSE (False alarm prevented!)")
}

// TEST 6: Onboarding Baseline Backfill
print("\n[TEST 6] Onboarding Baseline Backfill...")
do {
    let engine = AnalyticsEngine()
    let baselineInput = 4.3
    let generatedSessions = engine.generateBaselineSessions(averageHours: baselineInput)
    
    assertEqual(generatedSessions.count, 40, "Backfill must generate 40 workdays ending today")
    
    let result = engine.calculateTrailingAverage(
        sessions: generatedSessions,
        holidaysAndPTO: [],
        settings: UserSettings(targetHoursPerDay: 4.0, warningHoursPerDay: 4.5)
    )
    
    assertDoubleEqual(result.trailingAverage, baselineInput, accuracy: 0.01)
    print("  ✅ Passed: Initialized to exactly \(baselineInput)h/day")
}

// TEST 7: Backward Compatibility for OfficeLocation (Missing polygonCoordinates)
print("\n[TEST 7] OfficeLocation Backward Compatibility (Older JSON)...")
do {
    let legacyJSON = """
    {
        "id": "11111111-2222-3333-4444-555555555555",
        "name": "Legacy Office",
        "latitude": 37.7749,
        "longitude": -122.4194,
        "radiusMeters": 200.0,
        "isActive": true,
        "dateCreated": "2023-11-16T12:00:00Z"
    }
    """.data(using: .utf8)!
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(OfficeLocation.self, from: legacyJSON)
    assertEqual(decoded.name, "Legacy Office")
    assertEqual(decoded.polygonCoordinates.isEmpty, true)
    assertEqual(decoded.isPolygon, false)
    print("  ✅ Passed: Older JSON without polygonCoordinates decoded gracefully with no errors!")
}

// TEST 8: Granular 0.1h Target/Warning Buffers (e.g., 4.3h) & Deficit Verification
print("\n[TEST 8] Granular 0.1h Thresholds & Deficit Verification (4.0h Target, 4.3h Buffer)...")
do {
    let engine = AnalyticsEngine()
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    let refDate = calendar.date(from: DateComponents(year: 2023, month: 11, day: 16))!
    let weekdays = engine.trailingWeekdays(count: 20, referenceDate: refDate)
    
    // Total 74.8 hours across 20 days (average = 3.74h)
    // 19 days at 3.74h + 1 day at 3.74h
    var sessions: [WorkSession] = []
    let totalTargetHours = 74.8
    let hoursPerDay = totalTargetHours / 20.0
    for day in weekdays {
        let session = WorkSession(
            clockInTime: day.addingTimeInterval(3600 * 9),
            clockOutTime: day.addingTimeInterval(3600 * (9 + hoursPerDay))
        )
        sessions.append(session)
    }
    
    // Test with 4.0h target and 4.5h buffer (4 weeks = 20 weekdays)
    let result45 = engine.calculateTrailingAverage(
        sessions: sessions,
        holidaysAndPTO: [],
        settings: UserSettings(targetHoursPerDay: 4.0, warningHoursPerDay: 4.5, trailingWeeksCount: 4),
        referenceDate: refDate
    )
    assertDoubleEqual(result45.trailingAverage, 3.74, accuracy: 0.01)
    assertDoubleEqual(result45.hoursNeededToReachTarget, 5.2, accuracy: 0.01, "Target deficit must be exactly 5.2h")
    assertDoubleEqual(result45.hoursNeededToReachWarning, 15.2, accuracy: 0.01, "4.5h buffer deficit must be exactly 15.2h")
    
    // Test with 4.0h target and user-specified 4.3h warning buffer
    let result43 = engine.calculateTrailingAverage(
        sessions: sessions,
        holidaysAndPTO: [],
        settings: UserSettings(targetHoursPerDay: 4.0, warningHoursPerDay: 4.3, trailingWeeksCount: 4),
        referenceDate: refDate
    )
    assertDoubleEqual(result43.hoursNeededToReachTarget, 5.2, accuracy: 0.01, "Target deficit remains 5.2h")
    // (20 * 4.3) - 74.8 = 86.0 - 74.8 = 11.2h
    assertDoubleEqual(result43.hoursNeededToReachWarning, 11.2, accuracy: 0.01, "4.3h buffer deficit must be exactly 11.2h")
    assertEqual(result43.isBelowTarget, true)
    assertEqual(result43.isBelowWarning, true)
    
    print("  ✅ Passed: 4.0h target deficit = 5.2h. 4.5h buffer deficit = 15.2h. 4.3h buffer deficit = 11.2h.")
}

// TEST 9: Configurable Trailing Window Duration (2, 4, 12 weeks)
print("\n[TEST 9] Configurable Trailing Window Duration (2 Weeks, 4 Weeks, 12 Weeks)...")
do {
    let engine = AnalyticsEngine()
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    let refDate = calendar.date(from: DateComponents(year: 2023, month: 11, day: 16))!
    
    // 2 weeks = 10 weekdays
    let settings2w = UserSettings(trailingWeeksCount: 2)
    let result2w = engine.calculateTrailingAverage(
        sessions: [],
        holidaysAndPTO: [],
        settings: settings2w,
        referenceDate: refDate
    )
    assertEqual(result2w.standardWorkdaysCount, 10, "2-week window must have 10 standard workdays")
    assertEqual(result2w.trailingWeeksCount, 2, "Trailing weeks count must be 2")
    
    // 12 weeks = 60 weekdays
    let settings12w = UserSettings(trailingWeeksCount: 12)
    let result12w = engine.calculateTrailingAverage(
        sessions: [],
        holidaysAndPTO: [],
        settings: settings12w,
        referenceDate: refDate
    )
    assertEqual(result12w.standardWorkdaysCount, 60, "12-week window must have 60 standard workdays")
    assertEqual(result12w.trailingWeeksCount, 12, "Trailing weeks count must be 12")
    
    // Baseline generation with custom weeks (e.g., 6 weeks = 30 sessions)
    let baseline6w = engine.generateBaselineSessions(averageHours: 4.5, weeks: 6, referenceDate: refDate)
    assertEqual(baseline6w.count, 30, "6-week baseline must generate exactly 30 sessions")
    
    print("  ✅ Passed: 2-week window=10 days, 12-week window=60 days, 6-week baseline=30 sessions.")
}

// TEST 10: Automatic Data Retention & Out-of-Window Pruning
print("\n[TEST 10] Automatic Data Retention & Pruning (Purging Obsolete Records)...")
do {
    let engine = AnalyticsEngine()
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    let refDate = calendar.date(from: DateComponents(year: 2023, month: 11, day: 16))!
    
    // Generate 16 weeks of daily work sessions (16 * 5 = 80 weekdays)
    let sixteenWeeks = engine.trailingWeekdays(count: 80, referenceDate: refDate)
    assertEqual(sixteenWeeks.count, 80, "Must generate 80 weekdays")
    
    var allSessions: [WorkSession] = []
    for day in sixteenWeeks {
        let session = WorkSession(
            clockInTime: day.addingTimeInterval(3600 * 9),
            clockOutTime: day.addingTimeInterval(3600 * 13) // 4.0h
        )
        allSessions.append(session)
    }
    
    // Add an active session on an older day to ensure active sessions are never dropped
    let activeOlderSession = WorkSession(
        clockInTime: sixteenWeeks[0].addingTimeInterval(3600 * 8),
        clockOutTime: nil // Active!
    )
    allSessions.append(activeOlderSession)
    
    // 1. Prune with 8-week window (should retain 40 weekdays + 1 active session = 41 sessions)
    let pruned8w = engine.pruneSessions(sessions: allSessions, weeks: 8, referenceDate: refDate)
    assertEqual(pruned8w.count, 41, "8-week retention must retain exactly 40 completed weekdays + 1 active session")
    assertEqual(pruned8w.contains(where: { $0.id == activeOlderSession.id }), true, "Active session must never be pruned")
    
    // Verify all pruned completed sessions are >= earliest 8-week date
    let earliest8w = engine.earliestWindowDate(weeks: 8, referenceDate: refDate)
    for s in pruned8w where !s.isActive {
        assertEqual(s.clockInTime >= earliest8w, true, "Retained session must be within the 8-week window")
    }
    
    // 2. Prune with 4-week window (should retain 20 weekdays + 1 active session = 21 sessions)
    let pruned4w = engine.pruneSessions(sessions: pruned8w, weeks: 4, referenceDate: refDate)
    assertEqual(pruned4w.count, 21, "4-week retention must retain exactly 20 completed weekdays + 1 active session")
    
    // 3. Prune PTO entries: 1 within window, 1 older than window
    let ptoRecent = HolidayOrPTO(date: sixteenWeeks[75], type: .pto, title: "Recent PTO")
    let ptoOld = HolidayOrPTO(date: sixteenWeeks[10], type: .holiday, title: "Old Holiday")
    let prunedPto = engine.pruneHolidays(holidaysAndPTO: [ptoRecent, ptoOld], weeks: 8, referenceDate: refDate)
    assertEqual(prunedPto.count, 1, "Must prune 1 old holiday")
    assertEqual(prunedPto.first?.title, "Recent PTO", "Must keep the PTO within the 8-week window")
    
    print("  ✅ Passed: 80 sessions pruned to 40 for 8 weeks, further pruned to 20 for 4 weeks. Old PTO pruned.")
}

print("\n🎉 ALL LOG TRACKER UNIT TESTS PASSED SUCCESSFULLY! 🎉\n")
