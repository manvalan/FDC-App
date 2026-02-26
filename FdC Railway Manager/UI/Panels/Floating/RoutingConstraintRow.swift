import SwiftUI
import UIKit

struct RoutingConstraintRow: View {
    let constraint: RoutingConstraint
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    var body: some View {
        HStack(spacing: 8) {
            let line = linesManager.routes.first { $0.id == constraint.routeId }
            Circle().fill(line?.displayColor ?? .gray).frame(width: 6, height: 6)
            Text(line?.name ?? constraint.routeId)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(appState.theme.dark)
            Spacer()
            Text(constraint.allowedTracks.joined(separator: ", "))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(appState.theme.accent)
        }
    }
}
