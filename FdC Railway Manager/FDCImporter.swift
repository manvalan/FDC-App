import Foundation
import SwiftUI

enum ImportStatus: Equatable {
    case idle
    case loading
    case success(summary: String)
    case failure(error: String)
}

@MainActor
class FDCImportViewModel: ObservableObject {
    @Published var status: ImportStatus = .idle
    // Reference to app network to populate
    var network: RailwayNetwork?

    init(network: RailwayNetwork? = nil) {
        self.network = network
    }

    func importBundledFDC(named name: String = "fdc2.fdc") async {
        status = .loading
        print("[FDCImportViewModel] Starting import of bundled file: \(name)")
        do {
            var fileURL: URL? = nil
            // direct lookup first
            if let u = Bundle.main.url(forResource: name, withExtension: nil) {
                fileURL = u
            } else {
                // fallback: search resources for any .fdc file
                if let resourceRoot = Bundle.main.resourceURL {
                    print("[FDCImportViewModel] resourceURL: \(resourceRoot.path), searching for .fdc files...")
                    let fm = FileManager.default
                    let enumerator = fm.enumerator(at: resourceRoot, includingPropertiesForKeys: nil)
                    while let item = enumerator?.nextObject() as? URL {
                        if item.pathExtension.lowercased() == "fdc" {
                            print("[FDCImportViewModel] Found .fdc file in bundle: \(item.path)")
                            fileURL = item
                            break
                        }
                    }
                } else {
                    print("[FDCImportViewModel] Bundle.resourceURL is nil; cannot search bundle resources")
                }
            }

            guard let url = fileURL else {
                status = .failure(error: "File \(name) non trovato nel bundle (neanche con ricerca)")
                print("[FDCImportViewModel] File not found in bundle after fallback search: \(name)")
                return
            }

            let data = try Data(contentsOf: url)
            print("[FDCImportViewModel] Read \(data.count) bytes from bundle file: \(url.path)")

            // Parse using FDCParser
            let parsed = try FDCParser.parse(data: data)
            print("[FDCImportViewModel] Parsed network: \(parsed.name) stations=\(parsed.stations.count) edges=\(parsed.edges.count) trains=\(parsed.trains.count)")

            // Map parsed into RailwayNetwork (ViewModel)
            let nodes = parsed.stations.map { Node(id: $0.id, name: $0.name, type: .station, latitude: nil, longitude: nil, capacity: nil, platforms: nil) }
            let edges = parsed.edges.map { Edge(from: $0.from, to: $0.to, distance: $0.distance ?? 1.0, trackType: .regional, maxSpeed: 120, capacity: nil) }
            if let network = self.network {
                network.name = parsed.name
                network.nodes = nodes
                network.edges = edges
                print("[FDCImportViewModel] Applied parsed network to RailwayNetwork instance")
            } else {
                print("[FDCImportViewModel] No network instance provided; parsed data not applied")
            }
            let summary = "Importati \(nodes.count) stazioni, \(edges.count) binari, \(parsed.trains.count) treni"
            status = .success(summary: summary)
            print("[FDCImportViewModel] Import success: \(summary)")
        } catch let err as NSError {
            status = .failure(error: err.localizedDescription)
            print("[FDCImportViewModel] Import failed NSError: \(err.localizedDescription)")
        } catch {
            status = .failure(error: error.localizedDescription)
            print("[FDCImportViewModel] Import failed: \(error.localizedDescription)")
        }
    }
}
