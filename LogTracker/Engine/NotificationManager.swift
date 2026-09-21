import Foundation
import UserNotifications

public final class NotificationManager: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    public static let shared = NotificationManager()
    
    public static let categoryArrival = "OFFICE_ARRIVAL_CATEGORY"
    public static let categoryDeparture = "OFFICE_DEPARTURE_CATEGORY"
    public static let actionClockIn = "ACTION_CLOCK_IN"
    public static let actionClockOut = "ACTION_CLOCK_OUT"
    
    public var onClockInActionRequested: (() -> Void)?
    public var onClockOutActionRequested: (() -> Void)?
    
    private var lastAlertDate: Date?
    
    public override init() {
        super.init()
        setupCategories()
    }
    
    public func requestAuthorization(completion: @escaping (Bool) -> Void = { _ in }) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("[NotificationManager] Authorization error: \(error)")
            }
            completion(granted)
        }
    }
    
    private func setupCategories() {
        let clockInAction = UNNotificationAction(
            identifier: NotificationManager.actionClockIn,
            title: "Clock In Now",
            options: [.foreground]
        )
        
        let clockOutAction = UNNotificationAction(
            identifier: NotificationManager.actionClockOut,
            title: "Clock Out Now",
            options: [.foreground]
        )
        
        let arrivalCategory = UNNotificationCategory(
            identifier: NotificationManager.categoryArrival,
            actions: [clockInAction],
            intentIdentifiers: [],
            options: []
        )
        
        let departureCategory = UNNotificationCategory(
            identifier: NotificationManager.categoryDeparture,
            actions: [clockOutAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([arrivalCategory, departureCategory])
    }
    
    // MARK: - Geofence Arrival & Departure Notifications
    
    public func sendArrivalPrompt(locationName: String) {
        let content = UNMutableNotificationContent()
        content.title = "📍 Arrived at \(locationName)"
        content.body = "You just entered the office area. Would you like to clock in?"
        content.sound = .default
        content.categoryIdentifier = NotificationManager.categoryArrival
        
        let request = UNNotificationRequest(
            identifier: "arrival_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    public func sendDeparturePrompt(locationName: String) {
        let content = UNMutableNotificationContent()
        content.title = "👋 Left \(locationName)"
        content.body = "You have left the office area. Would you like to clock out?"
        content.sound = .default
        content.categoryIdentifier = NotificationManager.categoryDeparture
        
        let request = UNNotificationRequest(
            identifier: "departure_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    public func sendAutoClockedInNotice(locationName: String) {
        let content = UNMutableNotificationContent()
        content.title = "⏱️ Auto Clocked In"
        content.body = "Welcome to \(locationName). Your office hours session has started."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "autoin_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    public func sendAutoClockedOutNotice(locationName: String, netHours: Double) {
        let content = UNMutableNotificationContent()
        content.title = "🏁 Auto Clocked Out"
        content.body = String(format: "Left %@. Logged %.1f net office hours today.", locationName, netHours)
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "autoout_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Trailing 8-Week Average Alerts
    
    public func checkAndNotifyTrailingAverage(result: TrailingAverageResult, force: Bool = false) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if !force, let last = lastAlertDate, calendar.startOfDay(for: last) == today {
            return
        }
        
        guard result.isBelowWarning else { return }
        
        lastAlertDate = Date()
        
        let content = UNMutableNotificationContent()
        if result.isBelowTarget {
            content.title = "🚨 Trailing \(result.trailingWeeksCount)-Week Average Critical"
            content.body = String(
                format: "Average is %.2fh/day (target: %.1fh). Need %.1fh to reach target, or %.1fh to reach %.1fh buffer.",
                result.trailingAverage,
                result.targetHoursPerDay,
                result.hoursNeededToReachTarget,
                result.hoursNeededToReachWarning,
                result.warningHoursPerDay
            )
        } else {
            content.title = "⚠️ Trailing \(result.trailingWeeksCount)-Week Average Warning"
            content.body = String(
                format: "Average is %.2fh/day (target: %.1fh). Above target, but need %.1fh across window to restore %.1fh buffer.",
                result.trailingAverage,
                result.targetHoursPerDay,
                result.hoursNeededToReachWarning,
                result.warningHoursPerDay
            )
        }
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "trailing_avg_alert_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case NotificationManager.actionClockIn:
            onClockInActionRequested?()
        case NotificationManager.actionClockOut:
            onClockOutActionRequested?()
        default:
            break
        }
        completionHandler()
    }
}
