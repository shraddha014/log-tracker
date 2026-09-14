import SwiftUI

public struct HistoryView: View {
    @ObservedObject var viewModel: AppViewModel
    
    @State private var selectedTab = 0 // 0: Sessions, 1: Holidays & PTO
    @State private var sessionToEdit: WorkSession?
    @State private var showingAddSessionSheet = false
    @State private var showingAddPtoSheet = false
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedTab) {
                    Text("Work Logs").tag(0)
                    Text("PTO & Holidays").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                if selectedTab == 0 {
                    sessionsList
                } else {
                    ptoList
                }
            }
            .navigationTitle("History & Logs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if selectedTab == 0 {
                            showingAddSessionSheet = true
                        } else {
                            showingAddPtoSheet = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSessionSheet) {
                ManualSessionEditView(viewModel: viewModel, sessionToEdit: nil)
            }
            .sheet(item: $sessionToEdit) { session in
                ManualSessionEditView(viewModel: viewModel, sessionToEdit: session)
            }
            .sheet(isPresented: $showingAddPtoSheet) {
                AddPtoSheet(viewModel: viewModel)
            }
        }
    }
    
    // MARK: - Sessions List
    
    private var sessionsList: some View {
        Group {
            if viewModel.sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Work Logs Found")
                        .font(.headline)
                    Text("Tap '+' to add a manual work session or clock in from the Dashboard.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.sessions) { session in
                        Button {
                            sessionToEdit = session
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(session.clockInTime.formatted(date: .abbreviated, time: .omitted))
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        if session.isAutoLogged {
                                            Image(systemName: "location.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        if session.isActive {
                                            Text("IN PROGRESS")
                                                .font(.caption2.bold())
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.15))
                                                .foregroundColor(.green)
                                                .cornerRadius(4)
                                        }
                                    }
                                    
                                    HStack(spacing: 6) {
                                        Text("\(session.clockInTime.formatted(date: .omitted, time: .shortened)) – \(session.clockOutTime?.formatted(date: .omitted, time: .shortened) ?? "Now")")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        if !session.breaks.isEmpty {
                                            Text("• \(session.breaks.count) break\(session.breaks.count > 1 ? "s" : "") (\(formatMinutes(session.totalBreakDuration())))")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    
                                    if !session.notes.isEmpty {
                                        Text(session.notes)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "%.2f hrs", session.netWorkHours(at: viewModel.now)))
                                        .font(.title3.bold())
                                        .foregroundColor(.primary)
                                    Text("Net Time")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 4)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let session = viewModel.sessions[index]
                            viewModel.deleteSession(id: session.id)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
    
    // MARK: - PTO List
    
    private var ptoList: some View {
        Group {
            if viewModel.holidaysAndPTO.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No PTO or Holidays Logged")
                        .font(.headline)
                    Text("Add days off so they are excluded from your 8-week trailing average denominator.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    Section {
                        Text("Dates recorded below are automatically excluded from the standard 40-workday denominator.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ForEach(viewModel.holidaysAndPTO.sorted { $0.date > $1.date }) { pto in
                        HStack {
                            Image(systemName: pto.type.iconName)
                                .font(.title3)
                                .foregroundColor(.purple)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pto.title)
                                    .font(.headline)
                                Text(pto.date.formatted(date: .complete, time: .omitted))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(pto.type.rawValue)
                                .font(.caption.bold())
                                .foregroundColor(.purple)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        let sorted = viewModel.holidaysAndPTO.sorted { $0.date > $1.date }
                        for index in indexSet {
                            let item = sorted[index]
                            viewModel.deleteHolidayOrPTO(id: item.id)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
    
    private func formatMinutes(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds / 60)
        return "\(mins)m"
    }
}

public struct AddPtoSheet: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var date = Date()
    @State private var type: DayOffType = .pto
    @State private var title: String = ""
    
    public var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                
                Picker("Type", selection: $type) {
                    ForEach(DayOffType.allCases) { t in
                        Label(t.rawValue, systemImage: t.iconName).tag(t)
                    }
                }
                
                TextField("Title or Description", text: $title)
            }
            .navigationTitle("Add PTO / Holiday")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let item = HolidayOrPTO(
                            id: UUID(),
                            date: date,
                            type: type,
                            title: title.isEmpty ? type.rawValue : title
                        )
                        viewModel.addHolidayOrPTO(item)
                        dismiss()
                    }
                }
            }
        }
    }
}
