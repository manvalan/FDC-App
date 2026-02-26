import SwiftUI
import UIKit

struct InspectorWrapperView<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack(spacing: 12) {
                Button(action: {
                    appState.selectedNodeId = nil
                    appState.selectedEdgeId = nil
                    appState.selectedVehicleId = nil
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(appState.theme.accent)
                        .frame(width: 32, height: 32)
                        .background(appState.theme.accent.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(appState.theme.dark)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(appState.theme.background)
            
            Divider()
            
            ScrollView {
                content()
                    .padding(16)
            }
        }
    }
}
