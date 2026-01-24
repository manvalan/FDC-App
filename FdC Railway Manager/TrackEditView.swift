import SwiftUI

struct TrackEditView: View {
    @Binding var edge: Edge
    var onDelete: () -> Void // Callback for deletion
    
    @Environment(\.dismiss) var dismiss // Still useful if we want to close inspector programmatically context-aware
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        Form {
            Section("Proprietà Binario") {
                HStack {
                    Text("Distanza (km)")
                    Spacer()
                    TextField("Distanza", value: $edge.distance, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                }
                
                HStack {
                    Text("Velocità Max (km/h)")
                    Spacer()
                    TextField("Velocità", value: $edge.maxSpeed, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
                
                Picker("Tipo Binario", selection: $edge.trackType) {
                    Text("Binario Singolo").tag(Edge.TrackType.single)
                    Text("Doppio Binario").tag(Edge.TrackType.double)
                    Text("Alta Velocità").tag(Edge.TrackType.highSpeed)
                    Text("Regionale").tag(Edge.TrackType.regional)
                }
                .onChange(of: edge.trackType) { newType in
                    // Update default capacity based on track type
                    switch newType {
                    case .single: edge.capacity = 6
                    case .double: edge.capacity = 24
                    case .highSpeed: edge.capacity = 15
                    case .regional: edge.capacity = 10
                    }
                }
            }
            
            Section("Capacità") {
                HStack {
                    Text("Capacità (treni/h)")
                    Spacer()
                    TextField("Capacità", value: $edge.capacity, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Elimina Binario")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Modifica Binario")
        .alert("Elimina Binario", isPresented: $showDeleteConfirmation) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Sei sicuro di voler eliminare questo binario? L'azione non può essere annullata.")
        }
    }
}
