import SwiftUI

struct EditorToolboxView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: EditorModeViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Group {
                toolIcon(icon: "building.2.fill", help: "Nuova Stazione", active: viewModel.isWaitingForStationPlacement) {
                    viewModel.createStation()
                }
                
                toolIcon(icon: "tram.fill", help: "Nuovo Binario", active: appState.isCreatingTrack) {
                    withAnimation {
                        appState.isCreatingTrack.toggle()
                        if appState.isCreatingTrack {
                            appState.trackDraftFromId = nil
                            appState.trackDraftToId = nil
                            viewModel.clearSelection()
                        }
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
                
                toolIcon(icon: "arrow.up.and.down.and.sparkles", help: "Rilassa Layout (Molle)") {
                    viewModel.relaxNetworkLayout()
                }
                
                divider
                
                undoRedoControls
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.15), radius: 15, y: 5)
        .alert(
            "Impossibile creare la linea",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
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
                .font(.system(size: 20, weight: .bold))
                .frame(width: 44, height: 44)
                .background(active ? Color.blue : (isDestructive ? Color.red.opacity(0.1) : Color.primary.opacity(0.08)))
                .foregroundColor(active ? .white : (isDestructive ? .red : .primary))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
