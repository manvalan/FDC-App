import SwiftUI
import Combine

@MainActor
class StationEditViewModel: ObservableObject {
    @Published var appState: AppState
    
    init(appState: AppState = AppState.shared) {
        self.appState = appState
    }
    
    private var network: NetworkModel { appState.railroad.network }
    private var lines: LinesManager { appState.railroad.lines }

    struct DirectionGroup: Identifiable {
        let id: String // ID nodo destinazione o "terminus"
        let name: String
        let routes: [TrainRoute]
    }

    func calculateDirectionGroups(for stationId: String) -> [DirectionGroup] {
        let stationRoutes = lines.routes.filter { $0.stationIds.contains(stationId) }
        var groupsMap: [String: Set<String>] = [:]
        
        for route in stationRoutes {
            let neighborIds = route.stationIds.enumerated().flatMap { (idx, sId) -> [String] in
                guard sId == stationId else { return [] }
                var result: [String] = []
                if idx > 0 { result.append(route.stationIds[idx - 1]) }
                if idx < route.stationIds.count - 1 { result.append(route.stationIds[idx + 1]) }
                return result
            }
            
            if neighborIds.isEmpty {
                groupsMap["terminus", default: Set()].insert(route.id)
            } else {
                for nid in neighborIds {
                    groupsMap[nid, default: Set()].insert(route.id)
                }
            }
        }
        
        return groupsMap.map { (key, routeIds) in
            let name = key == "terminus" ? "Terminus / No neighbors" : (network.nodes.first(where: { $0.id == key })?.name ?? key)
            let groupRoutes = lines.routes.filter { routeIds.contains($0.id) }.sorted { $0.name < $1.name }
            return DirectionGroup(id: key, name: name, routes: groupRoutes)
        }.sorted { $0.name < $1.name }
    }

    func updateTracks(station: inout RailwayNode, localConstraints: inout [RoutingConstraint], routeId: String, directionId: String?, tracks: [String], type: TrackConfigType) {
        if let idx = localConstraints.firstIndex(where: { $0.routeId == routeId && $0.directionStationId == directionId }) {
            switch type {
            case .allowed: localConstraints[idx].allowedTracks = tracks
            case .transit: localConstraints[idx].transitTracks = tracks
            case .stop: localConstraints[idx].stopTracks = tracks
            }
            if localConstraints[idx].isEffectivelyEmpty {
                localConstraints.remove(at: idx)
            }
        } else if !tracks.isEmpty {
            var newC = RoutingConstraint(routeId: routeId, directionStationId: directionId, allowedTracks: [])
            switch type {
            case .allowed: newC.allowedTracks = tracks
            case .transit: newC.transitTracks = tracks
            case .stop: newC.stopTracks = tracks
            }
            localConstraints.append(newC)
        }
        station.routingConstraints = localConstraints
    }

    enum TrackConfigType { case allowed, transit, stop }
}

extension RoutingConstraint {
    var isEffectivelyEmpty: Bool {
        allowedTracks.isEmpty && (transitTracks?.isEmpty ?? true) && (stopTracks?.isEmpty ?? true)
    }
}
