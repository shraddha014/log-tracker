# Office Hours Log Tracker (iPhone)

A 100% free, private, on-device native iOS application built with **SwiftUI** to automatically track office hours via geofencing, manage coffee & lunch breaks, and proactively monitor compliance with a trailing 8-week office presence policy.

---

## Key Features

1. **Smart Geofencing**:
   - Add workplace locations with custom radii (e.g., 200m).
   - "Use Current Location" button to quickly register office coordinates.
   - Dual Clocking Modes (toggle anytime in Settings):
     - **Automatic Mode**: Clocks in when arriving at the office geofence and clocks out upon departure in the background.
     - **Interactive Prompt Mode**: Sends a local push notification ("Arrived at Office: Tap to Clock In", "Left Office: Tap to Clock Out").
2. **Break & Coffee Tracking**:
   - One-tap Coffee Break, Lunch, or Personal Break.
   - Live session timer subtracts break time in real-time to compute true **Net Office Hours**.
   - Full retroactive editing: adjust start/end times or add/delete breaks manually.
3. **Trailing 8-Week Compliance & Notification Engine**:
   - Trailing 8 calendar weeks window (Monday to Friday, standard 40 workdays).
   - **PTO & Holiday Exclusion**: Log days off to remove them from the 40-day denominator so your average is not unfairly penalized.
   - **Mathematical Formula**:
     $$\text{Trailing Average} = \frac{\sum \text{Net Office Hours in past 8 weeks}}{40 - \text{Count}(\text{PTO / Holidays})}$$
   - **Configurable Targets**:
     - Standard Target: **4.0 hrs/day**
     - Safety Buffer: **4.5 hrs/day**
   - **Daily Compliance Alerts**: Evaluates your trailing average once a day and notifies you if it slips below the 4.5h safety buffer, projecting exactly how many hours are needed to recover.
4. **Data Privacy & Zero Cost**:
   - 100% on-device storage. No accounts, no servers, no recurring fees.
   - One-tap CSV export of all work sessions and breaks for personal records or HR submissions.

---

## Project Structure

```
log-tracker/
├── LogTracker.xcodeproj/        # Standard Xcode project
├── LogTracker/
│   ├── App/
│   │   └── LogTrackerApp.swift  # SwiftUI @main entry point
│   ├── Models/
│   │   ├── BreakSession.swift   # Coffee, lunch, and personal breaks
│   │   ├── WorkSession.swift    # Clock in/out, net duration calculation
│   │   ├── OfficeLocation.swift # Geofence coordinates & radius
│   │   ├── HolidayOrPTO.swift   # Excluded leave & holiday dates
│   │   └── UserSettings.swift   # Target thresholds, clocking modes
│   ├── Engine/
│   │   ├── AnalyticsEngine.swift # 8-week trailing math & projections
│   │   ├── LocationManager.swift # CoreLocation geofencing & background monitoring
│   │   ├── NotificationManager.swift # UserNotifications & trailing alerts
│   │   └── StorageManager.swift  # Local JSON persistence & CSV exporter
│   ├── ViewModels/
│   │   └── AppViewModel.swift   # Coordinates state, live timers, & geofences
│   ├── Views/
│   │   ├── MainTabView.swift    # Tab navigation
│   │   ├── DashboardView.swift  # Live status card, timer, coffee button, 8-week gauge
│   │   ├── AnalyticsView.swift  # 8-week breakdown, quotient display, weekly trend
│   │   ├── HistoryView.swift    # Past logs editor & PTO manager
│   │   ├── LocationsView.swift  # Workplace geofences & radius slider
│   │   ├── SettingsView.swift   # Clocking style picker, thresholds, CSV export
│   │   └── ManualSessionEditView.swift # Manual log & break editor
│   └── Resources/
│       └── Info.plist           # CoreLocation background capabilities
├── Tests/
│   └── TestRunner/
│       └── main.swift           # Automated verification test suite
└── Package.swift                # Swift package for CLI builds & testing
```

---

## How to Run on Your iPhone for Free ($0)

You do **not** need a paid Apple Developer account to run this on your own iPhone:

1. **Install Xcode**: Download Xcode for free from the Mac App Store (if not already installed).
2. **Open the Project**: Double-click `LogTracker.xcodeproj` in this folder.
3. **Connect Your iPhone**: Plug your iPhone into your Mac with a USB cable.
4. **Set Up Free Personal Signing**:
   - In Xcode, select the `LogTracker` project in the left sidebar.
   - Select the `LogTracker` target under "Signing & Capabilities".
   - Under "Team", select "Add an Account..." and log in with your free personal Apple ID.
   - Xcode will automatically generate a free personal provisioning profile.
5. **Run**:
   - In the top toolbar, select your iPhone as the destination device.
   - Press the **Play** button (or `Cmd + R`).
   - On your iPhone, go to **Settings > General > VPN & Device Management**, tap your Apple ID, and tap **Trust**.
   - Open the app!

---

## Running Verification Tests on Mac CLI

You can verify the calculations, 8-week trailing average math, break deductions, and CSV export directly from your Mac terminal at any time:

```bash
swift run --disable-sandbox test-runner
```
