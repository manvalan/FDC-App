import SwiftUI
import UIKit

struct TrackRowContent: View {
    let edge: Edge
    let network: NetworkModel
    @EnvironmentObject var appState: AppState
    
    private var trackColor: Color {
        edge.trackType.color
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Badge icon with track symbol
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(trackColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                NetworkSymbols.trackSymbol(for: edge.trackType, width: 30, height: 20)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                let fromName = network.nodes.first(where: { $0.id == edge.from })?.name ?? edge.from
                let toName = network.nodes.first(where: { $0.id == edge.to })?.name ?? edge.to
                
                Text("\(fromName) ↔ \(toName)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(appState.theme.dark)
                
                Text(String(format: "%.1f km • %d km/h", edge.distance, edge.maxSpeed))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(appState.isEdgeSelected(edge.id.uuidString) ? appState.theme.accent.opacity(0.15) : appState.theme.backgroundSecondary)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(appState.isEdgeSelected(edge.id.uuidString) ? appState.theme.accent : appState.theme.line.opacity(0.2), lineWidth: 1)
        )
    }
}
