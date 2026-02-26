import SwiftUI

/// Vista per mostrare l'anteprima dei risultati della generazione orario prima della conferma
struct SchedulePreviewView: View {
    let trains: [Train]
    let line: TrainRoute
    let mode: ScheduleMode
    let onAccept: () -> Void
    let onReject: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    enum ScheduleMode {
        case single, cadenced
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
            
            // Statistiche riepilogo
            statsSection
            
            Divider()
            
            // Lista treni
            ScrollView {
                trainsList
                    .padding()
            }
            
            Divider()
            
            // Azioni
            actionsSection
        }
        .frame(minWidth: 400, minHeight: 600)
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedString("preview_schedule"))
                        .font(.headline)
                    Text(line.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(trains.count) train(s)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(mode == .single ? localizedString("single_trip") : localizedString("cadenced_service"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .background(Color.primary.opacity(0.05))
    }
    
    private var statsSection: some View {
        HStack(spacing: 20) {
            StatBox(
                icon: "arrow.right",
                label: localizedString("outbound"),
                value: "\(trains.filter { !isReturnTrain($0) }.count)"
            )
            
            StatBox(
                icon: "arrow.left",
                label: localizedString("return"),
                value: "\(trains.filter { isReturnTrain($0) }.count)"
            )
            
            if mode == .cadenced {
                StatBox(
                    icon: "clock",
                    label: localizedString("interval"),
                    value: calculateAverageInterval()
                )
            }
            
            StatBox(
                icon: "gauge.medium",
                label: localizedString("vehicles_assigned"),
                value: "\(trains.filter { $0.vehicleId != nil }.count)/\(trains.count)"
            )
        }
        .padding()
        .background(Color.primary.opacity(0.03))
    }
    
    private var trainsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(trains.sorted(by: { ($0.departureTime ?? .distantPast) < ($1.departureTime ?? .distantPast) })) { train in
                TrainPreviewCard(train: train)
            }
        }
    }
    
    private var actionsSection: some View {
        HStack(spacing: 16) {
            Button(role: .cancel) {
                onReject()
            } label: {
                Label(localizedString("reject"), systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            
            Button {
                onAccept()
            } label: {
                Label(localizedString("accept_schedule"), systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .background(Color.primary.opacity(0.05))
    }
    
    // MARK: - Helpers
    
    private func isReturnTrain(_ train: Train) -> Bool {
        guard let first = train.stops.first?.stationId,
              let last = train.stops.last?.stationId else {
            return false
        }
        return first == line.destinationStationId && last == line.originStationId
    }
    
    private func calculateAverageInterval() -> String {
        let outbound = trains.filter { !isReturnTrain($0) }
            .compactMap { $0.departureTime }
            .sorted()
        
        guard outbound.count >= 2 else { return "N/A" }
        
        var intervals: [TimeInterval] = []
        for i in 0..<(outbound.count - 1) {
            intervals.append(outbound[i+1].timeIntervalSince(outbound[i]))
        }
        
        let avgSeconds = intervals.reduce(0, +) / Double(intervals.count)
        let avgMinutes = Int(avgSeconds / 60)
        
        return "\(avgMinutes) min"
    }
}

// MARK: - Supporting Views

struct StatBox: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

struct TrainPreviewCard: View {
    let train: Train
    
    var body: some View {
        HStack(spacing: 12) {
            // Numero treno
            VStack(spacing: 4) {
                Text(train.name)
                    .font(.headline)
                Text("\(train.number)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80)
            
            Divider()
            
            // Orario partenza
            VStack(alignment: .leading, spacing: 4) {
                Text(localizedString("departure"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let dep = train.departureTime {
                    Text(formatTime(dep))
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                } else {
                    Text("--:--")
                        .foregroundColor(.secondary)
                }
            }
            
            // Icona direzione
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
            
            // Stazioni
            VStack(alignment: .leading, spacing: 2) {
                if let first = train.stops.first, let last = train.stops.last {
                    Text("\(first.stationId) → \(last.stationId)")
                        .font(.subheadline)
                    Text("\(train.stops.count) stop(s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Mezzo assegnato
            if train.vehicleId != nil {
                Image(systemName: "tram.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "tram")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.1))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Localization Helper

private func localizedString(_ key: String) -> String {
    switch key {
    case "preview_schedule": return "Anteprima Orario"
    case "single_trip": return "Corsa Singola"
    case "cadenced_service": return "Servizio Cadenzato"
    case "outbound": return "Andata"
    case "return": return "Ritorno"
    case "interval": return "Intervallo"
    case "vehicles_assigned": return "Mezzi"
    case "reject": return "Rifiuta"
    case "accept_schedule": return "Accetta Orario"
    case "departure": return "Partenza"
    default: return NSLocalizedString(key, comment: "")
    }
}
