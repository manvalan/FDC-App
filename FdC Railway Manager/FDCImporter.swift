import Foundation
import SwiftUI
import Combine

enum ImportStatus: Equatable {
    case idle
    case loading
    case success(summary: String)
    case failure(error: String)
}

@MainActor
class FDCImportViewModel: ObservableObject {
    @Published var status: ImportStatus = .idle
    // Reference to app state to populate
    var network: RailwayNetwork?
    var trainManager: TrainManager?
    var appState: AppState?

    init(network: RailwayNetwork? = nil, trainManager: TrainManager? = nil, appState: AppState? = nil) {
        self.network = network
        self.trainManager = trainManager
        self.appState = appState
    }

    func importBundledFDC(named name: String = "fdc2.fdc") async {
        status = .loading
        do {
            var fileURL: URL? = Bundle.main.url(forResource: name, withExtension: nil)
            
            if fileURL == nil {
                // fallback: search resources for any .fdc file
                if let resourceRoot = Bundle.main.resourceURL,
                   let enumerator = FileManager.default.enumerator(at: resourceRoot, includingPropertiesForKeys: nil) {
                    while let item = enumerator.nextObject() as? URL {
                        if item.pathExtension.lowercased() == "fdc" {
                            fileURL = item
                            break
                        }
                    }
                }
            }

            guard let url = fileURL else {
                status = .failure(error: "File \(name) non trovato nel bundle")
                return
            }

            let data = try Data(contentsOf: url)
            
            // Delegate logic to aggregate root
            guard let railroad = appState?.railroad else {
                status = .failure(error: "Stato applicazione non disponibile")
                return
            }
            
            try railroad.io.importFromFDC(data: data)
            
            // Sync back to legacy models
            if let network = self.network, let tm = self.trainManager {
                network.nodes = railroad.network.nodes
                network.edges = railroad.network.edges
                // network.lines has been migrated to railroad.lines
                tm.trains = railroad.lines.trains
                
                // Update simulator view
                appState?.simulator.schedules = railroad.lines.generateSchedulesPreview()
            }
            
            let summary = "Importati \(railroad.network.nodes.count) stazioni, \(railroad.network.edges.count) binari, \(railroad.lines.lines.count) linee, \(railroad.lines.trains.count) treni"
            status = .success(summary: summary)
        } catch {
            status = .failure(error: error.localizedDescription)
            print("[FDCImportViewModel] Import failed: \(error.localizedDescription)")
        }
    }
}
