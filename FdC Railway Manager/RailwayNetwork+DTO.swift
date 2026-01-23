import Foundation

extension RailwayNetwork {
    func toDTO() -> RailwayNetworkDTO {
        return RailwayNetworkDTO(name: self.name, nodes: self.nodes, edges: self.edges, lines: self.lines)
    }

    func apply(dto: RailwayNetworkDTO) {
        self.name = dto.name
        self.nodes = dto.nodes
        self.edges = dto.edges
        self.lines = dto.lines ?? []
    }
}
