import SwiftUI

public struct AnalyticsView: View {
    @ObservedObject var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Formula & Status Hero Card
                    heroMetricCard
                    
                    // 2. Trailing 8-Week Breakdown Grid
                    breakdownGrid
                    
                    // 3. Weekly Hours Chart / Trend
                    weeklyTrendSection
                    
                    // 4. Daily Hours Visual Grid (Recent 4 Weeks)
                    dailyGridSection
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }
            .navigationTitle("8-Week Analytics")
        }
    }
    
    // MARK: - Hero Metric Card
    
    private var heroMetricCard: some View {
        let result = viewModel.trailingResult
        let avg = result.trailingAverage
        let warning = result.warningHoursPerDay
        let target = result.targetHoursPerDay
        
        let statusColor: Color = avg >= warning ? .green : (avg >= target ? .orange : .red)
        
        return VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trailing 8-Week Daily Average")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.2f", avg))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(statusColor)
                        Text("hrs/day")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(result.statusDescription)
                        .font(.subheadline.bold())
                        .foregroundColor(statusColor)
                    
                    Text("Mon – Fri Only")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(statusColor.opacity(0.12))
                .cornerRadius(10)
            }
            
            Divider()
            
            // Formula display: Total Hours / Effective Days = Average
            HStack(spacing: 8) {
                VStack {
                    Text(String(format: "%.1f hrs", result.totalNetHours))
                        .font(.headline)
                    Text("Total Net Hours")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text("÷")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                VStack {
                    Text("\(result.effectiveWorkdays) days")
                        .font(.headline)
                    Text("Eligible Days")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text("=")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                VStack {
                    Text(String(format: "%.2f hrs/day", avg))
                        .font(.headline)
                        .foregroundColor(statusColor)
                    Text("Trailing Avg")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            
            if result.isBelowWarning {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(statusColor)
                        Text("Compliance Requirement")
                            .font(.subheadline.bold())
                    }
                    
                    if result.isBelowTarget {
                        Text(String(format: "You are currently below the required 4.0h/day threshold by %.2fh. You need %.1f additional office hours across this 8-week cycle.", (target - avg), result.hoursNeededToReachTarget))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(String(format: "You are above the 4.0h minimum, but below your 4.5h safety buffer. You need %.1f more hours to reach the 4.5h buffer.", result.hoursNeededToReachWarning))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(statusColor.opacity(0.08))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
    
    // MARK: - Breakdown Grid
    
    private var breakdownGrid: some View {
        let result = viewModel.trailingResult
        
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricTile(
                title: "Standard Weekdays",
                value: "\(result.standardWorkdaysCount)",
                subtitle: "8 weeks × 5 days = 40",
                icon: "calendar",
                color: .blue
            )
            
            metricTile(
                title: "PTO / Holidays",
                value: "\(result.ptoHolidayDeductions)",
                subtitle: "Excluded from average",
                icon: "airplane",
                color: .purple
            )
            
            metricTile(
                title: "Target Threshold",
                value: String(format: "%.1fh", result.targetHoursPerDay),
                subtitle: "Minimum required",
                icon: "flag.checkered",
                color: .primary
            )
            
            metricTile(
                title: "Warning Buffer",
                value: String(format: "%.1fh", result.warningHoursPerDay),
                subtitle: "Alert buffer target",
                icon: "bell.badge",
                color: .orange
            )
        }
    }
    
    private func metricTile(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
    
    // MARK: - Weekly Trend Section
    
    private var weeklyTrendSection: some View {
        let summaries = viewModel.getDailySummaries(weeks: 8)
        let calendar = Calendar.current
        
        // Group daily summaries into 8 weeks
        let grouped = Dictionary(grouping: summaries) { summary in
            calendar.component(.weekOfYear, from: summary.date)
        }
        
        let sortedWeekKeys = grouped.keys.sorted()
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Progression (Past 8 Weeks)")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(Array(sortedWeekKeys.enumerated()), id: \.offset) { index, weekNumber in
                    if let days = grouped[weekNumber] {
                        let netTotal = days.reduce(0.0) { $0 + $1.netHours }
                        let weekdaysOnly = days.filter { $0.isWeekday && !$0.isPtoOrHoliday }
                        let effectiveDays = max(1, weekdaysOnly.count)
                        let weeklyAvg = netTotal / Double(effectiveDays)
                        let startDate = days.first?.date ?? Date()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Week \(index + 1)")
                                    .font(.subheadline.bold())
                                Text(startDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Visual bar
                            GeometryReader { barGeo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 8)
                                    
                                    let barWidth = min(barGeo.size.width, CGFloat(weeklyAvg / 6.0) * barGeo.size.width)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(weeklyAvg >= 4.5 ? Color.green : (weeklyAvg >= 4.0 ? Color.orange : Color.red))
                                        .frame(width: max(2, barWidth), height: 8)
                                }
                            }
                            .frame(width: 80, height: 8)
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f avg", weeklyAvg))
                                    .font(.subheadline.bold())
                                Text(String(format: "%.1f hrs total", netTotal))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(10)
                    }
                }
            }
        }
    }
    
    // MARK: - Daily Grid Section
    
    private var dailyGridSection: some View {
        let dailySummaries = viewModel.getDailySummaries(weeks: 4)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Daily Breakdown")
                    .font(.headline)
                Spacer()
                Text("Last 4 Weeks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 6) {
                ForEach(dailySummaries.filter { $0.isWeekday }.suffix(20)) { day in
                    HStack {
                        Text(day.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .frame(width: 95, alignment: .leading)
                        
                        if day.isPtoOrHoliday {
                            Text(day.ptoTitle ?? "PTO / Holiday")
                                .font(.caption.bold())
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.purple.opacity(0.12))
                                .cornerRadius(6)
                            Spacer()
                            Text("Excluded")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 6)
                                    
                                    let fillW = min(geo.size.width, CGFloat(day.netHours / 8.0) * geo.size.width)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(day.netHours >= 4.5 ? Color.green : (day.netHours >= 4.0 ? Color.orange : (day.netHours > 0 ? Color.red : Color.gray.opacity(0.3))))
                                        .frame(width: max(0, fillW), height: 6)
                                }
                            }
                            .frame(height: 6)
                            
                            Spacer()
                            
                            Text(day.netHours > 0 ? String(format: "%.1f hrs", day.netHours) : "0.0 hrs")
                                .font(.subheadline.bold())
                                .foregroundColor(day.netHours >= 4.5 ? .primary : (day.netHours >= 4.0 ? .orange : .secondary))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(8)
                }
            }
        }
    }
}
