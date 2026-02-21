import Foundation
import SwiftUI

// MARK: - Supporting Types for Infrastructure Service

/// Represents a complete path between two nodes in the network
struct PathResult {
    /// All nodes in the path, including stations AND junctions in order
    let nodes: [Node]
    /// Total cumulative distance of the path
    let totalDistance: Double
    /// Individual segments with their distances
    let segments: [(from: String, to: String, distance: Double)]
}

/// Calculated properties for a Ferrovia (railway line)
struct FerroviaProperties {
    let id: String
    let name: String
    let totalDistance: Double
    let stationCount: Int
    let junctionCount: Int
    let altitudeProfile: [AltitudePoint]
    let segments: [FerroviaSegment]
}

/// A point in the altitude profile
struct AltitudePoint: Identifiable {
    let id: String  // nodeId
    let nodeId: String
    let distance: Double  // Cumulative distance from start
    let altitude: Double
    let isStation: Bool
    let node: Node
}

/// A segment of a Ferrovia between two consecutive stations
struct FerroviaSegment {
    let fromNodeId: String
    let toNodeId: String
    let distance: Double
    let hasJunctions: Bool
    let junctionNodes: [Node]
}

/// Errors that can occur during infrastructure operations
enum InfrastructureError: Error, LocalizedError {
    case invalidPath(reason: String)
    case nodeNotFound(id: String)
    case disconnectedNodes(from: String, to: String)
    case duplicateStations([String])
    case emptyPath
    case invalidNetwork(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPath(let reason):
            return "Invalid path: \(reason)"
        case .nodeNotFound(let id):
            return "Node not found: \(id)"
        case .disconnectedNodes(let from, let to):
            return "Nodes are not connected: \(from) -> \(to)"
        case .duplicateStations(let ids):
            return "Duplicate stations: \(ids.joined(separator: ", "))"
        case .emptyPath:
            return "Path is empty"
        case .invalidNetwork(let reason):
            return "Invalid network: \(reason)"
        }
    }
}

/// Issues found during network validation
struct ValidationIssue: Identifiable {
    let id = UUID()
    
    enum Severity {
        case error, warning, info
        
        var color: Color {
            switch self {
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
    }
    
    let severity: Severity
    let description: String
    let affectedNodes: [String]
    let affectedEdges: [UUID]
    
    init(severity: Severity, description: String, affectedNodes: [String] = [], affectedEdges: [UUID] = []) {
        self.severity = severity
        self.description = description
        self.affectedNodes = affectedNodes
        self.affectedEdges = affectedEdges
    }
}
