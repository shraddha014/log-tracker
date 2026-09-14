import SwiftUI

public struct ManualSessionEditView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    private let editingSessionId: UUID?
    
    @State private var clockInDate: Date
    @State private var isOngoing: Bool
    @State private var clockOutDate: Date
    @State private var notes: String
    @State private var breaks: [BreakSession]
    @State private var showingAddBreak = false
    
    public init(viewModel: AppViewModel, sessionToEdit: WorkSession? = nil) {
        self.viewModel = viewModel
        self.editingSessionId = sessionToEdit?.id
        
        _clockInDate = State(initialValue: sessionToEdit?.clockInTime ?? Date())
        _isOngoing = State(initialValue: sessionToEdit?.isActive ?? false)
        _clockOutDate = State(initialValue: sessionToEdit?.clockOutTime ?? Date().addingTimeInterval(3600 * 4))
        _notes = State(initialValue: sessionToEdit?.notes ?? "")
        _breaks = State(initialValue: sessionToEdit?.breaks ?? [])
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Work Session Time") {
                    DatePicker("Clock In", selection: $clockInDate)
                    
                    Toggle("Session is ongoing", isOn: $isOngoing)
                    
                    if !isOngoing {
                        DatePicker("Clock Out", selection: $clockOutDate)
                    }
                }
                
                Section("Breaks (Coffee, Lunch, etc.)") {
                    if breaks.isEmpty {
                        Text("No breaks logged for this session.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(breaks) { b in
                            HStack {
                                Image(systemName: b.category.iconName)
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                    Text(b.category.rawValue)
                                        .font(.subheadline.bold())
                                    Text("\(b.startTime.formatted(date: .omitted, time: .shortened)) - \(b.endTime?.formatted(date: .omitted, time: .shortened) ?? "Ongoing")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.0f mins", b.duration() / 60.0))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onDelete { indexSet in
                            breaks.remove(atOffsets: indexSet)
                        }
                    }
                    
                    Button {
                        showingAddBreak = true
                    } label: {
                        Label("Add Break", systemImage: "plus.circle")
                    }
                }
                
                Section("Notes") {
                    TextField("Optional notes...", text: $notes)
                }
                
                Section("Calculated Net Hours") {
                    let gross = isOngoing ? Date().timeIntervalSince(clockInDate) : max(0, clockOutDate.timeIntervalSince(clockInDate))
                    let breakSecs = breaks.reduce(0.0) { $0 + $1.duration() }
                    let netSecs = max(0, gross - breakSecs)
                    
                    HStack {
                        Text("Net Office Hours")
                        Spacer()
                        Text(String(format: "%.2f hrs", netSecs / 3600.0))
                            .bold()
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle(editingSessionId == nil ? "New Work Log" : "Edit Work Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSession()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddBreak) {
                AddBreakSheet { newBreak in
                    breaks.append(newBreak)
                }
            }
        }
    }
    
    private func saveSession() {
        let session = WorkSession(
            id: editingSessionId ?? UUID(),
            clockInTime: clockInDate,
            clockOutTime: isOngoing ? nil : clockOutDate,
            breaks: breaks,
            isAutoLogged: false,
            locationId: nil,
            notes: notes
        )
        
        if editingSessionId != nil {
            viewModel.updateSession(session)
        } else {
            viewModel.addManualSession(session)
        }
    }
}

public struct AddBreakSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (BreakSession) -> Void
    
    @State private var category: BreakCategory = .coffee
    @State private var startTime: Date = Date().addingTimeInterval(-1800)
    @State private var endTime: Date = Date()
    @State private var note: String = ""
    
    public var body: some View {
        NavigationStack {
            Form {
                Picker("Category", selection: $category) {
                    ForEach(BreakCategory.allCases) { cat in
                        Label(cat.rawValue, systemImage: cat.iconName).tag(cat)
                    }
                }
                
                DatePicker("Break Start", selection: $startTime)
                DatePicker("Break End", selection: $endTime)
                
                TextField("Note (optional)", text: $note)
            }
            .navigationTitle("Add Break")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let newBreak = BreakSession(
                            id: UUID(),
                            startTime: startTime,
                            endTime: endTime,
                            category: category,
                            note: note
                        )
                        onAdd(newBreak)
                        dismiss()
                    }
                }
            }
        }
    }
}
