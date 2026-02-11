import SwiftUI

struct WidePanelView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
                .background(appState.theme.line.opacity(0.1))
            
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appState.theme.background)
        .overlay(alignment: .trailing) {
            // Shadow separator from inspector
            Rectangle()
                .fill(LinearGradient(colors: [.black.opacity(0.05), .clear], startPoint: .trailing, endPoint: .leading))
                .frame(width: 20)
        }
    }
    
    @ViewBuilder
    private var header: some View {
        HStack {
            if let line = appState.selectedLine {
                Text(line.name)
                    .font(.headline)
                    .foregroundColor(appState.theme.dark)
                
                Text(appState.lineInspectorMode.rawValue)
                    .font(.subheadline)
                    .foregroundColor(appState.theme.medium)
            } else if appState.sidebarSelection == .trains {
                Text("Treni per Linea")
                    .font(.headline)
                    .foregroundColor(appState.theme.dark)
            }
            
            Spacer()
            
            // Mode Toggle (Table / Graph) if applicable
            // This can be handled inside LineScheduleView
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .padding(.top, 40) // SafeArea padding
    }
    
    @ViewBuilder
    private var content: some View {
        if appState.sidebarSelection == .lines {
            if let line = appState.selectedLine {
                LineScheduleView(line: line)
                    .environmentObject(appState.railroad.lines)
                    .environmentObject(appState.railroad.network)
            }
        } else if appState.sidebarSelection == .trains {
            TrainsByLineListView()
        } else {
            Color.clear
        }
    }
}
