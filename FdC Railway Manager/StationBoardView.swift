import SwiftUI

struct StationBoardView: View {
    let station: Node
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var arrivals: [(TrainSchedule, ScheduleStop)] {
        var result: [(TrainSchedule, ScheduleStop)] = []
        for schedule in appState.simulator.schedules {
            if let stop = schedule.stops.first(where: { $0.stationId == station.id }) {
                result.append((schedule, stop))
            }
        }
        // Sort by arrival time if available, otherwise departure
        return result.sorted { a, b in
            let timeA = a.1.arrivalTime ?? a.1.departureTime ?? Date.distantPast
            let timeB = b.1.arrivalTime ?? b.1.departureTime ?? Date.distantPast
            return timeA < timeB
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Informazioni Stazione")) {
                    LabeledContent("ID", value: station.id)
                    LabeledContent("Tipo", value: station.type.rawValue.capitalized)
                    if let cap = station.capacity {
                        LabeledContent("Capacità", value: "\(cap) treni")
                    }
                    if let plat = station.platforms {
                        LabeledContent("Binari", value: "\(plat)")
                    }
                }
                
                Section(header: Text("Tabellone Arrivi/Partenze")) {
                    if arrivals.isEmpty {
                        Text("Nessun treno programmato per questa stazione.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(arrivals, id: \.0.id) { (schedule, stop) in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(schedule.trainName)
                                        .font(.headline)
                                    Spacer()
                                    if let arr = stop.arrivalTime {
                                        Text(formatTime(arr)).bold()
                                    } else {
                                        Text("ORIGINE").font(.caption).bold()
                                    }
                                }
                                
                                HStack {
                                    Text(schedule.trainName.contains("AV") ? "Alta Velocità" : "Regionale")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(schedule.trainName.contains("AV") ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                                        .foregroundColor(schedule.trainName.contains("AV") ? .red : .blue)
                                        .cornerRadius(4)
                                    
                                    Spacer()
                                    
                                    if let dep = stop.departureTime {
                                        Text("Partenza: \(formatTime(dep))")
                                            .font(.caption).foregroundColor(.secondary)
                                    } else {
                                        Text("TERMINE CORSA").font(.caption).foregroundColor(.red).bold()
                                    }
                                }
                                
                                HStack {
                                    Label("Binario \(stop.platform ?? 1)", systemImage: "tram")
                                        .font(.caption)
                                    
                                    Spacer()
                                    
                                    if schedule.totalDelayMinutes > 0 {
                                        Text("+\(schedule.totalDelayMinutes) min")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(station.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
