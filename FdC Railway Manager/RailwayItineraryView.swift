import SwiftUI

struct RailwayItineraryView: View {
    @EnvironmentObject var appState: AppState
    @Binding var train: Train
    let network: RailwayNetwork
    let lineColor: Color?
    var isReadOnly: Bool = false
    
    // Focused Editing States
    @State private var editingTrackIndex: Int? = nil // Local variable for sheet mapping
    @State private var editingStopIndex: Int? = nil  // For popover anchoring
    
    var stations: [String] {
        train.stops.map { $0.stationId }
    }
    
    var trainConflicts: [ScheduleConflict] {
        appState.railroad.lines.conflictManager.conflicts.filter { $0.trainAId == train.id || $0.trainBId == train.id }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(train.stops.enumerated()), id: \.offset) { index, stop in
                let stopConflicts = trainConflicts.filter { $0.locationId.contains(stop.stationId) }
                
                ItineraryStepView(
                    index: index,
                    stop: stop,
                    train: $train,
                    network: network,
                    lineColor: lineColor ?? .green,
                    hasConflict: !stopConflicts.isEmpty,
                    isReadOnly: isReadOnly,
                    onTrackTap: { editingTrackIndex = index },
                    onTimeTap: { /* Inline editing handled in StationTimesView */ }
                )
                .zIndex(Double(train.stops.count - index))
            }
        }
        .padding()
        .background(Color.black)
        .cornerRadius(12)
        .sheet(item: $editingTrackIndex) { idx in
            if idx < train.stops.count {
                TrackSelectionSheet(
                    train: $train,
                    stopIndex: idx,
                    network: network
                )
                .presentationDetents([.height(300), .medium])
            }
        }
    }
    
    // MARK: - Subviews
    
    struct ItineraryStepView: View {
        let index: Int
        let stop: RelationStop
        @Binding var train: Train
        let network: RailwayNetwork
        let lineColor: Color
        let hasConflict: Bool
        let isReadOnly: Bool
        let onTrackTap: () -> Void
        let onTimeTap: () -> Void

        var body: some View {
            let isFirst = index == 0
            let isLast = index == train.stops.count - 1
            let nextId = isLast ? nil : train.stops[index + 1].stationId
            let isTransit = !isFirst && !isLast && stop.minDwellTime == 0

            VerticalDiagramStep(
                stationId: stop.stationId,
                network: network,
                isLast: isLast,
                nextStationId: nextId,
                lineColor: lineColor,
                isTransit: isTransit,
                isEditing: false, 
                leadingInfo: {
                    // LEFT: Time Schedule (Clickable)
                    StationTimesView(
                        train: $train,
                        index: index,
                        hasConflict: hasConflict,
                        isReadOnly: isReadOnly,
                        isLast: isLast,
                        onTap: onTimeTap
                    )
                },
                extraInfo: {
                    // RIGHT: Track Badge (Clickable)
                    TrackBadgeView(
                        stop: stop,
                        hasConflict: hasConflict,
                        isReadOnly: isReadOnly,
                        onTap: onTrackTap
                    )
                },
                segmentMetadata: {
                    if !isLast, let nextId = nextId {
                        let segmentDist = RailwayItineraryView.calculateSegmentDistance(from: stop.stationId, to: nextId, network: network)
                        
                        TrainSegmentMetadataView(
                            arrivalTime: nil,
                            departureTime: nil,
                            segmentDistance: segmentDist,
                            isOrigin: false,
                            isTerminus: (index + 1 == train.stops.count - 1)
                        )
                    }
                }
            )
        }
    }

    struct StationTimesView: View {
        @EnvironmentObject var appState: AppState
        @Binding var train: Train
        let index: Int
        let hasConflict: Bool
        let isReadOnly: Bool
        let isLast: Bool
        let onTap: () -> Void
        
        var body: some View {
            let stop = train.stops[index]
            let isOrigin = index == 0
            let isTerminus = isLast
            
            VStack(alignment: .trailing, spacing: 2) {
                if isOrigin {
                    timeDisplay(label: "Partenza", date: train.stops[index].plannedDeparture ?? stop.departure, isInteractive: !isReadOnly)
                } else if isTerminus {
                    timeDisplay(label: "Arrivo", date: stop.plannedArrival ?? stop.arrival, isInteractive: false) // Terminus arrival usually calculated
                } else {
                    timeDisplay(label: "Arr", date: stop.plannedArrival ?? stop.arrival, isInteractive: false)
                    timeDisplay(label: "Part", date: train.stops[index].plannedDeparture ?? stop.departure, isInteractive: !isReadOnly)
                }
            }
            .frame(width: 100, alignment: .trailing)
        }
        
        @ViewBuilder
        private func timeDisplay(label: String, date: Date?, isInteractive: Bool) -> some View {
            if let d = date {
                HStack(spacing: 0) {
                    if isInteractive {
                        DatePicker("", selection: Binding(
                            get: { d },
                            set: { newValue in
                                let normalized = newValue.normalized().cleanSeconds()
                                
                                // Calculate and save the dwell time delta
                                if let currentArrival = train.stops[index].arrival {
                                    let dwellSeconds = normalized.timeIntervalSince(currentArrival)
                                    train.stops[index].customDwellSeconds = max(0, dwellSeconds)
                                }
                                
                                // Remove plannedDeparture - we only preserve the delta
                                train.stops[index].plannedDeparture = nil
                                
                                if index == 0 {
                                    train.departureTime = normalized
                                }
                                appState.railroad.lines.validateSchedules()
                            }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .scaleEffect(0.9)
                        .frame(width: 90, height: 32)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(6)
                        .onLongPressGesture(minimumDuration: 0.5) {
                            withAnimation {
                                train.stops[index].plannedDeparture = nil
                                appState.railroad.lines.validateSchedules()
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                    } else {
                        Text(d.timeFormat)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(hasConflict ? .red : (train.stops[index].customDwellSeconds != nil && label == "Part" ? .yellow : .white))
                            .padding(2)
                    }
                }
            } else {
                Text("--:--")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.gray)
        }
    }
    }

    struct TrackBadgeView: View {
        let stop: RelationStop
        let hasConflict: Bool
        let isReadOnly: Bool
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 6) {
                    Text(stop.track ?? "1")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(hasConflict ? .white : .black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(hasConflict ? Color.red : Color.orange)
                        .cornerRadius(4)
                    
                    if !isReadOnly {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isReadOnly)
        }
    }
    
    private static func calculateSegmentDistance(from: String, to: String, network: RailwayNetwork) -> Double {
        if let edge = network.edges.first(where: { ($0.from == from && $0.to == to) || ($0.from == to && $0.to == from) }) {
            return edge.distance
        }
        return 0.0
    }
}

// MARK: - Specialized Sheets

struct TrackSelectionSheet: View {
    @Binding var train: Train
    let stopIndex: Int
    let network: RailwayNetwork
    @Environment(\.dismiss) var dismiss
    
    private var stop: RelationStop { train.stops[stopIndex] }
    private var node: Node? { network.nodes.first(where: { $0.id == stop.stationId }) }
    private var prevId: String? { stopIndex > 0 ? train.stops[stopIndex - 1].stationId : nil }
    private var nextId: String? { stopIndex < train.stops.count - 1 ? train.stops[stopIndex + 1].stationId : nil }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let node = node {
                    trackSelectionContent(node: node)
                } else {
                    Text("Stazione non trovata")
                }
            }
            .padding()
            .navigationTitle("Scelta Binario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
    }
    
    @ViewBuilder
    private func trackSelectionContent(node: Node) -> some View {
        let preferred = train.getPreferredTracks(at: node, prevStationId: prevId, nextStationId: nextId, for: nil)
        
        Text("Binari consigliati per \(node.name)")
            .font(.subheadline)
            .foregroundColor(.secondary)
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                ForEach(preferred, id: \.self) { track in
                    trackButton(track: track, node: node)
                }
            }
            .padding()
        }
        
        Spacer()
        
        Button("Chiudi") { dismiss() }
            .buttonStyle(.bordered)
    }
    
    @ViewBuilder
    private func trackButton(track: String, node: Node) -> some View {
        let isSelected = stop.track == track
        let isPreferred = train.isTrackPreferred(track, at: node, prevStationId: prevId, nextStationId: nextId, for: nil)
        
        Button(action: {
            train.stops[stopIndex].track = track
            train.stops[stopIndex].isManualTrack = true
            dismiss()
        }) {
            VStack {
                Text(track)
                    .font(.title2.bold())
                Text("Binario")
                    .font(.caption2.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : (isPreferred ? .purple : .white))
            .frame(width: 70, height: 70)
            .background(isSelected ? Color.blue : (isPreferred ? Color.purple.opacity(0.3) : Color.gray.opacity(0.3)))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.blue : (isPreferred ? Color.purple : Color.clear), lineWidth: 3)
            )
            .shadow(radius: isSelected ? 4 : (isPreferred ? 3 : 0))
        }
    }
}


