import SwiftUI

@MainActor
struct TrainsListView: View {
    @EnvironmentObject var network: NetworkModel
    @EnvironmentObject var manager: LinesManager
    @EnvironmentObject var appState: AppState
    
    @Binding var selectedTrains: Set<UUID>
    @State private var showAddTrain = false
    @State private var customTrainLine: RailwayLine? = nil
    @State private var showScheduleForLine: RailwayLine? = nil

    // AI State
    @State private var suggestingForLine: RailwayLine? = nil
    @State private var aiSuggestion: String? = nil
    @State private var isAiLoading = false
    
    struct ScheduleRequest: Identifiable {
        let id = UUID()
        let line: RailwayLine
        let mode: ScheduleCreationView.ScheduleMode
    }
    @State private var activeScheduleRequest: ScheduleRequest? = nil
    
    var body: some View {
        List {
            ForEach(manager.sortedLines) { line in
                LineSectionView(
                    line: line,
                    manager: manager,
                    selectedTrains: $selectedTrains,
                    onShowSchedule: { showScheduleForLine = $0 },
                    onAddTrain: { line, mode in
                        activeScheduleRequest = ScheduleRequest(line: line, mode: mode)
                    }
                )
            }
            
            Section("unassigned_trains".localized) {
                let unassigned = manager.trains.filter { $0.lineId == nil }
                ForEach(unassigned) { train in
                    Button(action: {
                        selectedTrains = [train.id]
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                            Text(train.name)
                            Spacer()
                            Text(train.type.localized).font(.caption)
                        }
                        .background(selectedTrains.contains(train.id) ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { idx in
                    let toDel = idx.map { unassigned[$0] }
                    manager.trains.removeAll { t in toDel.contains(where: { $0.id == t.id }) }
                }
            }
        }
        .navigationTitle("schedule_management".localized)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    manager.trains.removeAll()
                    appState.simulator.schedules.removeAll()
                    selectedTrains.removeAll()
                }) {
                    Label("delete_all_trains".localized, systemImage: "trash.fill")
                }
                .foregroundColor(.red)
                .help("delete_all_trains_help".localized)
            }
        }
        .sheet(item: $activeScheduleRequest) { req in
            ScheduleCreationView(line: req.line, initialMode: req.mode)
                .environmentObject(network)
                .environmentObject(manager)
                .environmentObject(appState)
        }
        .sheet(item: $customTrainLine) { line in
            TrainCreationView(line: line)
        }
        .fullScreenCover(item: $showScheduleForLine) { line in
            NavigationStack {
                LineScheduleView(line: line)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("close".localized) {
                                showScheduleForLine = nil
                            }
                        }
                    }
            }
        }
        .alert("ai_suggestion_alert".localized, isPresented: Binding(get: { aiSuggestion != nil }, set: { if !$0 { aiSuggestion = nil } })) {
            Button("ok".localized, role: .cancel) { }
        } message: {
            Text(aiSuggestion ?? "")
        }
    }
}

// Helpers
struct LineHeader: View {
    let line: RailwayLine
    let onAddTrain: () -> Void
    let onAddTrainCadenced: () -> Void
    let onShowSchedule: () -> Void
    
    var body: some View {
        HStack {
            if let c = line.color {
                Circle().fill(Color(hex: c) ?? .black).frame(width: 10, height: 10)
            }
            Text(line.name).font(.headline)
            Spacer()
            
            Button(action: onShowSchedule) {
                Label("Orario Grafico", systemImage: "chart.xyaxis.line")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            
            Menu {
                Button(action: onAddTrain) {
                    Label("Nuova Corsa Singola", systemImage: "train.side.front.car")
                }
                Button(action: onAddTrainCadenced) {
                    Label("Genera Orario Cadenzato", systemImage: "calendar.badge.plus")
                }
            } label: {
                Image(systemName: "plus.circle")
                    .foregroundColor(.accentColor)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
        }
    }
}

struct TrainRow: View {
    let train: Train
    let selectedIds: Set<UUID>
    let onSelectTrain: (Train) -> Void
    let onToggleSelection: (Train) -> Void
    
    var body: some View {
        Button(action: { onSelectTrain(train) }) {
            HStack {
                Image(systemName: selectedIds.contains(train.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedIds.contains(train.id) ? .blue : .secondary)
                    .onTapGesture { onToggleSelection(train) }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("\(train.number ?? 0)").font(.subheadline).bold().foregroundColor(.blue)
                        Text(train.name).font(.subheadline)
                    }
                    if let dep = train.departureTime {
                        Text("Partenza: \(formatTime(dep))").font(.caption2).foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text(train.type).font(.caption2).padding(4).background(Color.blue.opacity(0.1)).cornerRadius(4)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.string(from: date)
    }
}
