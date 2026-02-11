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
        VStack(spacing: 16) { // Increased spacing between stations
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
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(appState.isInspectorEditingMode ? Color.blue.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
        )
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
        @EnvironmentObject var appState: AppState // Added for theme access
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
            HStack(alignment: .center, spacing: 12) {
                // STATION NAME (Left)
                if let node = network.nodes.first(where: { $0.id == stop.stationId }) {
                    Text(node.name)
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(appState.theme.dark)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(stop.stationId)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // TIMES & TRACK (Right)
                HStack(alignment: .center, spacing: 20) {
                    
                    // Times
                    StationTimesView(
                        train: $train,
                        index: index,
                        hasConflict: hasConflict,
                        isReadOnly: isReadOnly,
                        isLast: isLast,
                        onTap: onTimeTap
                    )
                    
                    // Track
                    TrackBadgeView(
                        stop: stop,
                        hasConflict: hasConflict,
                        isReadOnly: isReadOnly,
                        onTap: onTrackTap
                    )
                }
            }
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(index % 2 == 0 ? Color.clear : Color.secondary.opacity(0.03))
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
            
            VStack(alignment: .leading, spacing: 2) {
                if isOrigin {
                    timeDisplay(label: "Partenza", date: train.stops[index].plannedDeparture ?? stop.departure, isInteractive: !isReadOnly)
                } else if isTerminus {
                    timeDisplay(label: "Arrivo", date: stop.plannedArrival ?? stop.arrival, isInteractive: false)
                } else {
                    timeDisplay(label: "Arr:", date: stop.plannedArrival ?? stop.arrival, isInteractive: false)
                    timeDisplay(label: "Part:", date: train.stops[index].plannedDeparture ?? stop.departure, isInteractive: !isReadOnly)
                }
            }
            .frame(minWidth: 100, alignment: .leading)
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
                        HStack(spacing: 4) {
                            Text(label)
                                .font(.system(size: 12)) // Larger label (was 11)
                                .foregroundColor(.secondary)
                            Text(d.timeFormat)
                                .font(.system(size: 16, weight: .bold, design: .monospaced)) // Larger time (was 13)
                                .foregroundColor(hasConflict ? .red : (train.stops[index].customDwellSeconds != nil && (label == "Part:" || label == "Partenza") ? .yellow : appState.theme.dark.opacity(0.9)))
                        }
                    }
                }
            } else {
                Text("--:--")
                    .font(.system(size: 16, design: .monospaced)) // Larger placeholder
                    .foregroundColor(.gray.opacity(0.5))
            }
    }
    }

    struct TrackBadgeView: View {
        @EnvironmentObject var appState: AppState // Added for theme access
        let stop: RelationStop
        let hasConflict: Bool
        let isReadOnly: Bool
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 6) {
                    Text("Bin \(stop.track ?? "1")") // Shortened label
                        .font(.system(size: 14, weight: .bold, design: .rounded)) // Larger font (was 11)
                        .foregroundColor(hasConflict ? .white : appState.theme.dark)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(hasConflict ? Color.red : Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let node = node {
                        trackSelectionContent(node: node)
                    } else {
                        ContentUnavailableView("Stazione non trovata", systemImage: "exclamationmark.triangle")
                    }
                }
                .padding()
            }
            .navigationTitle("Scelta Binario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    @ViewBuilder
    private func trackSelectionContent(node: Node) -> some View {
        let preferred = train.getPreferredTracks(at: node, prevStationId: prevId, nextStationId: nextId, for: nil)
        let totalTracks = node.platforms ?? 2
        let allTracks = (1...totalTracks).map { String($0) }
        
        // SECTION 1: PREFERRED
        if !preferred.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Consigliati", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundColor(.purple)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                    ForEach(preferred, id: \.self) { track in
                        trackButton(track: track, node: node, isPreferred: true)
                    }
                }
            }
        }
        
        Divider()
        
        // SECTION 2: ALL TRACKS
        VStack(alignment: .leading, spacing: 10) {
            Label("Tutti i Binari", systemImage: "tram.fill")
                .font(.headline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                ForEach(allTracks, id: \.self) { track in
                    trackButton(track: track, node: node, isPreferred: preferred.contains(track))
                }
            }
        }
    }
    
    @ViewBuilder
    private func trackButton(track: String, node: Node, isPreferred: Bool) -> some View {
        let isSelected = stop.track == track
        
        Button(action: {
            train.stops[stopIndex].track = track
            train.stops[stopIndex].isManualTrack = true
            dismiss()
        }) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 2) {
                    Text(track)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                    
                    Text(isSelected ? "ATTUALE" : (isPreferred ? "OTTIMO" : "BIN"))
                        .font(.system(size: 8, weight: .black))
                        .opacity(0.8)
                }
                .frame(width: 70, height: 70)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.blue : (isPreferred ? Color.purple.opacity(0.1) : Color(UIColor.secondarySystemBackground)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.blue : (isPreferred ? Color.purple.opacity(0.4) : Color.clear), lineWidth: isSelected ? 0 : 2)
                )
                
                // BADGES
                Group {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .blue)
                            .font(.system(size: 18))
                            .offset(x: 6, y: -6)
                    } else if isPreferred {
                        Image(systemName: "star.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 14))
                            .offset(x: 5, y: -5)
                    }
                }
            }
            .foregroundColor(isSelected ? .white : (isPreferred ? .purple : .primary))
            .shadow(color: isSelected ? Color.blue.opacity(0.3) : (isPreferred ? Color.purple.opacity(0.1) : Color.clear), radius: 6, x: 0, y: 3)
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}


