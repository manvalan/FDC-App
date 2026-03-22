import Foundation

// MARK: - File I/O Extensions for NetworkModel
extension NetworkModel {
    static func loadFromFile(url: URL) throws -> NetworkModel {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let dto = try decoder.decode(RailwayNetworkDTO.self, from: data)
        let network = NetworkModel()
        network.apply(dto: dto)
        return network
    }
    
    func saveToFile(url: URL) throws {
        // Saves nodes, edges, infrastructure lines and service routes.
        // Note: trains are saved via LinesManager/TrainManager separately.
        let dto = RailwayNetworkDTO(name: name, nodes: nodes, edges: edges)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(dto)
        try data.write(to: url)
    }
}

extension NetworkModel {
    func toDTO() -> RailwayNetworkDTO {
        return RailwayNetworkDTO(name: name, nodes: nodes, edges: edges)
    }
    
    func apply(dto: RailwayNetworkDTO) {
        self.name = dto.name ?? "Network"
        self.nodes = dto.nodes
        self.edges = dto.edges
        self.lines  = dto.lines  ?? []
        self.routes = dto.routes ?? []
    }
}
