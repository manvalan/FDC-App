import SwiftUI

struct StationEditView: View {
    @Binding var station: Node
    @Binding var isMoveModeEnabled: Bool
    @EnvironmentObject var network: RailwayNetwork
    @Environment(\.dismiss) var dismiss
    
    var onDelete: (() -> Void)? = nil
    @State private var showDeleteConfirmation = false
    @State private var initialStation: Node? // For Undo logic
    
    private var availableHubs: [Node] {
        network.nodes.filter { $0.id != station.id }.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "building.2.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text(station.name)
                            .font(.title)
                            .fontWeight(.bold)
                        Text("edit_station".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // Station Data
                VStack(alignment: .leading, spacing: 8) {
                    Text("station_data".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    TextField("station_name".localized, text: $station.name)
                        .textFieldStyle(.roundedBorder)
                    
                    Picker("functional_type".localized, selection: $station.type) {
                        Text("standard_station".localized).tag(Node.NodeType.station)
                        Text("interchange".localized).tag(Node.NodeType.interchange)
                        Text("depot".localized).tag(Node.NodeType.depot)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: station.type) { newValue in
                        station.visualType = station.defaultVisualType
                        station.customColor = station.defaultColor
                    }
                    
                    Stepper(value: Binding(
                        get: { station.platforms ?? 2 },
                        set: { station.platforms = $0 }
                    ), in: 1...20) {
                        HStack {
                            Text("platform_count".localized)
                            Spacer()
                            Text("\(station.platforms ?? 2)")
                                .foregroundColor(.secondary)
                                .fontWeight(.bold)
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // Hubs
                VStack(alignment: .leading, spacing: 8) {
                    Text("hubs_interchanges".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    Picker("belongs_to_hub".localized, selection: $station.parentHubId) {
                        Text("no_hub".localized).tag(String?.none)
                        Divider()
                        ForEach(availableHubs) { node in
                            Text(node.name).tag(String?.some(node.id))
                        }
                    }
                    .onChange(of: station.parentHubId) { newHubId in
                        station.visualType = station.defaultVisualType
                        station.customColor = station.defaultColor
                        
                        if let hubId = newHubId,
                           let parentHub = network.nodes.first(where: { $0.id == hubId }),
                           let parentLat = parentHub.latitude,
                           let parentLon = parentHub.longitude {
                            station.latitude = parentLat - 0.01
                            station.longitude = parentLon - 0.01
                        }
                    }
                    
                    if station.parentHubId != nil {
                        Picker("hub_position".localized, selection: $station.hubOffsetDirection) {
                            Text("hub_standard_pos".localized).tag(Node.HubOffsetDirection?.none)
                            ForEach(Node.HubOffsetDirection.allCases) { dir in
                                Text(dir.localizedName).tag(Node.HubOffsetDirection?.some(dir))
                            }
                        }
                        
                        Text("hub_logic_description".localized)
                            .font(.caption).foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // Visual Style
                VStack(alignment: .leading, spacing: 8) {
                    Text("visual_style".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    Picker("type".localized, selection: $station.visualType) {
                        ForEach(Node.StationVisualType.allCases) { type in
                            symbolImage(for: type).tag(Node.StationVisualType?.some(type))
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Text("custom_color".localized)
                        Spacer()
                        ColorPicker("", selection: Binding<Color>(
                            get: { Color(hex: station.customColor ?? station.defaultColor) ?? .black },
                            set: { if let hex = $0.toHex() { station.customColor = hex } }
                        ))
                        .labelsHidden()
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // Coordinates
                VStack(alignment: .leading, spacing: 8) {
                    Text("coordinates".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("latitude".localized)
                        Spacer()
                        TextField("latitude".localized, value: Binding<Double>(
                            get: { station.latitude ?? 0.0 },
                            set: { station.latitude = $0 }
                        ), format: .number.precision(.fractionLength(6)))
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            .disabled(!isMoveModeEnabled)
                            .frame(width: 150)
                    }
                    
                    HStack {
                        Text("longitude".localized)
                        Spacer()
                        TextField("longitude".localized, value: Binding<Double>(
                            get: { station.longitude ?? 0.0 },
                            set: { station.longitude = $0 }
                        ), format: .number.precision(.fractionLength(6)))
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            .disabled(!isMoveModeEnabled)
                            .frame(width: 150)
                    }
                    
                    Toggle(isOn: $isMoveModeEnabled) {
                        Label("move_mode".localized, systemImage: isMoveModeEnabled ? "hand.draw.fill" : "hand.draw")
                            .font(.headline)
                    }
                    .tint(.blue)
                    
                    Text(isMoveModeEnabled ? "move_mode_on".localized : "move_mode_off".localized)
                        .font(.caption)
                        .foregroundColor(isMoveModeEnabled ? .blue : .secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // Delete
                if let onDelete = onDelete {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("delete_station".localized)
                            Spacer()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            if initialStation == nil {
                initialStation = station
            }
        }
        .alert("delete_station".localized, isPresented: $showDeleteConfirmation) {
            Button("cancel".localized, role: .cancel) { }
            Button("delete".localized, role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("delete_confirm".localized)
        }
    }
    
    @ViewBuilder
    private func symbolImage(for type: Node.StationVisualType) -> some View {
        switch type {
        case .filledStar: Image(systemName: "star.fill")
        case .filledSquare: Image(systemName: "square.fill")
        case .emptySquare: Image(systemName: "square")
        case .filledCircle: Image(systemName: "circle.fill")
        case .emptyCircle: Image(systemName: "circle")
        }
    }
}

// Helper for Color serialization
extension Color {
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        if components.count >= 4 {
            a = Float(components[3])
        }
        
        if a != 1.0 {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}
