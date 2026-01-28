import SwiftUI

struct StationEditView: View {
    @Binding var station: Node
    @EnvironmentObject var network: RailwayNetwork
    @Environment(\.dismiss) var dismiss
    
    var onDelete: (() -> Void)? = nil
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        let availableHubs = network.nodes
            .filter { $0.id != station.id }
            .sorted(by: { $0.name < $1.name })
        
        Form {
            Section("Anagrafica") {
                TextField("Nome Stazione", text: $station.name)
                Picker("Tipo Funzionale", selection: $station.type) {
                    Text("Stazione Standard").tag(Node.NodeType.station)
                    Text("Interscambio").tag(Node.NodeType.interchange)
                    Text("Deposito").tag(Node.NodeType.depot)
                }
                .onChange(of: station.type) { newValue in
                    // Auto-update visual style when functional type changes
                    station.visualType = station.defaultVisualType
                    station.customColor = station.defaultColor
                }
            }
            
            Section("Hub e Interscambi") {
                Picker("Appartiene a HUB", selection: $station.parentHubId) {
                    Text("Nessun HUB (Indipendente)").tag(String?.none)
                    Divider()
                    ForEach(availableHubs) { node in
                        Text(node.name).tag(String?.some(node.id))
                    }
                }
                .onChange(of: station.parentHubId) { newHubId in
                    // Auto-apply interchange look if it's part of a hub
                    station.visualType = station.defaultVisualType
                    station.customColor = station.defaultColor
                    
                    // Auto-position near parent hub
                    if let hubId = newHubId,
                       let parentHub = network.nodes.first(where: { $0.id == hubId }),
                       let parentLat = parentHub.latitude,
                       let parentLon = parentHub.longitude {
                        // Position at bottom-left (like lower-left vertex of a square)
                        station.latitude = parentLat - 0.01  // ~1km south
                        station.longitude = parentLon - 0.01 // ~1km west
                    }
                }
                
                if station.parentHubId != nil {
                    Text("Questa stazione è legata logicamente a un'altra. Verrà trattata come punto di interscambio rapido.")
                        .font(.caption).foregroundColor(.blue)
                }
            }
            
            Section("Aspetto Grafico") {
                // Custom Binding for Visual Type to handle Optional
                let visualTypeBinding = Binding<Node.StationVisualType>(
                    get: { station.visualType ?? station.defaultVisualType },
                    set: { station.visualType = $0 }
                )
                
                Picker("Simbolo", selection: visualTypeBinding) {
                    ForEach(Node.StationVisualType.allCases) { type in
                        HStack {
                            symbolImage(for: type)
                            Text(type.rawValue)
                        }
                        .tag(type)
                    }
                }
                .pickerStyle(.menu) // Safer than navigationLink in sheet
                
                // Custom Binding for Color
                let colorBinding = Binding<Color>(
                    get: { Color(hex: station.customColor ?? station.defaultColor) ?? .black },
                    set: { if let hex = $0.toHex() { station.customColor = hex } }
                )
                ColorPicker("Colore Personalizzato", selection: colorBinding)
            }
            
            Section("Coordinate") {
                // Custom bindings for Optionals with default 0.0
                let latBinding = Binding<Double>(
                    get: { station.latitude ?? 0.0 },
                    set: { station.latitude = $0 }
                )
                let lonBinding = Binding<Double>(
                    get: { station.longitude ?? 0.0 },
                    set: { station.longitude = $0 }
                )
                
                HStack {
                    Text("Lat")
                    TextField("Latitudine", value: latBinding, format: .number.precision(.fractionLength(6)))
                        .keyboardType(.decimalPad)
                }
                HStack {
                    Text("Lon")
                    TextField("Longitudine", value: lonBinding, format: .number.precision(.fractionLength(6)))
                        .keyboardType(.decimalPad)
                }
                Text("Puoi modificare le coordinate manualmente qui o trascinando la stazione sulla mappa.")
                    .font(.caption).foregroundColor(.secondary)
            }
            
            if let onDelete = onDelete {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Elimina Stazione")
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Modifica Stazione")
        .alert("Elimina Stazione", isPresented: $showDeleteConfirmation) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Sei sicuro di voler eliminare questa stazione? L'azione non può essere annullata.")
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
