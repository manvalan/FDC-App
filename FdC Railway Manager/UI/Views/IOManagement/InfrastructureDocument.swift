import SwiftUI
import UniformTypeIdentifiers
import CoreLocation

struct InfrastructureDocument: @preconcurrency FileDocument {
    static var readableContentTypes: [UTType] { [UTType.json] }
    private var nodes: [RailwayNode]
    private var edges: [RailwayEdge]

    init(nodes: [RailwayNode], edges: [RailwayEdge]) {
        self.nodes = nodes
        self.edges = edges
    }

    init(configuration: ReadConfiguration) throws {
        guard configuration.file.regularFileContents != nil else { throw CocoaError(.fileReadCorruptFile) }
        self.nodes = []
        self.edges = []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        struct Payload: Encodable {
            let nodes: [Node]
            let edges: [Edge]
        }
        let payload = Payload(nodes: nodes, edges: edges)
        let data = try encoder.encode(payload)
        return .init(regularFileWithContents: data)
    }
}
