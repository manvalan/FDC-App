import SwiftUI

struct LineDetailView: View {
    @Binding var line: RailwayLine
    @EnvironmentObject var network: NetworkModel
    @EnvironmentObject var appState: AppState
    @Binding var isMoveModeEnabled: Bool
    @Binding var selectedNode: Node?
    @Binding var selectedEdgeId: String?
    
    @State private var showScheduleCreator = false
    
    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: line.color ?? "") ?? .black },
            set: { if let hex = $0.toHex() { line.color = hex } }
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Identification
                VStack(alignment: .leading, spacing: 8) {
                    Text("identification".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    TextField("line_name_placeholder".localized, text: $line.name)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Text("color_label".localized)
                        Spacer()
                        ColorPicker("", selection: colorBinding)
                            .labelsHidden()
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // 2. Numbering
                VStack(alignment: .leading, spacing: 8) {
                    Text("train_numbering".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("prefix".localized).font(.caption2)
                            TextField("RE", text: Binding(
                                get: { line.codePrefix ?? "" },
                                set: { line.codePrefix = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("code".localized).font(.caption2)
                            TextField("5", value: Binding(
                                get: { line.numberPrefix ?? 0 },
                                set: { line.numberPrefix = $0 == 0 ? nil : $0 }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                        }
                    }
                    
                    Text(String(format: "numbering_example".localized, line.codePrefix ?? "RE", line.numberPrefix ?? 5))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // 3. Diagram
                VStack(alignment: .leading, spacing: 12) {
                    Text("vertical_diagram".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    VerticalTrackDiagramView(
                        line: $line,
                        network: network,
                        isMoveModeEnabled: $isMoveModeEnabled,
                        externalSelectedStationID: Binding(
                            get: { selectedNode?.id },
                            set: { id in
                                if let id = id {
                                    selectedNode = network.nodes.first(where: { $0.id == id })
                                } else {
                                    selectedNode = nil
                                }
                            }
                        ),
                        externalSelectedEdgeID: $selectedEdgeId
                    )
                    .frame(minHeight: 400)
                    .cornerRadius(8)
                }
                
                // 4. Dwell Times & Tracks
                VStack(alignment: .leading, spacing: 12) {
                    Text("tracks_dwells".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    ForEach($line.stops) { $stop in
                        HStack {
                            Text(stopName(stop.stationId))
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 120, alignment: .leading)
                            
                            TextField("track_label_short".localized, text: Binding(
                                get: { stop.track ?? "" },
                                set: { stop.track = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            
                            Spacer()
                            
                            Stepper(String(format: "dwell_time_min".localized, stop.minDwellTime), value: $stop.minDwellTime, in: 0...120)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // 5. Actions
                Button(action: { showScheduleCreator = true }) {
                    HStack {
                        Image(systemName: "clock.badge.checkmark")
                        Text("generate_schedule".localized)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.top, 10)
            }
            .padding()
            .disabled(!appState.isInspectorEditingMode)
        }
        .onLongPressGesture(minimumDuration: 1.0) {
            appState.isInspectorEditingMode.toggle()
        }
        .sheet(isPresented: $showScheduleCreator) {
            ScheduleCreationView(line: line)
        }
    }
     
     private func stopName(_ id: String) -> String {
         network.nodes.first(where: { $0.id == id })?.name ?? id
     }
}
