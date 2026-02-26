import SwiftUI
import UIKit

struct LineVehiclesView: View {
    let lineId: String
    @EnvironmentObject var linesManager: LinesManager
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mezzi in servizio")
                .font(.headline)
                .foregroundColor(appState.theme.dark)
                .padding(.horizontal)
            
            let assignedTrains = linesManager.trains.filter { $0.routeId == lineId }
            let groupedTrains = Dictionary(grouping: assignedTrains) { train -> String in
                if let vehicleId = train.vehicleId,
                   let vehicle = linesManager.vehicles.first(where: { $0.id == vehicleId }) {
                    return cleanModelName(vehicle.name)
                }
                return "Non Assegnati"
            }
            
            if assignedTrains.isEmpty {
                VStack(spacing: 8) {
                    Text("Nessun treno programmato.")
                        .font(.caption)
                        .foregroundColor(appState.theme.medium)
                    Text("Premi a lungo su 'Orario' per generare corse.")
                        .font(.system(size: 9))
                        .foregroundColor(appState.theme.medium.opacity(0.7))
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(appState.theme.light.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(groupedTrains.keys.sorted(), id: \.self) { type in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(type.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(appState.theme.medium)
                                    .padding(.horizontal, 4)
                                
                                ForEach(groupedTrains[type] ?? []) { train in
                                    Button(action: { appState.selectTrain(train.id) }) {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(train.name).font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                                                HStack {
                                                    Text("Corsa \(train.number ?? 0)")
                                                    if let dep = train.departureTime {
                                                        Text("• \(dep, style: .time)")
                                                    }
                                                }
                                                .font(.system(size: 10))
                                                .foregroundColor(appState.theme.medium)
                                            }
                                            Spacer()
                                            
                                            if train.vehicleId == nil {
                                                Text("NON ASS.")
                                                    .font(.system(size: 8, weight: .black))
                                                    .padding(4)
                                                    .background(Color.red.opacity(0.1))
                                                    .foregroundColor(.red)
                                                    .cornerRadius(4)
                                            }
                                            
                                            if appState.selectedTrainIds.contains(train.id) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(appState.theme.accent)
                                            }
                                        }
                                        .padding(12)
                                        .background(appState.selectedTrainIds.contains(train.id) ? appState.theme.accent.opacity(0.05) : appState.theme.light.opacity(0.4))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func cleanModelName(_ name: String) -> String {
        // Rimuove brand come "Alstom", "Hitachi", ecc. se presenti
        let brands = ["Alstom", "Hitachi", "Ansaldo", "Breda", "Stadler", "Pesa", "Siemens", "Bombardier", "Fiat"]
        var cleaned = name
        for brand in brands {
            cleaned = cleaned.replacingOccurrences(of: brand, with: "", options: .caseInsensitive)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
