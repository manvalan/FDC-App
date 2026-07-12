import Foundation

/// DTO per import/export JSON della rete ferroviaria.
public struct RailwayNetworkDTO: Codable {
    public var name: String? = nil
    public let nodes: [Node]
    public let edges: [Edge]
    /// Linee fisiche (ex `ferrovie`). Chiave JSON `"ferrovie"` per compatibilità.
    public var lines: [RailwayLine]? = nil
    /// Template di servizio (ex `lines`). Chiave JSON `"lines"` per compatibilità.
    public var routes: [TrainRoute]? = nil
    public var trains: [Train]? = nil
    public var vehicles: [Vehicle]? = nil

    enum CodingKeys: String, CodingKey {
        case name, nodes, edges
        case lines = "ferrovie"
        case routes = "lines"
        case trains, vehicles
    }

    public init(
        name: String? = nil,
        nodes: [Node],
        edges: [Edge],
        lines: [RailwayLine]? = nil,
        routes: [TrainRoute]? = nil,
        trains: [Train]? = nil,
        vehicles: [Vehicle]? = nil
    ) {
        self.name = name
        self.nodes = nodes
        self.edges = edges
        self.lines = lines
        self.routes = routes
        self.trains = trains
        self.vehicles = vehicles
    }
}
