import Foundation
import Combine
import SwiftUI

/// Service responsible for heavy computations related to the railroad network.
/// This includes background optimization, connectivity validation, and complex filters.
@MainActor
final class RailroadService: ObservableObject {
    static let shared = RailroadService()
    
    // Background Optimization State
    @Published var isOptimizingInBackground = false
    @Published var showOptimizationResultAlert = false
    @Published var pendingOptimizedTrains: [Train] = []
    @Published var optimizationConflictDelta: (before: Int, after: Int) = (0, 0)
    
    private var backgroundOptimizationTask: Task<Void, Never>? = nil
    private let backgroundGA = GeneticOptimizer()
    
    // Infrastructure validation
    @Published var missingTracks: [(from: String, to: String, type: Edge.TrackType)] = []
    @Published var showInfrastructureAlert = false
    
    private init() {}
    
    // MARK: - Optimization Logic
    
    func startBackgroundOptimization(for lines: LinesManager, network: NetworkModel) {
        guard !isOptimizingInBackground else { return }
        
        isOptimizingInBackground = true
        let originalTrains = lines.trains
        let initialConflicts = lines.conflictManager.conflicts.count
        
        backgroundOptimizationTask = Task {
            // Run GA in background thread
            let result = await backgroundGA.optimize(
                newTrains: originalTrains, 
                existingTrains: [], 
                nodes: network.nodes, 
                edges: network.edges
            )
            
            if !Task.isCancelled {
                // Calculate final conflicts using a temporary manager
                let tempManager = ConflictManager()
                var tempCache: [String: [Edge]]? = [:]
                let (finalConflictList, _) = tempManager.calculateConflictsWithCapacities(
                    nodes: network.nodes, 
                    edges: network.edges, 
                    trains: result, 
                    pathCache: &tempCache
                )
                let finalConflictsCount = finalConflictList.count
                
                await MainActor.run {
                    self.pendingOptimizedTrains = result
                    self.optimizationConflictDelta = (before: initialConflicts, after: finalConflictsCount)
                    self.isOptimizingInBackground = false
                    self.showOptimizationResultAlert = true
                }
            }
        }
    }
    
    func cancelOptimization() {
        backgroundOptimizationTask?.cancel()
        backgroundOptimizationTask = nil
        isOptimizingInBackground = false
    }
    
    func applyOptimization(to lines: LinesManager) {
        lines.createCheckpoint()
        lines.trains = pendingOptimizedTrains
        lines.validateSchedules()
        showOptimizationResultAlert = false
    }
    
    // MARK: - Infrastructure Logic
    
    func validateConnectivity(network: NetworkModel) {
        // Here we could implement complex connectivity checks
        // For now, it's a placeholder for the logic that was in ContentView
    }
}
