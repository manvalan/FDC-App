import Foundation

// DTO indipendente, non isolato al MainActor, usato per serializzazione/esportazione
struct RailwayNetworkDTO: Codable {
    let name: String
    let nodes: [Node]
    let edges: [Edge]
    let lines: [RailwayLine]?
}
