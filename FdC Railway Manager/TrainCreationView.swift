import SwiftUI

struct TrainCreationView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    // If we are creating a train "for a line", we prefill information
    var line: RailwayLine? = nil
    
    @State private var trainNumber: Int = 0
    @State private var trainName: String = ""
    @State private var trainType: TrainCategory = .regional
    @State private var maxSpeed: Int = 140
    @State private var departureTime: Date = Date()
    
    // Path picking
    @State private var startStationId: String = ""
    @State private var viaStationIds: [String] = []
    @State private var endStationId: String = ""
    @State private var stationSequence: [String] = []
    @State private var manualAddition: Bool = false
    
    @State private var activePicker: PickerType?
    @State private var manualStationId: String = ""

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                lineOrPathSection
                stopsSection
            }
            .navigationTitle("new_trip".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("create".localized) {
                        saveTrain()
                    }
                    .disabled(stationSequence.count < 2)
                }
            }
            .onAppear(perform: prefillFromLine)
            .onChange(of: startStationId) { old, new in
                if !new.isEmpty && !manualAddition {
                    stationSequence = [new]
                }
            }
            .onChange(of: manualStationId) { old, new in
                if !new.isEmpty {
                    stationSequence.append(new)
                    manualStationId = "" // Clear for next one
                }
            }
            .sheet(item: $activePicker) { item in
                pickerSheet(for: item)
            }
        }
    }
    
    private var detailsSection: some View {
        Section(header: Text("train_details".localized)) {
            HStack {
                Text("number".localized)
                TextField("1234", value: $trainNumber, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            TextField("name_optional".localized, text: $trainName)
            
            Picker("train_type_picker".localized, selection: $trainType) {
                ForEach(TrainCategory.allCases) { cat in
                    Text(cat.localizedName).tag(cat)
                }
            }
            .onChange(of: trainType) { old, new in
                updateMaxSpeed(for: new)
            }
            
            HStack {
                Text("max_speed_label".localized)
                TextField("120", value: $maxSpeed, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                Text("km/h")
            }
            
            DatePicker("departure_picker".localized, selection: $departureTime, displayedComponents: .hourAndMinute)
        }
    }
    
    @ViewBuilder
    private var lineOrPathSection: some View {
        if let activeLine = line {
            Section(header: Text("selected_line".localized)) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(activeLine.name).font(.headline)
                        Text("\(activeLine.originId) → \(activeLine.destinationId)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "line.horizontal.3.circle.fill")
                        .foregroundColor(Color(hex: activeLine.color ?? "#000000") ?? .blue)
                }
            }
        } else {
            PathPickerComponent(
                startStationId: $startStationId,
                viaStationIds: $viaStationIds,
                endStationId: $endStationId,
                stationSequence: $stationSequence,
                manualAddition: $manualAddition,
                activePicker: $activePicker,
                manualStationId: $manualStationId,
                lineContext: line
            )
        }
    }
    
    private var stopsSection: some View {
        Section(header: Text("stop_sequence".localized)) {
            if stationSequence.isEmpty {
                Text("select_terminals_desc".localized).font(.caption).foregroundColor(.secondary)
            }
            
            ForEach(stationSequence, id: \.self) { id in
                stopRow(for: id)
            }
            .onDelete { stationSequence.remove(atOffsets: $0) }
            .onMove { stationSequence.move(fromOffsets: $0, toOffset: $1) }
            
            Button(action: { activePicker = .manual }) {
                Label("add_stop_manual".localized, systemImage: "plus.circle")
                    .foregroundColor(.green)
            }
        }
    }
    
    private func stopRow(for id: String) -> some View {
        let node = network.nodes.first(where: { $0.id == id })
        return HStack {
            Image(systemName: "smallcircle.filled.circle")
                .foregroundColor(.blue)
            Text(node?.name ?? id)
            Spacer()
            if let node = node {
                let dwell = (node.type == .interchange) ? 5 : 3
                Text(String(format: "dwell_time_min".localized, dwell)).font(.caption).foregroundColor(.secondary)
            }
        }
    }
    
    private func pickerSheet(for item: PickerType) -> some View {
        Group {
            switch item {
            case .start:
                StationPickerView(selectedStationId: $startStationId, whitelistIds: line?.stations)
            case .via(let idx):
                StationPickerView(selectedStationId: $viaStationIds[idx], whitelistIds: line?.stations)
            case .end:
                StationPickerView(selectedStationId: $endStationId, whitelistIds: line?.stations)
            case .manual:
                StationPickerView(selectedStationId: $manualStationId, linkedToStationId: stationSequence.last, whitelistIds: line?.stations)
            }
        }
        .environmentObject(network)
        .environmentObject(manager)
    }
    
    private func updateMaxSpeed(for category: TrainCategory) {
        switch category {
        case .regional:
            maxSpeed = Int(appState.regionalMaxSpeed)
        case .direct:
            maxSpeed = Int(appState.intercityMaxSpeed)
        case .highSpeed:
            maxSpeed = Int(appState.highSpeedMaxSpeed)
        case .freight:
            maxSpeed = 100
        case .support:
            maxSpeed = 80
        }
    }
    
    private func prefillFromLine() {
        if let line = line {
            startStationId = line.originId
            endStationId = line.destinationId
            stationSequence = line.stops.map { $0.stationId }
            
            // Smart Numbering with Prefixes
            let prefix = line.numberPrefix ?? 0
            let code = line.codePrefix ?? "regional_type".localized // Fallback name prefix
            
            let lineTrains = manager.trains.filter { $0.lineId == line.id }
            let existingNumbers = lineTrains.map { $0.number }
            
            // Determine base number to increment
            var nextBase = 1
            if !existingNumbers.isEmpty {
                let maxNum = existingNumbers.max() ?? 0
                let currentBase = (prefix > 0) ? (maxNum % 1000) : maxNum
                nextBase = currentBase + 1
            }
            
            let finalNum = (prefix * 1000) + nextBase
            trainNumber = finalNum
            
            // Pre-fill Name
            trainName = "\(code) \(finalNum)"
        }
    }
    
    private func saveTrain() {
        let stops = stationSequence.map { sid -> RelationStop in
            let node = network.nodes.first(where: { $0.id == sid })
            let defaultDwell = (node?.type == .interchange) ? 5 : 3
            return RelationStop(stationId: sid, minDwellTime: defaultDwell)
        }
        
        let config = getTrainConfig()
        
        let newTrain = Train(
            id: UUID(),
            number: trainNumber,
            name: trainName.isEmpty ? String(format: "train_name_default".localized, trainNumber) : trainName,
            type: trainType.rawValue,
            maxSpeed: config.maxSpeed,
            priority: config.priority,
            acceleration: config.acceleration,
            deceleration: config.deceleration,
            lineId: line?.id,
            departureTime: departureTime.normalized(),
            stops: stops
        )
        manager.trains.append(newTrain)
        dismiss()
    }
    
    private struct TrainConfig {
        let acceleration: Double
        let deceleration: Double
        let priority: Int
        let maxSpeed: Int
    }
    
    private func getTrainConfig() -> TrainConfig {
        switch trainType {
        case .regional:
            return TrainConfig(
                acceleration: appState.regionalAcceleration,
                deceleration: appState.regionalDeceleration,
                priority: Int(appState.regionalPriority),
                maxSpeed: Int(appState.regionalMaxSpeed)
            )
        case .direct:
            return TrainConfig(
                acceleration: appState.intercityAcceleration,
                deceleration: appState.intercityDeceleration,
                priority: Int(appState.intercityPriority),
                maxSpeed: Int(appState.intercityMaxSpeed)
            )
        case .highSpeed:
            return TrainConfig(
                acceleration: appState.highSpeedAcceleration,
                deceleration: appState.highSpeedDeceleration,
                priority: Int(appState.highSpeedPriority),
                maxSpeed: Int(appState.highSpeedMaxSpeed)
            )
        case .freight:
            return TrainConfig(acceleration: 0.3, deceleration: 0.3, priority: 3, maxSpeed: 100)
        case .support:
            return TrainConfig(acceleration: 0.4, deceleration: 0.4, priority: 1, maxSpeed: 80)
        }
    }
}
