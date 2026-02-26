import SwiftUI
import UIKit

struct LineRow: View {
    let line: TrainRoute
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    var body: some View {
        Button(action: {
            appState.selectedRouteId = line.id
            appState.mapVisualizationMode = .scheduler
        }) {
            HStack(spacing: 12) {
                Text(line.serviceCodePrefix ?? "L")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(line.displayColor.isDark ? .white : .black)
                    .frame(width: 44, height: 32)
                    .background(line.displayColor)
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.name)
                        .font(.subheadline.bold())
                        .foregroundColor(appState.theme.dark)
                    
                    HStack(spacing: 4) {
                        let origin = appState.railroad.network.nodes.first(where: { $0.id == line.originStationId })?.name ?? "-"
                        let destination = appState.railroad.network.nodes.first(where: { $0.id == line.destinationStationId })?.name ?? "-"
                        Text("\(origin) → \(destination)")
                        if let mid = findUniqueIntermediate() { Text("(via \(mid))") }
                    }
                    .font(.system(size: 10))
                    .foregroundColor(appState.theme.medium)
                }
                Spacer()
            }
            .padding(.vertical, 8).padding(.horizontal, 10).frame(maxWidth: .infinity, alignment: .leading)
            .background(appState.selectedRouteId == line.id ? appState.theme.accent.opacity(0.15) : appState.theme.backgroundSecondary)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(appState.selectedRouteId == line.id ? appState.theme.accent : appState.theme.line.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    
    private func findUniqueIntermediate() -> String? {
        let allRoutes = linesManager.routes
        let sameTerminals = allRoutes.filter {
            $0.originStationId == line.originStationId && $0.destinationStationId == line.destinationStationId
        }
        if sameTerminals.count <= 1 { return nil }
        let midStops = line.stationIds.filter { $0 != line.originStationId && $0 != line.destinationStationId }
        for stopId in midStops {
            let isUnique = !sameTerminals.contains { other in
                other.id != line.id && other.stationIds.contains(stopId)
            }
            if isUnique { return appState.railroad.network.nodes.first(where: { $0.id == stopId })?.name }
        }
        return appState.railroad.network.nodes.first(where: { $0.id == (midStops.first ?? "") })?.name
    }
}
