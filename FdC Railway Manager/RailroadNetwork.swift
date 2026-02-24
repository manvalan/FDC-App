import Foundation
import Combine
import SwiftUI

/// The central class for the Railway Manager system.
/// Orchestrates the different sub-systems (Network, Lines, Settings, I/O, AI).
@MainActor
final class RailroadNetwork: ObservableObject {
    
    // MARK: - Sub-Systems
    
    /// Network: Tutto quello che si riferisce alla rete fisica (Stazioni, Binari, ecc.)
    @Published var network: NetworkModel
    
    /// Linee: Le linee di servizio percorse dai treni (Lines, Trains)
    @Published var lines: LinesManager
    
    /// Impostazioni: Dati di setup
    @Published var settings: SettingsManager
    
    /// I/O: Input/Output operations
    var io: IOManager
    
    /// AI: Artificial Intelligence modules
    var ai: AIManager
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init() {
        let newNetwork = NetworkModel()
        let newLines = LinesManager(network: newNetwork)
        
        self.network = newNetwork
        self.lines = newLines
        self.settings = SettingsManager()
        self.io = IOManager()
        self.ai = AIManager()
        
        // Link sub-systems
        self.network.owner = self
        self.lines.owner = self
        self.io.railroad = self
        self.ai.railroad = self
        
        // Propagate changes
        self.network.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        self.lines.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        self.settings.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
    }
    
    // MARK: - Global Undo/Redo System
    
    struct RailroadSnapshot: Equatable {
        let nodes: [RailwayNode]
        let edges: [Edge]
        let lines: [RailwayLine]
        let trains: [RailwayTrain]
        let vehicles: [RailwayVehicle]
    }
    
    private var undoStack: [RailroadSnapshot] = []
    private var redoStack: [RailroadSnapshot] = []
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    func createCheckpoint() {
        let snapshot = RailroadSnapshot(
            nodes: network.nodes,
            edges: network.edges,
            lines: lines.lines,
            trains: lines.trains,
            vehicles: lines.vehicles
        )
        if undoStack.last != snapshot {
            undoStack.append(snapshot)
            if undoStack.count > 50 { undoStack.removeFirst() }
            redoStack.removeAll()
        }
    }
    
    func undo() {
        guard let last = undoStack.popLast() else { return }
        let current = RailroadSnapshot(
            nodes: network.nodes,
            edges: network.edges,
            lines: lines.lines,
            trains: lines.trains,
            vehicles: lines.vehicles
        )
        redoStack.append(current)
        applySnapshot(last)
    }
    
    func redo() {
        guard let next = redoStack.popLast() else { return }
        let current = RailroadSnapshot(
            nodes: network.nodes,
            edges: network.edges,
            lines: lines.lines,
            trains: lines.trains,
            vehicles: lines.vehicles
        )
        undoStack.append(current)
        applySnapshot(next)
    }
    
    private func applySnapshot(_ snapshot: RailroadSnapshot) {
        network.nodes = snapshot.nodes
        network.edges = snapshot.edges
        lines.lines = snapshot.lines
        lines.trains = snapshot.trains
        lines.vehicles = snapshot.vehicles
        lines.validateSchedules()
        objectWillChange.send()
    }
}
