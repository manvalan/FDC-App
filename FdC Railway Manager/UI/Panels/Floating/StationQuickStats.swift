import SwiftUI
import UIKit

struct StationQuickStats: View {
    let node: Node
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    var onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(node.type.rawValue.capitalized)
                    .font(.caption.bold())
                    .foregroundColor(appState.theme.dark)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(appState.theme.light)
                    .cornerRadius(6)
                
                if let hub = node.parentHubId {
                    Text("Hub: \(hub)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(appState.theme.medium)
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                CompactInfoRow(label: "Binari", value: "\(node.platforms ?? 1)")
                CompactInfoRow(label: "Capacità", value: "\(node.capacity ?? 10) treni")
            }
            
            StationRoutingConstraintsView(node: node)
            
            Button(action: onEdit) {
                Text("Dettagli completi")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10).background(appState.theme.light).foregroundColor(appState.theme.dark).cornerRadius(10)
            }
        }
    }
}
