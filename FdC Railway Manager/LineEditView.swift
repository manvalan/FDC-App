import SwiftUI

struct LineEditView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = LineEditViewModel()
    @Environment(\.dismiss) var dismiss
    
    let lineId: String
    
    // UI-only navigation state
    @State private var manualAddition: Bool = true
    @State private var manualStationId: String = ""
    @State private var activePicker: PickerType?
    @State private var mapPickingType: PickerType?
    
    var body: some View {
        Form {
            detailsSection
                
                Section(header: Text("path_composition".localized)) {
                    PathPickerComponent(
                        startStationId: $vm.startStationId,
                        viaStationIds: $vm.viaStationIds,
                        endStationId: $vm.endStationId,
                        stationSequence: $vm.stationSequence,
                        manualAddition: $manualAddition,
                        activePicker: $activePicker,
                        manualStationId: $manualStationId,
                        lineAnalysis: vm.lineAnalysis,
                        isAnalyzing: vm.isAnalyzingLine
                    )
                }
                
                if !vm.stationSequence.isEmpty || manualAddition {
                    StationSequenceSection(
                        stationSequence: $vm.stationSequence,
                        lineColor: vm.lineColor,
                        network: appState.railroad.network,
                        activePicker: $activePicker,
                        mapPickingType: $mapPickingType,
                        suggestions: vm.getSuggestions()
                    )
                }
                
                vehicleAssignmentSection
                
                if let error = vm.errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !vm.stationSequence.isEmpty {
                    suggestionsOverlay
                }
            }
            .navigationTitle("Dettagli Linea")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save".localized) {
                        if vm.saveChanges() {
                            dismiss()
                        }
                    }
                    .disabled(vm.lineName.isEmpty || vm.stationSequence.count < 2)
                }
            }
            .onAppear {
                vm.setup(lineId: lineId, appState: appState)
            }
            .onChange(of: manualStationId) { old, new in
                if !new.isEmpty {
                    vm.stationSequence.append(new)
                    manualStationId = "" 
                }
            }
            .onChange(of: activePicker) { old, new in
                if let type = new {
                    setupPickingCallback(for: type)
                } else if mapPickingType == nil {
                    appState.stationPickingCallback = nil
                }
            }
            .onChange(of: mapPickingType) { old, new in
                if let type = new {
                    setupPickingCallback(for: type)
                } else if activePicker == nil {
                    appState.stationPickingCallback = nil
                }
            }
            .onDisappear {
                appState.stationPickingCallback = nil
            }
            .sheet(item: $activePicker) { item in
                Group {
                    switch item {
                    case .start:
                        StationPickerView(selectedStationId: $vm.startStationId)
                    case .via(let idx):
                        if idx >= 0 && idx < vm.viaStationIds.count {
                            StationPickerView(selectedStationId: Binding(
                                get: { vm.viaStationIds[idx] },
                                set: { vm.viaStationIds[idx] = $0 }
                            ))
                        } else {
                            VStack {
                                Text(String(format: "error_index_not_found_fmt".localized, idx))
                                Button("close".localized) { activePicker = nil }
                            }
                            .padding()
                        }
                    case .end:
                        StationPickerView(selectedStationId: $vm.endStationId)
                    case .manual:
                        StationPickerView(selectedStationId: $manualStationId, linkedToStationId: vm.stationSequence.last)
                    }
                }
                .environmentObject(appState.railroad.network)
            }
    }
    
    private var detailsSection: some View {
        Section(header: Text("line_details".localized)) {
            TextField("line_name_placeholder".localized, text: $vm.lineName)
            
            if appState.currentMode != .design {
                TextField("code_prefix_placeholder".localized, text: $vm.codePrefix)
                TextField("number_prefix_placeholder".localized, value: $vm.numberPrefix, format: .number)
                    .keyboardType(.numberPad)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("cadence_frequency".localized)
                        Spacer()
                        TextField("minutes", value: $vm.cadenceFrequency, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Button(action: { vm.findIdealOffset() }) {
                            Label(vm.isRunningOptimizer ? "finding_slot".localized : "propose_ideal_slot".localized, 
                                  systemImage: "wand.and.stars")
                        }
                        .disabled(vm.isRunningOptimizer || vm.stationSequence.count < 2)
                        
                        if let offset = vm.proposedOffset {
                            Spacer()
                            Text(String(format: "suggested_offset_fmt".localized, Int(offset)))
                                .foregroundColor(.green)
                                .font(.caption.bold())
                        }
                    }
                }
            }
            ColorPicker("Colore Linea", selection: $vm.lineColor, supportsOpacity: false)
                
            Section(header: Text("capolinea_e_binari".localized)) {
                if let startNode = appState.railroad.network.nodes.first(where: { $0.id == vm.stationSequence.first }) {
                    HStack {
                        Text("Origine: \(startNode.name)")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { vm.terminalTracks[startNode.id] ?? "" },
                            set: { vm.terminalTracks[startNode.id] = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("-").tag("")
                            ForEach(1...(startNode.platforms ?? 2), id: \.self) { p in
                                Text("\(p)").tag("\(p)")
                            }
                        }
                    }
                }
                
                if let endNode = appState.railroad.network.nodes.first(where: { $0.id == vm.stationSequence.last }), endNode.id != vm.stationSequence.first {
                    HStack {
                        Text("Destinazione: \(endNode.name)")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { vm.terminalTracks[endNode.id] ?? "" },
                            set: { vm.terminalTracks[endNode.id] = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("-").tag("")
                            ForEach(1...(endNode.platforms ?? 2), id: \.self) { p in
                                Text("\(p)").tag("\(p)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var vehicleAssignmentSection: some View {
        Section(header: Text("materiale_rotabile".localized)) {
            Button(action: {
                vm.lines.autoAssignRollingStock(for: lineId)
            }) {
                Label("Ottimizza Assegnazione Mezzi", systemImage: "sparkles.rectangle.stack")
            }
            
            Text("Assegna i turni macchina minimizzando il materiale rotabile e bilanciando il numero di corse (preferendo turni pari).")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            let assignedVehicleIds = Set(vm.lines.trains.filter { $0.lineId == lineId }.compactMap { $0.vehicleId })
            let assignedVehicles = vm.lines.vehicles.filter { assignedVehicleIds.contains($0.id) }
            
            if !assignedVehicles.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Mezzi Attualmente Assegnati:").font(.caption.bold())
                
                ForEach(assignedVehicles) { vehicle in
                    let count = vm.lines.trains.filter { $0.lineId == lineId && $0.vehicleId == vehicle.id }.count
                    HStack {
                        Image(systemName: "train.side.front.car")
                            .foregroundColor(.purple)
                        VStack(alignment: .leading) {
                            Text(vehicle.name).font(.subheadline)
                            Text(vehicle.model).font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(count) corse")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(count % 2 == 0 ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                            .foregroundColor(count % 2 == 0 ? .green : .orange)
                            .cornerRadius(8)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    private var suggestionsOverlay: some View {
        let suggestions = vm.getSuggestions()
        return Group {
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Consigliate (Tocca per aggiungere):")
                        .font(.caption2.bold())
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(suggestions) { node in
                                Button(action: {
                                    withAnimation(.spring()) {
                                        vm.stationSequence.append(node.id)
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus.circle.fill")
                                        Text(node.name)
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                                    .shadow(color: .black.opacity(0.1), radius: 3)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .overlay(Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.2)), alignment: .top)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private func setupPickingCallback(for type: PickerType) {
        appState.stationPickingCallback = { stationId in
            vm.handleStationSelection(type: type, stationId: stationId)
            
            // Auto-close terminals/via, keep manual sequence open
            if case .manual = type {
                // Keep it open for series of clicks
            } else {
                activePicker = nil
                mapPickingType = nil
            }
        }
    }
}
