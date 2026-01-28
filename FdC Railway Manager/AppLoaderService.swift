import Foundation
import SwiftUI
import Combine

@MainActor
class AppLoaderService: ObservableObject {
    @Published var isLoading = false
    let network: RailwayNetwork
    let trainManager: TrainManager
    let appState: AppState
    
    init(network: RailwayNetwork, trainManager: TrainManager, appState: AppState) {
        self.network = network
        self.trainManager = trainManager
        self.appState = appState
    }
    
    func performInitialLoad() async {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let lastStateURL = docs.appendingPathComponent("last_state.json")
        
        isLoading = true
        defer { isLoading = false }
        
        // 1. Check if we have a last session JSON (autosave)
        if FileManager.default.fileExists(atPath: lastStateURL.path) {
            do {
                let data = try Data(contentsOf: lastStateURL)
                
                // PIGNOLO PROTOCOL: Offload heavy decoding to background thread
                let dto = try await Task.detached(priority: .userInitiated) {
                    try JSONDecoder().decode(RailwayNetworkDTO.self, from: data)
                }.value
                
                // Load into models (on MainActor)
                network.name = dto.name
                network.nodes = dto.nodes
                network.edges = dto.edges
                network.lines = dto.lines ?? []
                trainManager.trains = dto.trains ?? []
                
                print("✅ Caricato ultimo stato da: \(lastStateURL.lastPathComponent)")
                trainManager.validateSchedules(with: network)
                
                // PIGNOLO PROTOCOL: Pre-populate simulator for map visualization
                appState.simulator.schedules = trainManager.generateSchedules(with: network)
                
                return
            } catch {
                print("❌ Errore caricamento ultimo stato: \(error)")
            }
        }
        
        // 2. Fallback to UserDefaults URL if present (manually opened file)
        if let lastURLString = UserDefaults.standard.string(forKey: "lastOpenedURL"),
           let lastURL = URL(string: lastURLString) {
            
            if lastURL.startAccessingSecurityScopedResource() {
                defer { lastURL.stopAccessingSecurityScopedResource() }
                do {
                    let data = try Data(contentsOf: lastURL)
                    // If we wanted to load this, we'd do the same background decode here
                } catch {
                    print("❌ Errore caricamento file UserDefaults: \(error)")
                }
            }
        }
    }
    
    func saveCurrentState() async {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let lastStateURL = docs.appendingPathComponent("last_state.json")
        
        let dto = RailwayNetworkDTO(
            name: network.name,
            nodes: network.nodes,
            edges: network.edges,
            lines: network.lines,
            trains: trainManager.trains
        )
        
        do {
            let data = try JSONEncoder().encode(dto)
            try data.write(to: lastStateURL)
            print("💾 Stato salvato correttamente in: \(lastStateURL.lastPathComponent)")
        } catch {
            print("❌ Errore salvataggio stato: \(error)")
        }
    }
}
