import SwiftUI
import Combine
import UniformTypeIdentifiers
import Foundation
import Charts

struct TrainsDetailView: View {
    @ObservedObject var manager: LinesManager
    @State private var showAdd = false
    @State private var newName = ""
    @State private var newType = "Regionale"
    @State private var newMaxSpeed = 120
    var body: some View {
        NavigationStack {
            List {
                ForEach(manager.trains) { train in
                    VStack(alignment: .leading) {
                        Text(train.name).font(.headline)
                        Text(String(format: "type_speed_label".localized, train.type, train.maxSpeed)).font(.caption)
                    }
                }
                .onDelete { manager.trains.remove(atOffsets: $0) }
            }
            .navigationTitle("manage_trains_title".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAdd = true }) {
                        Label("add_train".localized, systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                NavigationStack {
                    Form {
                        TextField("train_name".localized, text: $newName)
                        TextField("type_label".localized, text: $newType)
                        TextField("max_speed_kmh".localized, value: $newMaxSpeed, format: .number)
                    }
                    .navigationTitle("new_train".localized)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("cancel".localized) { showAdd = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("add_button".localized) {
                                guard !newName.isEmpty else { return }
                                 manager.trains.append(Train(
                                    id: UUID(), 
                                    number: 100 + manager.trains.count, 
                                    name: newName, 
                                    type: newType, 
                                    lineId: nil,
                                    departureTime: nil,
                                    stops: [],
                                    vehicleId: nil,
                                    maxSpeed: Double(newMaxSpeed), 
                                    acceleration: 0.5, 
                                    deceleration: 0.5, 
                                    priority: 5
                                 ))
                                 newName = ""
                                newType = "Regionale"
                                newMaxSpeed = 120
                                showAdd = false
                            }
                        }
                    }
                }
            }
        }
    }
}
