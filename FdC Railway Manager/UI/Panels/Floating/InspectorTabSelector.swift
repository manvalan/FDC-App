import SwiftUI

struct InspectorTabSelector: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        if shouldShowTabSelector {
            HStack(spacing: 0) {
                tabButton(title: "Rete", item: .stations)
                tabButton(title: "Binari", item: .tracks)
            }
            .padding(.horizontal)
            .background(appState.theme.light.opacity(0.4))
            .cornerRadius(10)
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
    }
    
    private var shouldShowTabSelector: Bool {
        appState.selectedLine == nil && 
        appState.selectedNode == nil && 
        appState.selectedEdgeId == nil && 
        (appState.sidebarSelection == .stations || appState.sidebarSelection == .tracks)
    }
    
    private func tabButton(title: String, item: SidebarItem) -> some View {
        Button(action: { appState.sidebarSelection = item }) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(appState.sidebarSelection == item ? appState.theme.accent.opacity(0.12) : Color.clear)
        }
        .foregroundColor(appState.sidebarSelection == item ? appState.theme.accent : appState.theme.dark)
        // Note: cornerRadius(10, corners: [...]) is a custom extension, I'll use it if available or standard
        .cornerRadius(10) 
    }
}
