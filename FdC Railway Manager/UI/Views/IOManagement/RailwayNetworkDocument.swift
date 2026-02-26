import SwiftUI
import UniformTypeIdentifiers
import CoreLocation

struct RailwayNetworkDocument: @preconcurrency FileDocument {
    static var readableContentTypes: [UTType] { [UTType.json, UTType.fdc, UTType.railml, UTType.rail] }
    var dto: RailwayNetworkDTO
    
    @MainActor
    init(network: NetworkModel, lines: [TrainRoute], trains: [RailwayTrain]) { 
        self.dto = RailwayNetworkDTO(name: network.name, nodes: network.nodes, edges: network.edges, lines: network.lines, routes: lines, trains: trains)
    }
    
    @MainActor
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        let decoder = JSONDecoder()
        
        if let container = try? decoder.decode(RailFileContainer.self, from: data) {
            self.dto = container.network
            return
        }
        
        if let dto = try? decoder.decode(RailwayNetworkDTO.self, from: data) {
            self.dto = dto
            return
        }
        
        throw CocoaError(.fileReadCorruptFile)
    }
    
    @MainActor
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        if configuration.contentType == .rail {
            let container = RailFileContainer(
                formatVersion: "2.0",
                qualifier: "FDC_RAIL_V2_QUALIFIED",
                network: dto,
                metadata: RailMetadata(
                    createdBy: "FdC Manager App",
                    createdAt: Date(),
                    lastModified: Date(),
                    description: "Qualified output for AI Pignolo Protocol"
                )
            )
            let data = try encoder.encode(container)
            return .init(regularFileWithContents: data)
        } else {
            let data = try encoder.encode(dto)
            return .init(regularFileWithContents: data)
        }
    }
}
