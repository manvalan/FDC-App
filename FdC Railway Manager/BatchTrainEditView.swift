import SwiftUI

struct BatchTrainEditView: View {
    let selectedIds: Set<UUID>
    @EnvironmentObject var manager: TrainManager
    @EnvironmentObject var network: RailwayNetwork
    
    @State private var timeShiftMinutes: Int = 0
    @State private var showingDeleteConfirmation = false
    
    var selectedTrains: [Train] {
        manager.trains.filter { selectedIds.contains($0.id) }
    }
    
    var body: some View {
        Form {
            Section(header: Text("Selezione")) {
                Text("\(selectedTrains.count) treni selezionati")
                ForEach(selectedTrains.prefix(5)) { train in
                    Text(train.name).font(.caption).foregroundColor(.secondary)
                }
                if selectedTrains.count > 5 {
                    Text("+ altri \(selectedTrains.count - 5)").font(.caption).italic()
                }
            }
            
            Section(header: Text("Azioni Rapide")) {
                Stepper("Sposta Orario: \(timeShiftMinutes > 0 ? "+" : "")\(timeShiftMinutes) min", value: $timeShiftMinutes, step: 5)
                
                Button("Applica Spostamento") {
                    shiftTimes()
                }
                .disabled(timeShiftMinutes == 0)
                
                Button("Elimina Selezionati", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .navigationTitle("Modifica Multipla")
        .alert("Elimina Treni", isPresented: $showingDeleteConfirmation) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                deleteSelected()
            }
        } message: {
            Text("Sei sicuro di voler eliminare \(selectedTrains.count) treni? L'azione non è reversibile.")
        }
    }
    
    private func shiftTimes() {
        for i in manager.trains.indices {
            if selectedIds.contains(manager.trains[i].id) {
                if let current = manager.trains[i].departureTime {
                    manager.trains[i].departureTime = Calendar.current.date(byAdding: .minute, value: timeShiftMinutes, to: current)
                }
            }
        }
        timeShiftMinutes = 0
    }
    
    private func deleteSelected() {
        manager.trains.removeAll { selectedIds.contains($0.id) }
        // Selection clearing should be handled by parent or bindings, 
        // but since selectedIds is a let here, the parent view needs to react to changes 
        // or we need a binding. 
        // Ideally we should pass Binding<Set<UUID>>? 
        // For now, ContentView's onChange will handle invalidation if we remove them from manager.
    }
}
