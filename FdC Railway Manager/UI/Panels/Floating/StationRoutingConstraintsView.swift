import SwiftUI
import UIKit

struct StationRoutingConstraintsView: View {
    let node: Node
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    var body: some View {
        if !node.routingConstraints.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Vincoli").font(.system(size: 11, weight: .bold)).foregroundColor(appState.theme.medium)
                ForEach(node.routingConstraints) { constraint in
                    RoutingConstraintRow(constraint: constraint)
                }
            }
            .padding(10)
            .background(appState.theme.light.opacity(0.3))
            .cornerRadius(10)
        }
    }
}
