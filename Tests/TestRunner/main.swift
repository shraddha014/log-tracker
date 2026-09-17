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

print("\n🎉 ALL LOG TRACKER UNIT TESTS PASSED SUCCESSFULLY! 🎉\n")
