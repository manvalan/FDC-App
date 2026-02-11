import SwiftUI

extension ContentView {
    
    @ViewBuilder
    var sidebarPropertiesContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("details".localized)
                    .font(.headline)
                Spacer()
                Button(action: {
                    withAnimation {
                        appState.clearSelection()
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.fdcGreyMedium)
                }
                .buttonStyle(.plain)
            }
            .padding()
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    if let node = appState.selectedNode, let index = network.nodes.firstIndex(where: { $0.id == node.id }) {
                        StationEditView(
                            station: Binding(
                                get: { network.nodes[index] },
                                set: { network.nodes[index] = $0 }
                            ),
                            isMoveModeEnabled: $appState.isMoveModeEnabled,
                            onDelete: {
                                withAnimation {
                                    network.removeNode(node.id)
                                    appState.selectedNodeId = nil
                                }
                            }
                        )
                        .id("node-\(node.id)")
                    } else if let line = appState.selectedLine {
                        LineDetailView(line: Binding(
                            get: { line },
                            set: { newVal in
                                if let idx = lines.lines.firstIndex(where: { $0.id == line.id }) {
                                    lines.lines[idx] = newVal
                                    appState.selectedLineId = newVal.id
                                }
                            }
                        ), isMoveModeEnabled: $appState.isMoveModeEnabled, selectedNode: Binding(get: { appState.selectedNode }, set: { appState.selectedNodeId = $0?.id }), selectedEdgeId: $appState.selectedEdgeId)
                        .id("line-\(line.id)")
                    } else if let edgeId = appState.selectedEdgeId, let index = network.edges.firstIndex(where: { $0.id.uuidString == edgeId }) {
                        TrackEditView(
                            edge: Binding(
                                get: { network.edges[index] },
                                set: { network.edges[index] = $0 }
                            ),
                            onDelete: {
                                withAnimation {
                                    network.removeEdge(from: network.edges[index].from, to: network.edges[index].to)
                                    appState.selectedEdgeId = nil
                                }
                            },
                            onBack: {
                                withAnimation {
                                    appState.selectedEdgeId = nil
                                }
                            }
                        )
                        .id("edge-\(edgeId)")
                    } else if !appState.selectedTrainIds.isEmpty {
                        if appState.selectedTrainIds.count == 1, let trainId = appState.selectedTrainIds.first, let train = trainManager.trains.first(where: { $0.id == trainId }) {
                            TrainDetailView(train: train)
                                .id("train-\(trainId)")
                        } else {
                            BatchTrainEditView(selectedIds: $appState.selectedTrainIds)
                        }
                    }
                }
                .padding()
            }
        }
    }
}
