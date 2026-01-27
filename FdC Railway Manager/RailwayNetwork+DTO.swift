import Foundation

extension RailwayNetwork {
    func toDTO(with trains: [Train]? = nil) -> RailwayNetworkDTO {
        return RailwayNetworkDTO(name: self.name, nodes: self.nodes, edges: self.edges, lines: self.lines, relations: self.relations, trains: trains)
    }

    func apply(dto: RailwayNetworkDTO) {
        self.name = dto.name
        self.nodes = dto.nodes
        self.edges = dto.edges
        self.lines = dto.lines ?? []
        self.relations = dto.relations ?? []
    }
}
