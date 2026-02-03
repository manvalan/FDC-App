import SwiftUI

struct LineEditView: View {
    @EnvironmentObject var network: RailwayNetwork
    @Environment(\.dismiss) var dismiss
    
    let lineId: String
    
    @State private var lineName: String = ""
    @State private var codePrefix: String = ""
    @State private var numberPrefix: Int = 0
    @State private var lineColor: Color = .blue
    
    // Path selection state
    @State private var startStationId: String = ""
    @State private var viaStationIds: [String] = []
    @State private var endStationId: String = ""
    @State private var stationSequence: [String] = []
    @State private var manualAddition: Bool = true // Default to true for editing
    
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
            .navigationTitle("edit_line".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save".localized) {
                        saveChanges()
                    }
                    .disabled(lineName.isEmpty || stationSequence.count < 2)
                }
            }
            .onAppear {
                loadLineData()
            }
            .onChange(of: manualStationId) { old, new in
                if !new.isEmpty {
                    stationSequence.append(new)
                    manualStationId = "" 
                }
            }
        }
    }
    
    private var detailsSection: some View {
        Section(header: Text("line_details".localized)) {
            TextField("line_name_placeholder".localized, text: $lineName)
            TextField("code_prefix_placeholder".localized, text: $codePrefix)
            TextField("number_prefix_placeholder".localized, value: $numberPrefix, format: .number)
                .keyboardType(.numberPad)
            ColorPicker("line_color".localized, selection: $lineColor)
        }
    }
    
    
    private func loadLineData() {
        guard let line = network.lines.first(where: { $0.id == lineId }) else {
            dismiss()
            return
        }
        
        lineName = line.name
        codePrefix = line.codePrefix ?? ""
        numberPrefix = line.numberPrefix ?? 0
        lineColor = Color(hex: line.color ?? "") ?? .blue
        
        startStationId = line.originId
        endStationId = line.destinationId
        stationSequence = line.stops.map { $0.stationId }
        // viaStationIds is trickier since it's used for pathfinding, 
        // but for manual sequence editing we mainly care about stationSequence.
    }
    
    private func saveChanges() {
        guard let index = network.lines.firstIndex(where: { $0.id == lineId }) else { return }
        
        let hexColor = lineColor.toHex()
        let stops = stationSequence.map { sid -> RelationStop in
            let node = network.nodes.first(where: { $0.id == sid })
            let defaultDwell = (node?.type == .interchange) ? 5 : 3
            return RelationStop(stationId: sid, minDwellTime: defaultDwell)
        }
        
        // Update the existing line
        network.lines[index].name = lineName
        network.lines[index].color = hexColor
        network.lines[index].originId = startStationId
        network.lines[index].destinationId = endStationId
        network.lines[index].stops = stops
        network.lines[index].codePrefix = codePrefix.isEmpty ? nil : codePrefix
        network.lines[index].numberPrefix = numberPrefix == 0 ? nil : numberPrefix
        
        
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
