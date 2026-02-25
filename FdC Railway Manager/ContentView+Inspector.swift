import SwiftUI

extension ContentView {
    
    private var headerTitle: String {
        if appState.sidebarSelection == .io {
            return "io_title".localized
        }
        if appState.isCreatingLine {
            return "Crea Nuova Linea"
        }
        if appState.creationLineId != nil {
            return "Genera Orari"
        }
        return "details".localized
    }

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
                                 // Just clear the selection, don't close the inspector
                                 appState.selectedNodeId = nil
                                 appState.selectedEdgeId = nil
                                 appState.selectedFerroviaId = nil
                                 appState.selectedLineId = nil
                                 appState.selectedTrainIds.removeAll()
                                 appState.selectedVehicleId = nil
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

                Text(headerTitle)
                    .font(.system(.headline, design: .rounded))

                Spacer()

                Button(action: {
                    withAnimation {
                        if appState.isCreatingLine {
                            appState.isCreatingLine = false
                            appState.lineDraftStations.removeAll()
                            appState.stationPickingCallback = nil
                        } else if appState.creationLineId != nil {
                            // Close schedule creation view
                            appState.creationLineId = nil
                        } else if !appState.selectedTrainIds.isEmpty {
                            // Close train inspector view
                            appState.selectedTrainIds.removeAll()
                        } else if appState.selectedVehicleId != nil {
                            // Close vehicle inspector view
                            appState.selectedVehicleId = nil
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
                    inspectorForCurrentState()
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private func inspectorForCurrentState() -> some View {
        if appState.sidebarSelection == .io {
            IOManagementView()
                .id("io-management")
        } else if appState.isShowingSettings {
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
        } else if appState.isCreatingTrack {
            TrackCreationWizard()
                .id("track-creation")
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
            LineInspectorView(line: line)
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
                    .id("batch-train-edit")
            }
        } else {
            EmptyView()
        }
    }
}
