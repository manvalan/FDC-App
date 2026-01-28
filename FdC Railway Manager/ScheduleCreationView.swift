import SwiftUI

struct ScheduleCreationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    
    let line: RailwayLine
    
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
    @State private var selectedTrainType: String = "Regionale"
    @State private var startNumber: Int = 1000
    
    // Paired Return
    @State private var scheduleReturn: Bool = false
    @State private var returnLine: RailwayLine? = nil
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
                        Text("Supporto").tag("Supporto")
                    }
                    
                    DatePicker("Ora Inizio", selection: $startTime, displayedComponents: .hourAndMinute)
                    
                    if mode == .cadenced {
                        DatePicker("Ora Fine", selection: $endTime, displayedComponents: .hourAndMinute)
                        Stepper("Intervallo: \(intervalMinutes) min", value: $intervalMinutes, in: 10...360, step: 10)
                    }
                    
                    HStack {
                        Text("Numero Iniziale")
                        Spacer()
                        TextField("1000", value: $startNumber, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
                
                Section(header: Text("Ritorno (Coppia)")) {
                    if let retLine = returnLine {
                        Toggle("Pianifica Ritorno (B -> A)", isOn: $scheduleReturn)
                        if scheduleReturn {
                            Text("Linea Ritorno: \(retLine.name)")
                            Stepper("Tempo di giro: \(returnDelayMinutes) min", value: $returnDelayMinutes, in: 5...120, step: 5)
                            Text("Il treno ripartirà \(returnDelayMinutes) minuti dopo l'arrivo.").font(.caption).foregroundColor(.secondary)
                        }
                    } else {
                        Text("Nessuna linea di ritorno trovata.").foregroundColor(.secondary)
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
                findReturnLine()
                updatePreview()
            }
            .onChange(of: mode) { _ in updatePreview() }
            .onChange(of: startTime) { _ in updatePreview() }
            .onChange(of: endTime) { _ in updatePreview() }
            .onChange(of: intervalMinutes) { _ in updatePreview() }
            .onChange(of: scheduleReturn) { _ in updatePreview() }
        }
    }
    
    private func findReturnLine() {
        returnLine = network.lines.first(where: { 
            $0.originId == line.destinationId && 
            $0.destinationId == line.originId 
        })
    }
    
    private func updatePreview() {
        var count = 0
        if mode == .single {
            count = 1
        } else {
            let start = startTime
            let end = endTime
            let calendar = Calendar.current
            let startComp = calendar.dateComponents([.hour, .minute], from: start)
            let endComp = calendar.dateComponents([.hour, .minute], from: end)
            
            let startMinutes = (startComp.hour ?? 0) * 60 + (startComp.minute ?? 0)
            var endMinutes = (endComp.hour ?? 0) * 60 + (endComp.minute ?? 0)
            if endMinutes < startMinutes { endMinutes += 24 * 60 }
            
            if intervalMinutes > 0 {
                count = (endMinutes - startMinutes) / intervalMinutes + 1
            }
        }
        
        if scheduleReturn && returnLine != nil {
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
            
            // 1. OUTWARD
            let timeStr = formatTime(departureTime)
            let trainName = "\(line.name) \(timeStr)"
            let maxSpeed: Int = selectedTrainType == "Alta Velocità" ? 300 : (selectedTrainType == "Merci" ? 100 : 160)
            
            let outwardNumber = startNumber + (i * 2)
            let outwardTrain = Train(
                id: UUID(),
                number: outwardNumber,
                name: trainName,
                type: selectedTrainType,
                maxSpeed: maxSpeed,
                lineId: line.id,
                departureTime: departureTime,
                stops: line.stops
            )
            manager.trains.append(outwardTrain)
            
            // 2. RETURN
            if scheduleReturn, let retLine = returnLine {
                 let travelMinutes = estimateTravelTime(line)
                 let returnDep = calendar.date(byAdding: .minute, value: travelMinutes + returnDelayMinutes, to: departureTime) ?? departureTime
                 let retTimeStr = formatTime(returnDep)
                 let retName = "\(retLine.name) \(retTimeStr)"
                 
                 let returnNumber = outwardNumber + 1
                 let retTrain = Train(
                    id: UUID(),
                    number: returnNumber,
                    name: retName,
                    type: selectedTrainType,
                    maxSpeed: maxSpeed,
                    lineId: retLine.id,
                    departureTime: returnDep,
                    stops: retLine.stops
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
    
    private func estimateTravelTime(_ line: RailwayLine) -> Int {
        // Simple heuristic: 3 mins per stop + 5 mins travel
        return line.stops.count * 8 + 10 
    }
}
