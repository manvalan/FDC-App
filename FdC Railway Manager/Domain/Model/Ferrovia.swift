import Foundation
import SwiftUI

// MARK: - RailwayLine (Physical Infrastructure)

/// Represents a physical railway infrastructure line:
/// an ordered sequence of connected nodes (stations/junctions) sharing
/// a common electrification system and visual identity.
/// Does NOT contain service information (trains, schedules, timetables).
public struct RailwayLine: Identifiable, Codable, Hashable {

    public let id: String
    public var name: String
    public var color: String?                             // Hex color for map display
    public var nodeIds: [String]                          // Ordered sequence of infrastructure node IDs
    public var electrification: ElectrificationType      // Electrification type for the whole line

    // MARK: - Computed

    public var displayColor: Color {
        color.flatMap { Color(hex: $0) } ?? .gray
    }

    // MARK: - Init

    public init(
        id: String = UUID().uuidString,
        name: String,
        color: String? = nil,
        nodeIds: [String] = [],
        electrification: ElectrificationType = .dc3kv
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.nodeIds = nodeIds
        self.electrification = electrification
    }
}

// MARK: - Backward compatibility
// Temporary alias so existing code referencing `Ferrovia` still compiles
// while the rename is applied across the codebase.
public typealias Ferrovia = RailwayLine
