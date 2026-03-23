import SwiftUI

struct TrackCreationOverlay: View {
    @EnvironmentObject var appState: AppState
    @Binding var editMode: MapEditMode
    @Binding var newTrackFrom: Node?
    @Binding var newTrackTo: Node?
    @Binding var newTrackDistance: Double
    @Binding var newTrackType: RailwayEdge.TrackType
    var onCreate: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Text("new_track".localized).font(.headline)
            
            HStack {
                stationInfo(label: "from_label".localized, node: newTrackFrom)
                Image(systemName: "arrow.right")
                stationInfo(label: "to_label".localized, node: newTrackTo, trailing: true)
            }
            .padding(.horizontal)
            
            distanceInput
            trackTypeSelector
            actionButtons
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 10)
        .padding(.horizontal)
        .frame(maxWidth: 400)
        .padding(.bottom, 100) // Spazio dal bordo inferiore
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func stationInfo(label: String, node: Node?, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(node?.name ?? "select_station_placeholder".localized)
                .fontWeight(.bold)
                .foregroundColor(node == nil ? .gray : .primary)
        }
        .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
    }
    
    private var distanceInput: some View {
        HStack {
            Text("distance_label".localized).font(.caption).foregroundColor(.secondary)
            TextField("km", value: $newTrackDistance, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
            Text("km")
        }
    }
    
    private var trackTypeSelector: some View {
        HStack(spacing: 8) {
            ForEach(RailwayEdge.TrackType.allCases) { type in
                Button(action: { newTrackType = type }) {
                    VStack(spacing: 4) {
                        trackIcon(type: type)
                        Text(type.displayName).font(.system(size: 10, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(newTrackType == type ? type.color.opacity(0.15) : Color.gray.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(newTrackType == type ? type.color : Color.clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func trackIcon(type: RailwayEdge.TrackType) -> some View {
        ZStack {
            if type == .highSpeed {
                HStack(spacing: 2) {
                    Capsule().fill(type.color).frame(width: 3, height: 16)
                    Capsule().fill(type.color).frame(width: 3, height: 16)
                }
            } else {
                Capsule().fill(type.color).frame(width: 6, height: 16)
            }
        }
    }
    
    private var actionButtons: some View {
        HStack {
            Button("close".localized) {
                editMode = .explore
            }
            .foregroundColor(.secondary)
            
            Button(action: onCreate) {
                Text("create_track_button".localized).bold().frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(newTrackFrom == nil || newTrackTo == nil)
        }
    }
}

struct StationPickingIndicator: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        if appState.stationPickingCallback != nil {
            HStack(spacing: 12) {
                Image(systemName: "cursorarrow.click.2").symbolEffect(.pulse).foregroundColor(.accentColor)
                Text("Seleziona una stazione sulla mappa").font(.system(size: 14, weight: .bold))
                Button(action: { withAnimation { appState.stationPickingCallback = nil } }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.ultraThinMaterial).clipShape(Capsule())
            .shadow(radius: 8)
            .padding(.top, 40)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
