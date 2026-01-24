import SwiftUI

struct StationEditView: View {
    @Binding var station: Node
    @Environment(\.dismiss) var dismiss
    
    // We bind to a local copy to allow cancellation, or bind directly if "live edit" is preferred.
    // Given the request for "live update" or simple edit, direct binding is easiest, 
    // but a local state + save is safer. Let's do direct for "real-time" feel on colors, 
    // but usually Sheet needs a button to commit or is just a detail view.
    // The previous StationBoardView was just a board.
    // Let's make this a real editor.
    
    // Direct binding for live updates
    // Remove local state to avoid sync issues
    
    var onDelete: (() -> Void)? = nil
    @State private var showDeleteConfirmation = false
    
    // Direct binding for live updates
    // Remove local state to avoid sync issues
    
    var body: some View {
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
                    station.visualType = defaultVisualType(for: newValue)
                    let newColor = defaultColor(for: newValue)
                    if let hex = newColor.toHex() {
                        station.customColor = hex
                    }
                }
            }
            
            Section("Aspetto Grafico") {
                // Custom Binding for Visual Type to handle Optional
                let visualTypeBinding = Binding<Node.StationVisualType>(
                    get: { station.visualType ?? defaultVisualType(for: station.type) },
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
                    get: { Color(hex: station.customColor ?? "") ?? .black },
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
    
    
    private func defaultVisualType(for type: Node.NodeType) -> Node.StationVisualType {
        switch type {
        case .interchange: return .filledSquare
        case .depot: return .filledSquare
        default: return .filledCircle
        }
    }
    
    private func defaultColor(for type: Node.NodeType) -> Color {
        switch type {
        case .interchange: return .red
        case .depot: return .orange
        default: return .black
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
