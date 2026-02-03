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
            Section(header: Text("selection".localized)) {
                Text(String(format: "trains_selected_count".localized, selectedTrains.count))
                ForEach(selectedTrains.prefix(5)) { train in
                    Text(train.name).font(.caption).foregroundColor(.secondary)
                }
                if selectedTrains.count > 5 {
                    Text(String(format: "plus_others_count".localized, selectedTrains.count - 5)).font(.caption).italic()
                }
            }
            
            Section(header: Text("quick_actions".localized)) {
                Stepper(String(format: "shift_time_minutes".localized, timeShiftMinutes > 0 ? "+" : "", timeShiftMinutes), value: $timeShiftMinutes, step: 5)
                
                Button("apply_shift".localized) {
                    shiftTimes()
                }
                .disabled(timeShiftMinutes == 0)
                
                Button("delete_selected".localized, role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .navigationTitle("batch_edit".localized)
        .alert("delete_trains".localized, isPresented: $showingDeleteConfirmation) {
            Button("cancel".localized, role: .cancel) { }
            Button("delete".localized, role: .destructive) {
                deleteSelected()
            }
        } message: {
            Text(String(format: "delete_trains_confirm".localized, selectedTrains.count))
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
