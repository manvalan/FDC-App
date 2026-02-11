import Foundation
import Combine

/// AI: Moduli di Intelligenza Artificiale per l'analisi e l'ottimizzazione della rete.
@MainActor
final class AIManager: ObservableObject {
    weak var railroad: RailroadNetwork?
    
    @Published var isAnalyzing = false
    @Published var lastAnalysis: RailwayAIService.LineAnalysis?
    
    func analyzeLine(_ line: RailwayLine) async {
        guard let railroad = railroad else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        do {
            let stationIds = line.stops.map { $0.stationId }
            let result = try await RailwayAIService.shared.analyzeLine(
                name: line.name,
                stationIds: stationIds,
                nodes: railroad.network.nodes,
                edges: railroad.network.edges
            )
            lastAnalysis = result
        } catch {
            print("❌ AI Analysis failed: \(error.localizedDescription)")
        }
    }
    
    func optimize() async {
        guard let railroad = railroad else { return }
        // Future implementation for advanced AI optimization pipeline
    }
}
