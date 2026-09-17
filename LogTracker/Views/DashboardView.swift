import SwiftUI

public struct DashboardView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showingManualEntrySheet = false
    @State private var showingBreakPicker = false
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Current Status & Timer Card
                    statusCard
                    
                    // 2. Trailing 8-Week Average Summary Card
                    trailingAverageCard
                    
                    // 3. Today's Quick Summary
                    todaySummaryCard
                    
                    // 4. Recent Activity
                    recentActivitySection
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }
            .navigationTitle("Office Hours")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingManualEntrySheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingManualEntrySheet) {
                ManualSessionEditView(viewModel: viewModel, sessionToEdit: nil)
            }
            .confirmationDialog("Select Break Type", isPresented: $showingBreakPicker, titleVisibility: .visible) {
                Button("☕️ Coffee Break") {
                    viewModel.startBreak(category: .coffee)
                }
                Button("🥗 Lunch Break") {
                    viewModel.startBreak(category: .lunch)
                }
                Button("🚶 Personal Break") {
                    viewModel.startBreak(category: .personal)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    // MARK: - Status Card
    
    private var statusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Text(statusTitle)
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let session = viewModel.activeSession {
                    Text("Since \(session.clockInTime.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Primary Timer Display
            VStack(spacing: 4) {
                Text(formattedTimerString)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                
                Text(timerSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            
            // Secondary Break Indicator
            if let active = viewModel.activeSession, active.isOnBreak, let currentBreak = active.activeBreak {
                HStack(spacing: 6) {
                    Image(systemName: currentBreak.category.iconName)
                    Text("\(currentBreak.category.rawValue): \(formatDuration(currentBreak.duration(at: viewModel.now)))")
                }
                .font(.subheadline.bold())
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(20)
            }
            
            // Primary Action Buttons
            HStack(spacing: 12) {
                if viewModel.activeSession == nil {
                    // Clock In Button
                    Button {
                        viewModel.clockIn()
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Clock In")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .font(.headline)
                    }
                } else {
                    // Break Button
                    if let active = viewModel.activeSession, active.isOnBreak {
                        Button {
                            viewModel.endBreak()
                        } label: {
                            HStack {
                                Image(systemName: "stop.circle.fill")
                                Text("End Break")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .font(.headline)
                        }
                    } else {
                        Button {
                            showingBreakPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "cup.and.saucer.fill")
                                Text("Take Break")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                            .font(.headline)
                        }
                    }
                    
                    // Clock Out Button
                    Button {
                        viewModel.clockOut()
                    } label: {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("Clock Out")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .font(.headline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
    
    // MARK: - Trailing 8-Week Average Card
    
    private var trailingAverageCard: some View {
        let result = viewModel.trailingResult
        let avg = result.trailingAverage
        let warningThreshold = result.warningHoursPerDay
        let targetThreshold = result.targetHoursPerDay
        
        let cardColor: Color = avg >= warningThreshold ? .green : (avg >= targetThreshold ? .orange : .red)
        let statusBadgeText: String = avg >= warningThreshold 
            ? String(format: "Above %.1fh Buffer", warningThreshold)
            : (avg >= targetThreshold 
                ? String(format: "Below %.1fh Buffer", warningThreshold)
                : String(format: "Below %.1fh Target", targetThreshold))
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trailing 8-Week Average")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%.2f", avg))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("hrs / day")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(statusBadgeText)
                    .font(.caption.bold())
                    .foregroundColor(cardColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(cardColor.opacity(0.12))
                    .cornerRadius(8)
            }
            
            // Progress Gauge Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                    
                    // Filled progress
                    let progressWidth = min(geo.size.width, max(0, CGFloat(avg / 6.0) * geo.size.width))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(cardColor)
                        .frame(width: progressWidth, height: 12)
                    
                    // Target marker
                    let targetX = (CGFloat(targetThreshold) / 6.0) * geo.size.width
                    Rectangle()
                        .fill(Color.primary.opacity(0.6))
                        .frame(width: 2, height: 16)
                        .offset(x: targetX, y: -2)
                    
                    // Warning marker
                    let warningX = (CGFloat(warningThreshold) / 6.0) * geo.size.width
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 2, height: 16)
                        .offset(x: warningX, y: -2)
                }
            }
            .frame(height: 16)
            
            // Indicator Legends
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color.primary.opacity(0.6)).frame(width: 6, height: 6)
                    Text(String(format: "Target: %.1fh", targetThreshold))
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                    Text(String(format: "Buffer: %.1fh", warningThreshold))
                }
                Spacer()
                Text("\(result.effectiveWorkdays) workdays in window")
                    .foregroundColor(.secondary)
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            
            if result.isBelowWarning {
                VStack(alignment: .leading, spacing: 4) {
                    if result.isBelowTarget {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundColor(.red)
                            Text(String(format: "Target deficit: Need %.1fh across window to reach %.1fh target.", result.hoursNeededToReachTarget, targetThreshold))
                                .font(.caption.bold())
                                .foregroundColor(.primary)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "bell.badge.fill")
                                .foregroundColor(.orange)
                            Text(String(format: "Buffer deficit: Need %.1fh across window to reach %.1fh buffer.", result.hoursNeededToReachWarning, warningThreshold))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(String(format: "Above %.1fh target! Need %.1fh across window to reach %.1fh buffer.", targetThreshold, result.hoursNeededToReachWarning, warningThreshold))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
    
    // MARK: - Today's Summary Card
    
    private var todaySummaryCard: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todaySessions = viewModel.sessions.filter { calendar.startOfDay(for: $0.clockInTime) == today }
        let totalNetHours = todaySessions.reduce(0.0) { $0 + $1.netWorkHours(at: viewModel.now) }
        let totalBreaks = todaySessions.reduce(0.0) { $0 + ($1.totalBreakDuration(at: viewModel.now) / 3600.0) }
        
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Net Office Hours")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f hrs", totalNetHours))
                    .font(.title2.bold())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Today's Breaks")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f mins", totalBreaks * 60))
                    .font(.title2.bold())
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    // MARK: - Recent Activity
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Sessions")
                .font(.headline)
            
            if viewModel.sessions.isEmpty {
                Text("No sessions logged yet. Clock in or add a past entry.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(viewModel.sessions.prefix(4)) { session in
                    SessionRowView(session: session, referenceDate: viewModel.now)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var statusColor: Color {
        if let active = viewModel.activeSession {
            return active.isOnBreak ? .orange : .green
        }
        return .gray
    }
    
    private var statusTitle: String {
        if let active = viewModel.activeSession {
            return active.isOnBreak ? "On Break" : "Clocked In"
        }
        return "Clocked Out"
    }
    
    private var formattedTimerString: String {
        guard let session = viewModel.activeSession else {
            return "00:00:00"
        }
        let netSeconds = session.netWorkDuration(at: viewModel.now)
        return formatDuration(netSeconds)
    }
    
    private var timerSubtitle: String {
        guard let session = viewModel.activeSession else {
            return "Ready to start"
        }
        if session.isOnBreak {
            return "Session paused during break"
        }
        return "Net office time running"
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }
}

public struct SessionRowView: View {
    public let session: WorkSession
    public let referenceDate: Date
    
    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.clockInTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.bold())
                
                HStack(spacing: 6) {
                    if session.isActive {
                        Text("Active Now")
                            .font(.caption2.bold())
                            .foregroundColor(.green)
                    } else if let out = session.clockOutTime {
                        Text("Until \(out.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if session.breaks.count > 0 {
                        Text("• \(session.breaks.count) break\(session.breaks.count > 1 ? "s" : "")")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if session.isAutoLogged {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            Text(String(format: "%.2f hrs", session.netWorkHours(at: referenceDate)))
                .font(.headline)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
}
