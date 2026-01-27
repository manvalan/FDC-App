import SwiftUI

struct ScheduleCreationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    
    let relation: TrainRelation
    
    // Scheduling Mode
    enum ScheduleMode: String, CaseIterable, Identifiable {
        case single = "Corsa Singola"
        case cadenced = "Cadenzato"
        var id: String { rawValue }
    }
    
    @State private var mode: ScheduleMode = .single
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(3600 * 4)
    @State private var intervalMinutes: Int = 60
    @State private var selectedTrainType: String = "Regionale" // New State
    
    // Paired Return
    @State private var scheduleReturn: Bool = false
    @State private var returnRelation: TrainRelation? = nil
    @State private var returnDelayMinutes: Int = 15 // Turnaround time
    
    // Preview
    @State private var previewCount: Int = 0
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Configurazione")) {
                    Picker("Modalità", selection: $mode) {
                        ForEach(ScheduleMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    
                    Picker("Tipo Treno", selection: $selectedTrainType) {
                        Text("Regionale").tag("Regionale")
                        Text("Diretto").tag("Diretto")
                        Text("Alta Velocità").tag("Alta Velocità")
                        Text("Merci").tag("Merci")
                    }
                    
                    DatePicker("Ora Inizio", selection: $startTime, displayedComponents: .hourAndMinute)
                    
                    if mode == .cadenced {
                        DatePicker("Ora Fine", selection: $endTime, displayedComponents: .hourAndMinute)
                        Stepper("Intervallo: \(intervalMinutes) min", value: $intervalMinutes, in: 10...360, step: 10)
                    }
                }
                
                Section(header: Text("Ritorno (Coppia)")) {
                    if let retRel = returnRelation {
                        Toggle("Pianifica Ritorno (B -> A)", isOn: $scheduleReturn)
                        if scheduleReturn {
                            Text("Relazione: \(retRel.name)")
                            Stepper("Tempo di giro: \(returnDelayMinutes) min", value: $returnDelayMinutes, in: 5...120, step: 5)
                            Text("Il treno ripartirà \(returnDelayMinutes) minuti dopo l'arrivo.").font(.caption).foregroundColor(.secondary)
                        }
                    } else {
                        Text("Nessuna relazione di ritorno trovata.").foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Anteprima")) {
                    Text("Verranno creati \(previewCount) treni.")
                    if scheduleReturn {
                        Text("(Metà andata, metà ritorno)")
                    }
                }
            }
            .navigationTitle("Crea Orario")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Genera") {
                        generateSchedule()
                    }
                }
            }
            .onAppear {
                findReturnRelation()
                updatePreview()
            }
            .onChange(of: mode) { _ in updatePreview() }
            .onChange(of: startTime) { _ in updatePreview() }
            .onChange(of: endTime) { _ in updatePreview() }
            .onChange(of: intervalMinutes) { _ in updatePreview() }
            .onChange(of: scheduleReturn) { _ in updatePreview() }
        }
    }
    
    // ... (Helpers remain same until generateSchedule)
    
    private func findReturnRelation() {
        // Look for relation on same line with swapped origin/dest
        returnRelation = network.relations.first(where: { 
            $0.lineId == relation.lineId && 
            $0.originId == relation.destinationId && 
            $0.destinationId == relation.originId 
        })
    }
    
    private func updatePreview() {
        var count = 0
        if mode == .single {
            count = 1
        } else {
            let start = startTime
            let end = endTime
            // Calculate components
            let calendar = Calendar.current
            let startComp = calendar.dateComponents([.hour, .minute], from: start)
            let endComp = calendar.dateComponents([.hour, .minute], from: end)
            
            let startMinutes = (startComp.hour ?? 0) * 60 + (startComp.minute ?? 0)
            var endMinutes = (endComp.hour ?? 0) * 60 + (endComp.minute ?? 0)
            if endMinutes < startMinutes { endMinutes += 24 * 60 } // Next day
            
            if intervalMinutes > 0 {
                count = (endMinutes - startMinutes) / intervalMinutes + 1
            }
        }
        
        if scheduleReturn && returnRelation != nil {
            count *= 2
        }
        previewCount = max(0, count)
    }
    
    private func generateSchedule() {
        let calendar = Calendar.current
        
        var iterations = 1
        if mode == .cadenced {
             let startComp = calendar.dateComponents([.hour, .minute], from: startTime)
             let endComp = calendar.dateComponents([.hour, .minute], from: endTime)
             let startMinutes = (startComp.hour ?? 0) * 60 + (startComp.minute ?? 0)
             var endMinutes = (endComp.hour ?? 0) * 60 + (endComp.minute ?? 0)
             if endMinutes < startMinutes { endMinutes += 24 * 60 }
             iterations = (endMinutes - startMinutes) / intervalMinutes + 1
        }
        
        for i in 0..<iterations {
            let departureTime = calendar.date(byAdding: .minute, value: i * intervalMinutes, to: startTime) ?? startTime
            
            // 1. Create Train for OUTWARD
            let trainId = UUID()
            let timeStr = formatTime(departureTime)
            let trainName = "\(relation.name) \(timeStr)"
            
            let maxSpeed: Int = selectedTrainType == "Alta Velocità" ? 300 : (selectedTrainType == "Merci" ? 100 : 160)
            
            let train = Train(
                id: trainId,
                name: trainName,
                type: selectedTrainType,
                maxSpeed: maxSpeed,
                relationId: relation.id,
                departureTime: departureTime,
                stops: relation.stops
            )
            
            manager.trains.append(train)
            
            // 2. Create Train for RETURN
            if scheduleReturn, let retRel = returnRelation {
                 let travelMinutes = estimateTravelTime(relation)
                 let returnDep = calendar.date(byAdding: .minute, value: travelMinutes + returnDelayMinutes, to: departureTime) ?? departureTime
                 
                 let retTimeStr = formatTime(returnDep)
                 let retName = "\(retRel.name) \(retTimeStr)"
                 
                 let retTrain = Train(
                    id: UUID(),
                    name: retName,
                    type: selectedTrainType,
                    maxSpeed: maxSpeed,
                    relationId: retRel.id,
                    departureTime: returnDep,
                    stops: retRel.stops
                 )
                 manager.trains.append(retTrain)
            }
        }
        
        dismiss()
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
    
    private func estimateTravelTime(_ rel: TrainRelation) -> Int {
        // Simple heuristic: 3 mins per stop + 5 mins travel
        return rel.stops.count * 8 + 10 
    }
}
