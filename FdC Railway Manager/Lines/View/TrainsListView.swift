import SwiftUI

@MainActor
struct TrainsListView: View {
    @EnvironmentObject var network: NetworkModel
    @EnvironmentObject var manager: LinesManager
    @EnvironmentObject var appState: AppState
    
    @Binding var selectedTrains: Set<UUID>
    @State private var showAddTrain = false
    @State private var customTrainRoute: TrainRoute? = nil
    @State private var showScheduleForRoute: TrainRoute? = nil

    // AI State
    @State private var suggestingForRoute: TrainRoute? = nil
    @State private var aiSuggestion: String? = nil
    @State private var isAiLoading = false
    
    struct ScheduleRequest: Identifiable {
        let id = UUID()
        let route: TrainRoute
        let mode: ScheduleMode
    }
    @State private var activeScheduleRequest: ScheduleRequest? = nil
    
    var body: some View {
        listContent
            .navigationTitle("schedule_management".localized)
            .toolbar { toolbarContent }
            .sheet(item: $activeScheduleRequest) { scheduleCreationSheet(for: $0) }
            .sheet(item: $customTrainRoute) { trainCreationSheet(for: $0) }
            .fullScreenCover(item: $showScheduleForRoute) { scheduleViewCover(for: $0) }
            .alert("ai_suggestion_alert".localized, isPresented: aiAlertBinding) {
                Button("ok".localized, role: .cancel) { }
            } message: {
                Text(aiSuggestion ?? "")
            }
    }
    
    private var listContent: some View {
        List {
            ForEach(manager.sortedRoutes) { route in
                RouteSectionView(
                    route: route,
                    manager: manager,
                    selectedTrains: $selectedTrains,
                    onShowSchedule: { showScheduleForRoute = $0 },
                    onAddTrain: { route, mode in
                        activeScheduleRequest = ScheduleRequest(route: route, mode: mode)
                    }
                )
            }
            
            unassignedSection
        }
    }
    
    private var unassignedSection: some View {
        Section("unassigned_trains".localized) {
            let unassigned = manager.trains.filter { $0.routeId == nil }
            ForEach(unassigned) { train in
                TrainRow(
                    train: train,
                    selectedIds: selectedTrains,
                    onSelectTrain: { t in selectedTrains = [t.id] },
                    onToggleSelection: { t in
                        if selectedTrains.contains(t.id) { selectedTrains.remove(t.id) }
                        else { selectedTrains.insert(t.id) }
                    }
                )
            }
            .onDelete { idx in
                let toDel = idx.map { unassigned[$0] }
                manager.trains.removeAll { t in toDel.contains(where: { $0.id == t.id }) }
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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
    
    private func scheduleCreationSheet(for req: ScheduleRequest) -> some View {
        ScheduleCreationView(route: req.route, initialMode: req.mode)
            .environmentObject(network)
            .environmentObject(manager)
            .environmentObject(appState)
    }
    
    private func trainCreationSheet(for route: TrainRoute) -> some View {
        TrainCreationView(route: route)
    }
    
    private func scheduleViewCover(for route: TrainRoute) -> some View {
        NavigationStack {
            LineScheduleView(line: route)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("close".localized) {
                            showScheduleForRoute = nil
                        }
                    }
                }
        }
    }
    
    private var aiAlertBinding: Binding<Bool> {
        Binding(get: { aiSuggestion != nil }, set: { if !$0 { aiSuggestion = nil } })
    }
}

// Helpers
struct LineHeader: View {
    let line: TrainRoute
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
    
    @EnvironmentObject var manager: LinesManager
    
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
                    HStack(spacing: 6) {
                        if let dep = train.departureTime {
                            Text("Partenza: \(formatTime(dep))").font(.caption2).foregroundColor(.secondary)
                        }
                        if let vId = train.vehicleId, let v = manager.vehicles.first(where: { $0.id == vId }) {
                            Text(v.name)
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.purple.opacity(0.1))
                                .foregroundColor(.purple)
                                .cornerRadius(3)
                        }
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
