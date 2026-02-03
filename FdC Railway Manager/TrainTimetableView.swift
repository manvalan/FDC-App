import SwiftUI
import Combine

struct TrainTimetableView: View {
    @ObservedObject var schedule: TrainSchedule
    let simulator: FDCSimulator? // Optional, for live resolution if needed
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(String(format: "train_label_fmt".localized, schedule.trainName))) {
                    HStack {
                        Label("total_delay_label".localized, systemImage: "clock.badge.exclamationmark")
                        Spacer()
                        Text("\(schedule.totalDelayMinutes) min")
                            .foregroundColor(schedule.totalDelayMinutes > 0 ? .red : .primary)
                    }
                }
                
                Section(header: Text("detailed_schedule".localized)) {
                    HStack {
                        Text("station".localized).bold().frame(maxWidth: .infinity, alignment: .leading)
                        Text("arrival".localized).bold().frame(width: 60)
                        Text("departure".localized).bold().frame(width: 60)
                        Text("dwell_time_short".localized).bold().frame(width: 40)
                        Text("platform_short".localized).bold().frame(width: 40)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    ForEach(schedule.stops) { stop in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(stop.stationName).font(.headline)
                                Text(stop.stationId).font(.caption2).foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text(formatTime(stop.arrivalTime, refDate: schedule.stops.first?.departureTime))
                                .frame(width: 60)
                            
                            Text(formatTime(stop.departureTime, refDate: schedule.stops.first?.departureTime))
                                .frame(width: 60)
                                
                            Text(formatDwell(stop))
                                .frame(width: 40)
                                .foregroundColor(.secondary)
                            
                            Text("\(stop.platform ?? 1)")
                                .frame(width: 40)
                        }
                        .padding(.vertical, 4)
                        .background(isConflict(stationId: stop.stationId) ? Color.red.opacity(0.1) : Color.clear)
                    }
                }
            }
            .navigationTitle("timetable_detail".localized)
            .toolbar {
                if let sim = simulator {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("solve_conflicts_button".localized) {
                            // This would run resolution for whole network
                        }
                    }
                }
            }
        }
    }
    
    func formatTime(_ date: Date?, refDate: Date? = nil) -> String {
        guard let date = date else { return "-" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        var str = formatter.string(from: date)
        
        // Add +1 if day differs from refDate (start of train)
        if let ref = refDate {
            let cal = Calendar.current
            if !cal.isDate(date, inSameDayAs: ref) {
                let diff = cal.dateComponents([.day], from: ref, to: date).day ?? 0
                if diff > 0 { str += " (+\(diff))" }
            }
        }
        return str
    }
    
    func formatDwell(_ stop: ScheduleStop) -> String {
        if let arr = stop.arrivalTime, let dep = stop.departureTime {
            let diff = dep.timeIntervalSince(arr)
            if diff > 0 {
                return String(format: "%d'", Int(diff / 60))
            }
        }
        // Fallback to min dwell if actual times not set
        if stop.dwellsMinutes > 0 {
             return "\(stop.dwellsMinutes)'"
        }
        return "-"
    }
    
    func isConflict(stationId: String) -> Bool {
        return simulator?.activeConflicts.contains(where: { $0.locationId == stationId && $0.trainIds.contains(schedule.trainId) }) ?? false
    }
}

#Preview {
    let mockSch = TrainSchedule(trainId: UUID(), trainName: "Frecciarossa 1000")
    mockSch.stops = [
        ScheduleStop(stationId: "MI", arrivalTime: nil, departureTime: Date(), platform: 1, dwellsMinutes: 0, stationName: "Milano Centrale"),
        ScheduleStop(stationId: "RO", arrivalTime: Date().addingTimeInterval(3600), departureTime: nil, platform: 10, dwellsMinutes: 0, stationName: "Roma Termini")
    ]
    return TrainTimetableView(schedule: mockSch, simulator: nil)
}
