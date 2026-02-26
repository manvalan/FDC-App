import SwiftUI
import UniformTypeIdentifiers
import CoreLocation

struct InfrastructurePayload: Codable {
    let nodes: [RailwayNode]
    let edges: [RailwayEdge]
}
