import Foundation
import Combine

/// AI: Moduli di Intelligenza Artificiale per l'analisi e l'ottimizzazione della rete.
@MainActor
final class AIManager: ObservableObject {
    weak var railroad: RailroadNetwork?
    
    @Published var isAnalyzing = false
    @Published var lastAnalysis: RailwayAIService.RouteAnalysis?
    
    func analyzeRoute(_ route: TrainRoute) async {
        guard let railroad = railroad else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        do {
            let result = try await RailwayAIService.shared.analyzeRoute(
                name: route.name,
                stationIds: route.stationIds,
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
