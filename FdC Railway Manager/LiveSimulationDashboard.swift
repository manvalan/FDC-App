import SwiftUI

struct LiveSimulationDashboard: View {
    @EnvironmentObject var appState: AppState
    private var simulator: FDCSimulator { appState.simulator }
    private var liveSim: LiveSimulationManager { appState.liveSim }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("simulation_dashboard".localized)
                    .font(.headline)
                Spacer()
                if liveSim.isRunning {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("LIVE").font(.caption).bold().foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
                }
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Control Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("controls".localized).font(.caption).foregroundColor(.secondary)
                        
                        HStack {
                            Button(action: { liveSim.toggle() }) {
                                Label(liveSim.isRunning ? "pause".localized : "play".localized, 
                                      systemImage: liveSim.isRunning ? "pause.fill" : "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(liveSim.isRunning ? .orange : .green)
                            
                            Button(action: { liveSim.stop() }) {
                                Image(systemName: "stop.fill")
                                    .padding(.horizontal)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Live Traffic
                    VStack(alignment: .leading, spacing: 12) {
                        Text("live_traffic".localized).font(.caption).foregroundColor(.secondary)
                        
                        let activeTrains = getActiveTrains()
                        if activeTrains.isEmpty {
                            Text("no_active_trains".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.5))
                                .cornerRadius(8)
                        } else {
                            ForEach(activeTrains) { info in
                                TrainLiveRow(info: info)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Resource Occupancy
                    VStack(alignment: .leading, spacing: 12) {
                        Text("infrastructure_load".localized).font(.caption).foregroundColor(.secondary)
                        
                        let usage = calculateResourceUsage()
                        ForEach(usage.sorted(by: { $0.load > $1.load }), id: \.id) { res in
                            ResourceLoadRow(resource: res)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Event Log (Train Director style)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("simulation_log".localized).font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Button("clear".localized) { liveSim.log.clear() }
                                .font(.caption2)
                        }
                        
                        VStack(spacing: 1) {
                            if liveSim.log.entries.isEmpty {
                                Text("no_events_yet".localized)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(liveSim.log.entries) { entry in
                                    LogEntryRow(entry: entry)
                                }
                            }
                        }
                        .background(Color.black.opacity(0.02))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
    }
    
    // MARK: - Helpers
    
    struct TrainSimInfo: Identifiable {
        let id: UUID
        let name: String
        let currentStatus: String
        let delay: Int
        let nextStop: String?
        let progress: Double
    }
    
    private func getActiveTrains() -> [TrainSimInfo] {
        let now = liveSim.currentSimTime
        return simulator.schedules.compactMap { sch -> TrainSimInfo? in
            guard let firstStart = sch.stops.first?.departureTime ?? sch.stops.first?.arrivalTime,
                  let lastEnd = sch.stops.last?.arrivalTime ?? sch.stops.last?.departureTime else { return nil }
            
            if now < firstStart || now > lastEnd { return nil }
            
            // Find current segment
            var currentStatus = "moving_label".localized
            var nextStop: String? = nil
            var progress: Double = 0.0
            
            for i in 0..<(sch.stops.count - 1) {
                let s1 = sch.stops[i]
                let s2 = sch.stops[i+1]
                if let d1 = s1.departureTime, let a2 = s2.arrivalTime, now >= d1 && now <= a2 {
                    progress = now.timeIntervalSince(d1) / a2.timeIntervalSince(d1)
                    nextStop = s2.stationName
                    currentStatus = "\("en_route_to".localized) \(s2.stationName)"
                    break
                }
                if let a1 = s1.arrivalTime, let d1 = s1.departureTime, now >= a1 && now <= d1 {
                    progress = 1.0
                    currentStatus = "\("stopped_at".localized) \(s1.stationName)"
                    nextStop = sch.stops.indices.contains(i+1) ? sch.stops[i+1].stationName : nil
                    break
                }
            }
            
            return TrainSimInfo(id: sch.id, name: sch.trainName, currentStatus: currentStatus, delay: sch.totalDelayMinutes, nextStop: nextStop, progress: progress)
        }
    }
    
    struct ResourceUsage: Identifiable {
        let id: String
        let name: String
        let load: Double // 0.0 to 1.0
        let occupants: [String]
    }
    
    private func calculateResourceUsage() -> [ResourceUsage] {
        // Simple mock for now
        return []
    }
}

struct TrainLiveRow: View {
    let info: LiveSimulationDashboard.TrainSimInfo
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(info.name).font(.headline)
                    Text(info.currentStatus).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if info.delay > 0 {
                    Text("+\(info.delay) min").font(.caption).bold().foregroundColor(.red)
                }
            }
            
            ProgressView(value: info.progress)
                .tint(.blue)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.02), radius: 5)
    }
}

struct ResourceLoadRow: View {
    let resource: LiveSimulationDashboard.ResourceUsage
    
    var body: some View {
        HStack {
            Text(resource.name).font(.subheadline)
            Spacer()
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.2)).frame(width: 100, height: 8)
                RoundedRectangle(cornerRadius: 4).fill(loadColor).frame(width: 100 * CGFloat(resource.load), height: 8)
            }
        }
    }
    
    private var loadColor: Color {
        if resource.load > 0.8 { return .red }
        if resource.load > 0.5 { return .orange }
        return .green
    }
}

struct LogEntryRow: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.timestamp, style: .time)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
            
            Text(entry.message)
                .font(.system(size: 11))
                .foregroundColor(entryColor)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(entry.type == .success ? Color.green.opacity(0.05) : Color.clear)
    }
    
    private var entryColor: Color {
        switch entry.type {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .info: return .primary
        }
    }
}
