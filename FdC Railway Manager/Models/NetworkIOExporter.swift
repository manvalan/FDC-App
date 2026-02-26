import Foundation
import SwiftUI
import Combine

final class NetworkIOExporter {
    static let shared = NetworkIOExporter()
    private init() {}

    /// Returns JSON Data with only stations (nodes) and tracks (edges)
    func exportStationsAndTracksJSON(nodes: [Node], edges: [Edge]) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        struct Payload: Encodable {
            let nodes: [Node]
            let edges: [Edge]
        }
        let payload = Payload(nodes: nodes, edges: edges)
        return try? encoder.encode(payload)
    }

    /// Convenience string version
    func exportString(nodes: [Node], edges: [Edge]) -> String? {
        guard let data = exportStationsAndTracksJSON(nodes: nodes, edges: edges) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
