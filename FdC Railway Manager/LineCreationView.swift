import SwiftUI

struct LineCreationView: View {
    @EnvironmentObject var network: RailwayNetwork
    @Environment(\.dismiss) var dismiss
    
    @State private var lineName: String = ""
    @State private var codePrefix: String = "" // New
    @State private var numberPrefix: Int = 0 // New
    @State private var lineColor: Color = .blue
    
    // Controlled by PathPickerComponent
    @State private var startStationId: String = ""
    @State private var viaStationIds: [String] = []
    @State private var endStationId: String = ""
    @State private var stationSequence: [String] = []
    @State private var manualAddition: Bool = false
    
    @State private var manualStationId: String = ""
    @State private var activePicker: PickerType?
    
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                
                Section(header: Text("path_composition".localized)) {
                    PathPickerComponent(
                        startStationId: $startStationId,
                        viaStationIds: $viaStationIds,
                        endStationId: $endStationId,
                        stationSequence: $stationSequence,
                        manualAddition: $manualAddition,
                        activePicker: $activePicker,
                        manualStationId: $manualStationId
                    )
                }
                
                if !stationSequence.isEmpty {
                    StationSequenceSection(
                        stationSequence: $stationSequence,
                        lineColor: lineColor,
                        network: network,
                        activePicker: $activePicker,
                        suggestions: getSuggestions()
                    )
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("new_line".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save".localized) {
                        saveLine()
                    }
                    .disabled(lineName.isEmpty || stationSequence.count < 2)
                }
            }
            .onChange(of: startStationId) { old, new in
                if !new.isEmpty {
                    if stationSequence.isEmpty || !manualAddition {
                        stationSequence = [new]
                    }
                }
            }
            .onChange(of: manualStationId) { old, new in
                if !new.isEmpty {
                    if !stationSequence.contains(new) {
                        stationSequence.append(new)
                    }
                    manualStationId = "" 
            }
        }
        .sheet(item: $activePicker) { item in
            Group {
                switch item {
                case .start:
                    StationPickerView(selectedStationId: $startStationId)
                case .via(let idx):
                    if idx >= 0 && idx < viaStationIds.count {
                        StationPickerView(selectedStationId: Binding(
                            get: { viaStationIds[idx] },
                            set: { viaStationIds[idx] = $0 }
                        ))
                    } else {
                        VStack {
                            Text(String(format: "error_index_not_found_fmt".localized, idx))
                            Button("close".localized) { activePicker = nil }
                        }
                        .padding()
                    }
                case .end:
                    StationPickerView(selectedStationId: $endStationId)
                case .manual:
                    StationPickerView(selectedStationId: $manualStationId, linkedToStationId: stationSequence.last)
                }
            }
            .environmentObject(network)
        }
    }
    
    
        }
    
    private var detailsSection: some View {
        Section(header: Text("line_details".localized)) {
            TextField("line_name_example".localized, text: $lineName)
            TextField("code_prefix_placeholder".localized, text: $codePrefix)
            TextField("number_prefix_example".localized, value: $numberPrefix, format: .number)
                .keyboardType(.numberPad)
            ColorPicker("line_color".localized, selection: $lineColor)
        }
    }
    
    private func saveLine() {
        let hexColor = lineColor.toHex()
        let stops = stationSequence.map { sid -> RelationStop in
            let node = network.nodes.first(where: { $0.id == sid })
            let defaultDwell = (node?.type == .interchange) ? 5 : 3
            return RelationStop(stationId: sid, minDwellTime: defaultDwell)
        }
        let newLine = RailwayLine(
            id: UUID().uuidString,
            name: lineName,
            color: hexColor,
            originId: startStationId,
            destinationId: endStationId,
            stops: stops,
            codePrefix: codePrefix.isEmpty ? nil : codePrefix,
            numberPrefix: numberPrefix == 0 ? nil : numberPrefix
        )
        network.lines.append(newLine)
        dismiss()
    }
    
    private func getSuggestions() -> [Node] {
        guard let lastId = stationSequence.last else { return [] }
        let connectedIds = network.edges.compactMap { edge -> String? in
            if edge.from == lastId { return edge.to }
            if edge.to == lastId { return edge.from }
            return nil
        }
        return network.nodes.filter { connectedIds.contains($0.id) && !stationSequence.contains($0.id) }
            .sorted { $0.name < $1.name }
    }
}
