import SwiftUI

struct RoutingConstraintsSheet: View {
    @Binding var station: RailwayNode
    @Binding var localConstraints: [RoutingConstraint]
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: StationEditViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                infoHeader
                constraintsList
            }
            .navigationTitle("routing_constraints".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) { dismiss() }
                }
            }
        }
    }
    
    private var infoHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(station.name).font(.headline).foregroundColor(appState.theme.accent)
            Text("Scegli una direzione per configurare i binari dedicati alle linee corrispondenti.").font(.caption).foregroundColor(appState.theme.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(UIColor.secondarySystemBackground))
    }
    
    private var constraintsList: some View {
        List {
            let groups = viewModel.calculateDirectionGroups(for: station.id)
            if groups.isEmpty {
                Text("Nessuna linea attraversa questa stazione.").foregroundColor(appState.theme.medium).padding()
            }
            
            ForEach(groups) { group in
                Section(header: Text("Collegamento: \(group.name)").font(.caption.bold()).foregroundColor(appState.theme.accent)) {
                    ForEach(group.routes) { route in
                        let dirId: String? = (group.id == "terminus" ? nil : group.id)
                        RoutingLineRow(
                            route: route,
                            allowedTracks: Binding(
                                get: { localConstraints.first { $0.routeId == route.id && $0.directionStationId == dirId }?.allowedTracks ?? [] },
                                set: { viewModel.updateTracks(station: &station, localConstraints: &localConstraints, routeId: route.id, directionId: dirId, tracks: $0, type: .allowed) }
                            ),
                            transitTracks: Binding(
                                get: { localConstraints.first { $0.routeId == route.id && $0.directionStationId == dirId }?.transitTracks ?? [] },
                                set: { viewModel.updateTracks(station: &station, localConstraints: &localConstraints, routeId: route.id, directionId: dirId, tracks: $0, type: .transit) }
                            ),
                            stopTracks: Binding(
                                get: { localConstraints.first { $0.routeId == route.id && $0.directionStationId == dirId }?.stopTracks ?? [] },
                                set: { viewModel.updateTracks(station: &station, localConstraints: &localConstraints, routeId: route.id, directionId: dirId, tracks: $0, type: .stop) }
                            ),
                            totalPlatforms: station.platforms ?? 2
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - ROW View semplificata per linea e direzione
struct RoutingLineRow: View {
    @EnvironmentObject var appState: AppState
    let route: TrainRoute
    @Binding var allowedTracks: [String]
    @Binding var transitTracks: [String]
    @Binding var stopTracks: [String]
    let totalPlatforms: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: route.color ?? "#666666") ?? .gray).frame(width: 8, height: 8)
                    Text(route.name).font(.subheadline.bold())
                }
                Spacer()
            }
            
            // 1. Binari per Transito
            VStack(alignment: .leading, spacing: 4) {
                Label("Transito (Prioritario)", systemImage: "bolt.horizontal.fill")
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.orange)
                trackSelector(for: $transitTracks, color: .orange)
            }
            
            // 2. Binari per Sosta / Origine
            VStack(alignment: .leading, spacing: 4) {
                Label("Sosta / Origine (Prioritario)", systemImage: "parkingsign.circle.fill")
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.blue)
                trackSelector(for: $stopTracks, color: .blue)
            }
            
            // 3. Altri binari ammessi
            VStack(alignment: .leading, spacing: 4) {
                Label("Ammessi (Generico)", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                trackSelector(for: $allowedTracks, color: appState.theme.accent)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func trackSelector(for tracks: Binding<[String]>, color: Color) -> some View {
        HStack(spacing: 6) {
            ForEach(1...totalPlatforms, id: \.self) { num in
                let track = "\(num)"
                let isSelected = tracks.wrappedValue.contains(track)
                
                Button(action: {
                    if isSelected {
                        tracks.wrappedValue.removeAll { $0 == track }
                    } else {
                        tracks.wrappedValue.append(track)
                    }
                }) {
                    Text(track)
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(isSelected ? color : appState.theme.backgroundSecondary)
                        .foregroundColor(isSelected ? .white : appState.theme.dark)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
