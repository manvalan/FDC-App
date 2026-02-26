import SwiftUI
import UIKit

struct EdgeRowButton: View {
    @EnvironmentObject var appState: AppState
    let edge: Edge
    var body: some View {
        Button(action: { appState.selectedEdgeId = edge.id.uuidString }) {
            let fromName = appState.railroad.network.nodes.first(where: { $0.id == edge.from })?.name ?? edge.from
            let toName = appState.railroad.network.nodes.first(where: { $0.id == edge.to })?.name ?? edge.to
            HStack(spacing: 8) {
                Text("🛤")
                Text("\(fromName) ↔ \(toName)")
            }
        }
        .buttonStyle(.plain)
    }
}
