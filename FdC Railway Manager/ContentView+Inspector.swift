import SwiftUI

extension ContentView {
    
    @ViewBuilder
    var sidebarPropertiesContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if appState.creationLineId != nil || appState.selectedTrainIds.count > 0 || appState.selectedNodeId != nil || appState.selectedEdgeId != nil || appState.isCreatingLine {
                     Button(action: {
                         withAnimation {
                             if appState.creationLineId != nil {
                                 appState.creationLineId = nil
                             } else if appState.isCreatingLine {
                                 appState.isCreatingLine = false
                                 appState.lineDraftStations.removeAll()
                                 appState.stationPickingCallback = nil
                             } else {
                                 appState.clearSelection()
                             }
                         }
                     }) {
                         Image(systemName: "chevron.left")
                             .font(.system(size: 14, weight: .bold))
                             .foregroundColor(.primary)
                             .padding(8)
                             .background(Circle().fill(Color.primary.opacity(0.1)))
                     }
                     .buttonStyle(.plain)
                }

                Text(appState.isCreatingLine ? "Crea Nuova Linea" : (appState.creationLineId != nil ? "Genera Orari" : "details".localized))
                    .font(.system(.headline, design: .rounded))

                Spacer()

                Button(action: {
                    withAnimation {
                        if appState.isCreatingLine {
                            appState.isCreatingLine = false
                            appState.lineDraftStations.removeAll()
                            appState.stationPickingCallback = nil
                        } else {
                            appState.clearSelection()
                        }
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.5))
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    if appState.isShowingSettings {
                        SettingsInspectorView()
                            .id("settings")
                    } else if let previewData = appState.optimizedTimesPreviewData {
                        OptimizedTimesPreviewInspectorView(
                            line: previewData.line,
                            mode: previewData.mode,
                            currentOutboundTime: previewData.currentOutboundTime,
                            currentReturnTime: previewData.currentReturnTime,
                            proposedOutboundTime: previewData.proposedOutboundTime,
                            proposedReturnTime: previewData.proposedReturnTime,
                            proposedInterval: previewData.proposedInterval,
                            proposedReturnInterval: previewData.proposedReturnInterval
                        )
                        .id("optimized-times-preview")
                    } else if let trains = appState.schedulePreviewTrains, let line = appState.schedulePreviewLine {
                        SchedulePreviewInspectorView(
                            trains: trains,
                            line: line,
                            mode: appState.schedulePreviewMode
                        )
                        .id("schedule-preview")
                    } else if appState.isCreatingLine {
                        LineCreationInspectorView()
                            .id("line-creation")
                    } else if let lineId = appState.creationLineId, let line = appState.railroad.lines.lines.first(where: { $0.id == lineId }) {
                        ScheduleCreationView(line: line)
                            .id("create-schedule-\(lineId)")
                    } else if let node = appState.selectedNode, let index = network.nodes.firstIndex(where: { $0.id == node.id }) {
                        StationInspectorView(
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
                        TrackInspectorView(
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
                            TrainInspectorView(train: train)
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
