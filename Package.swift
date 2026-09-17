// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LogTrackerCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "LogTrackerCore",
            targets: ["LogTrackerCore"]
        ),
        .executable(
            name: "test-runner",
            targets: ["TestRunner"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LogTrackerCore",
            path: "LogTracker",
            exclude: [
                "App",
                "Views",
                "ViewModels",
                "Resources",
                "Engine/NotificationManager.swift",
                "Engine/LocationManager.swift",
                "Engine/LocationSearchService.swift"
            ],
            sources: [
                "Models/BreakSession.swift",
                "Models/WorkSession.swift",
                "Models/OfficeLocation.swift",
                "Models/HolidayOrPTO.swift",
                "Models/UserSettings.swift",
                "Engine/AnalyticsEngine.swift",
                "Engine/StorageManager.swift"
            ]
        ),
        .executableTarget(
            name: "TestRunner",
            dependencies: ["LogTrackerCore"],
            path: "Tests/TestRunner"
        )
    ]
)
