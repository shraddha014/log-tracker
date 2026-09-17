import SwiftUI

public struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingExportShareSheet = false
    @State private var exportedCSVURL: URL?
    @State private var showingTestNotificationAlert = false
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                // 1. Clocking Style Section
                Section {
                    Picker("Clocking Style", selection: Binding(
                        get: { viewModel.settings.clockingMode },
                        set: { newMode in
                            var updated = viewModel.settings
                            updated.clockingMode = newMode
                            viewModel.updateSettings(updated)
                        }
                    )) {
                        ForEach(ClockingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text(viewModel.settings.clockingMode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Geofence Clocking Mode")
                } footer: {
                    Text("Choose whether entering the office geofence logs your time automatically or sends an interactive confirmation prompt.")
                }
                
                // 2. Trailing Average Thresholds
                Section("Trailing Average Targets") {
                    HStack {
                        Text("Required Target")
                        Spacer()
                        Text(String(format: "%.1f hrs/day", viewModel.settings.targetHoursPerDay))
                            .bold()
                        Stepper("", value: Binding(
                            get: { viewModel.settings.targetHoursPerDay },
                            set: { val in
                                var updated = viewModel.settings
                                updated.targetHoursPerDay = (val * 10).rounded() / 10
                                viewModel.updateSettings(updated)
                            }
                        ), in: 1.0...12.0, step: 0.1)
                        .labelsHidden()
                    }
                    
                    HStack {
                        Text("Warning Buffer")
                        Spacer()
                        Text(String(format: "%.1f hrs/day", viewModel.settings.warningHoursPerDay))
                            .bold()
                            .foregroundColor(.orange)
                        Stepper("", value: Binding(
                            get: { viewModel.settings.warningHoursPerDay },
                            set: { val in
                                var updated = viewModel.settings
                                updated.warningHoursPerDay = (val * 10).rounded() / 10
                                viewModel.updateSettings(updated)
                            }
                        ), in: 1.0...12.0, step: 0.1)
                        .labelsHidden()
                    }
                    
                    HStack {
                        Text("Trailing Window")
                        Spacer()
                        Text("\(viewModel.settings.trailingWeeksCount) Weeks (40 Weekdays)")
                            .foregroundColor(.secondary)
                    }
                }
                
                // 3. Daily Compliance Notifications
                Section("Notifications & Alerts") {
                    Toggle("Enable Daily Trailing Alerts", isOn: Binding(
                        get: { viewModel.settings.enableDailyAlerts },
                        set: { val in
                            var updated = viewModel.settings
                            updated.enableDailyAlerts = val
                            viewModel.updateSettings(updated)
                        }
                    ))
                    
                    Button {
                        NotificationManager.shared.requestAuthorization { granted in
                            DispatchQueue.main.async {
                                showingTestNotificationAlert = true
                            }
                        }
                    } label: {
                        Label("Request / Check Permissions", systemImage: "bell.badge")
                    }
                    
                    Button {
                        NotificationManager.shared.checkAndNotifyTrailingAverage(
                            result: viewModel.trailingResult,
                            force: true
                        )
                    } label: {
                        Label("Test Trailing Alert Notification", systemImage: "paperplane")
                    }
                }
                
                // 4. Data Export & Baseline
                Section("Data & Privacy") {
                    Button {
                        prepareCSVExport()
                    } label: {
                        Label("Export Work Logs (CSV)", systemImage: "square.and.arrow.up")
                    }
                    
                    if let baseline = viewModel.settings.initialBaselineAverage {
                        HStack {
                            Text("Initial Configured Baseline")
                            Spacer()
                            Text(String(format: "%.1f hrs/day", baseline))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(role: .destructive) {
                        var updated = viewModel.settings
                        updated.hasCompletedOnboarding = false
                        viewModel.updateSettings(updated)
                    } label: {
                        Label("Re-run Initial Onboarding", systemImage: "arrow.counterclockwise")
                    }
                    
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("100% On-Device Storage")
                                .font(.subheadline.bold())
                            Text("All work sessions, breaks, and geofences remain strictly on your iPhone. Zero server sync, 100% private and free.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingExportShareSheet) {
                if let url = exportedCSVURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Notification Setup", isPresented: $showingTestNotificationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Notification permissions requested. Check Settings > Notifications > LogTracker if needed.")
            }
        }
    }
    
    private func prepareCSVExport() {
        let csvContent = viewModel.exportCSVData()
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("office_hours_export_\(Date().formatted(date: .numeric, time: .omitted)).csv")
        
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            exportedCSVURL = fileURL
            showingExportShareSheet = true
        } catch {
            print("CSV Export error: \(error)")
        }
    }
}

public struct ShareSheet: UIViewControllerRepresentable {
    public var activityItems: [Any]
    public var applicationActivities: [UIActivity]? = nil
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
