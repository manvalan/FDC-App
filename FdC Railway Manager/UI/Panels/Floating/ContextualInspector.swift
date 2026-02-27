import SwiftUI

struct ContextualInspector: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    @State private var isListEditMode: EditMode = .inactive
    
    var body: some View {
        VStack(spacing: 0) {
            InspectorHeaderView()
            
            Divider()
                .background(appState.theme.line.opacity(0.2))
                .padding(.horizontal, 16)
            
            InspectorTabSelector()
            
            inspectorContent
        }
        .frame(width: Layout.inspectorWidth)
        .frame(maxHeight: .infinity)
        .fixedSize(horizontal: true, vertical: false)
        .background(appState.theme.background)
        .cornerRadius(Layout.panelCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.panelCornerRadius)
                .stroke(appState.theme.line.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(Layout.shadowOpacity), radius: Layout.shadowRadius, x: 0, y: Layout.shadowY)
        .padding(.trailing, Layout.standardPadding)
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .gesture(DragGesture().onEnded { val in if val.translation.width > 30 { appState.showPanel(.none) } })
    }
    
    @ViewBuilder
    private var inspectorContent: some View {
        if appState.isCreatingLine {
            RouteCreationInspectorView()
        } else if appState.isCreatingTrack {
            trackCreationView
        } else if let node = appState.selectedNode {
            StationEditView(station: Binding(
                get: { node },
                set: { newNode in
                    if let idx = appState.railroad.network.nodes.firstIndex(where: { $0.id == node.id }) {
                        appState.railroad.network.nodes[idx] = newNode
                    }
                }
            ))
        } else if let line = appState.selectedLine {
            LineInspectorView(line: line)
        } else if let trainId = appState.selectedTrainIds.first,
                  let train = linesManager.trains.first(where: { $0.id == trainId }) {
            TrainDetailView(train: train)
        } else {
            InspectorListViews(isListEditMode: $isListEditMode)
        }
    }
    
    private var trackCreationView: some View {
        TrackCreationView(
            onBack: { appState.isCreatingTrack = false },
            onCreate: { appState.isCreatingTrack = false }
        )
    }
}

// Sub-components to keep line count low
struct LineInspectorView: View {
    @EnvironmentObject var appState: AppState
    let line: TrainRoute
    
    var body: some View {
        VStack(spacing: 0) {
            LineQuickStats(line: line).padding(16)
            Divider().padding(.horizontal, 16)
            
            switch appState.lineInspectorMode {
            case .infrastructure: LineInfrastructureView(line: line)
            case .schedule: LineScheduleSummaryView(line: line).padding(16)
            case .vehicles: LineVehiclesView(lineId: line.id)
            }
        }
    }
}
