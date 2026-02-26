import SwiftUI
import UIKit

struct TrackQuickStats: View {
    let edge: Edge
    @EnvironmentObject var appState: AppState
    var onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            let fromName = appState.railroad.network.nodes.first(where: { $0.id == edge.from })?.name ?? edge.from
            let toName = appState.railroad.network.nodes.first(where: { $0.id == edge.to })?.name ?? edge.to
            
            Text("\(fromName) ↔ \(toName)").font(.subheadline.bold()).foregroundColor(appState.theme.dark)
            
            VStack(alignment: .leading, spacing: 10) {
                CompactInfoRow(label: "Distanza", value: String(format: "%.1f km", edge.distance))
                CompactInfoRow(label: "Velocità", value: "\(edge.maxSpeed) km/h")
                CompactInfoRow(label: "Tipo", value: edge.trackType.displayName)
            }
            
            Button(action: onEdit) {
                Text("Modifica Tratta")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10).background(appState.theme.light).foregroundColor(appState.theme.dark).cornerRadius(10)
            }
        }
    }
}
