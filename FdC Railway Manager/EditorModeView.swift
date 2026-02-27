import SwiftUI

struct EditorModeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loader: AppLoaderService
    @StateObject private var viewModel: EditorModeViewModel
    
    @State private var lockedNodeIds: Set<String> = []
    
    init() {
        _viewModel = StateObject(wrappedValue: EditorModeViewModel())
    }
    
    // Custom initializer to inject AppState if needed
    init(appState: AppState) {
        _viewModel = StateObject(wrappedValue: EditorModeViewModel(appState: appState))
    }

    var body: some View {
        EditorPrimaryContent(viewModel: viewModel, lockedNodeIds: $lockedNodeIds)
            .background(Color.white.ignoresSafeArea())
            .overlay(alignment: .topTrailing) {
                EditorSubModePicker()
                    .padding()
            }
            .overlay(alignment: .bottom) {
                bottomOverlays
            }
            .overlay(alignment: .bottomTrailing) {
                EditorToolboxView(viewModel: viewModel)
                    .padding(.trailing, 16)
                    .padding(.bottom, 320) // Spostato più in su per evitare i controlli della mappa e FloatingMenu
            }
            .onAppear {
                // Re-sync viewModel with the actual environment appState if necessary
                viewModel.appState = appState
                appState.currentMode = .editor
            }
    }
    
    @ViewBuilder
    private var bottomOverlays: some View {
        VStack {
            let showProfile = appState.designSubMode == .services && !appState.isMultiSelectMode && viewModel.hasSelection
            
            FdCBottomPanel(
                isPresented: .constant(showProfile),
                title: "Profilo Altimetrico",
                preferredHeight: 380
            ) {
                AltimetricProfileView(lockedNodeIds: $lockedNodeIds)
            }
            
            if !showProfile && viewModel.hasSelection && appState.activePanel != .inspector {
                FdCInspectorPanel(
                    title: appState.selectedNode?.name ?? "Proprietà",
                    onClose: { viewModel.clearSelection() }
                ) {
                    EditorInspectorContent(editingLineId: .constant(nil))
                }
                .transition(.move(edge: .bottom))
            }
        }
    }
}

struct EditorPrimaryContent: View {
    @ObservedObject var viewModel: EditorModeViewModel
    @Binding var lockedNodeIds: Set<String>
    
    var body: some View {
        if viewModel.appState.designSubMode == .infrastructure {
            RailwayMapView(
                selectedNode: Binding(get: { viewModel.appState.selectedNode }, set: { viewModel.appState.selectedNodeId = $0?.id }),
                selectedLine: Binding(get: { viewModel.appState.selectedInfraLine }, set: { viewModel.appState.selectedInfraLineId = $0?.id }),
                selectedEdgeId: $viewModel.appState.selectedEdgeId,
                showGrid: $viewModel.appState.showGrid,
                highlightedConflictLocation: .constant(nil),
                mode: $viewModel.appState.mapVisualizationMode
            )
        } else {
            VStack(spacing: 0) {
                Color.white.frame(height: 100)
                AltimetricProfileView(lockedNodeIds: $lockedNodeIds)
            }
        }
    }
}
