import SwiftUI

struct EditorToolboxView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: EditorModeViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Group {
                toolIcon(icon: "building.2.fill", help: "Nuova Stazione") {
                    viewModel.createStation()
                }
                
                toolIcon(icon: "tram.fill", help: "Nuovo Binario", active: appState.isCreatingTrack) {
                    appState.isCreatingTrack.toggle()
                    if appState.isCreatingTrack {
                        viewModel.clearSelection()
                    }
                }
                
                toolIcon(icon: "plus.rectangle.on.rectangle", help: "Crea Linea") {
                    if appState.selectedNodeIds.count > 1 {
                        viewModel.createNewRailwayLine()
                    }
                }
                .disabled(appState.selectedNodeIds.count < 2)
                
                divider
                
                toolIcon(icon: appState.isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle", 
                         help: "Multiselezione", active: appState.isMultiSelectMode) {
                    viewModel.toggleMultiSelect()
                }
                
                if viewModel.hasSelection {
                    toolIcon(icon: "trash", help: "Elimina", isDestructive: true) {
                        viewModel.deleteSelectedItems()
                    }
                }
                
                divider
                
                undoRedoControls
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
    
    private var divider: some View {
        Divider().frame(width: 30)
    }
    
    private var undoRedoControls: some View {
        Group {
            toolIcon(icon: "arrow.uturn.backward", help: "Annulla") {
                appState.railroad.network.undo()
            }
            .disabled(!appState.railroad.network.canUndo)
            .opacity(appState.railroad.network.canUndo ? 1.0 : 0.4)
            
            toolIcon(icon: "arrow.uturn.forward", help: "Ripristina") {
                appState.railroad.network.redo()
            }
            .disabled(!appState.railroad.network.canRedo)
            .opacity(appState.railroad.network.canRedo ? 1.0 : 0.4)
        }
    }
    
    private func toolIcon(icon: String, help: String, active: Bool = false, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .frame(width: 36, height: 36)
                .background(active ? Color.blue : (isDestructive ? Color.red.opacity(0.1) : Color.clear))
                .foregroundColor(active ? .white : (isDestructive ? .red : .primary))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
