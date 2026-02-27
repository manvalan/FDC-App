import SwiftUI

struct MapToolbarView: ToolbarContent {
    @EnvironmentObject var appState: AppState
    @Binding var zoomLevel: Double
    @Binding var hiddenLineIds: Set<String>
    
    private var lines: LinesManager { appState.railroad.lines }
    
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            resetZoomButton
            lineFilterMenu
        }
    }
    
    private var resetZoomButton: some View {
        Button(action: { withAnimation { zoomLevel = 1.0 } }) {
            Label("reset_zoom".localized, systemImage: "arrow.down.left.and.arrow.up.right")
        }
    }
    
    private var lineFilterMenu: some View {
        Menu {
            Text("lines_visibility".localized)
            Divider()
            ForEach(lines.lines) { line in
                Button(action: { toggleLineVisibility(line.id) }) {
                    HStack {
                        Text(line.name)
                        if !hiddenLineIds.contains(line.id) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            Button("show_all_button".localized) {
                hiddenLineIds.removeAll()
            }
        } label: {
            Label("filter_lines".localized, systemImage: "line.3.horizontal.decrease.circle")
        }
    }
    
    private func toggleLineVisibility(_ id: String) {
        if hiddenLineIds.contains(id) {
            hiddenLineIds.remove(id)
        } else {
            hiddenLineIds.insert(id)
        }
    }
}
