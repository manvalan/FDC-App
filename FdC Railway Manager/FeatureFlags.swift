import Foundation

/// Feature flags per lo Strangler pattern (CLAUDE.md §11).
enum FeatureFlags {

    /// Modalità game nel simulatore (non ancora implementata).
    static let simulatorGameMode = false

    /// Evidenziazione conflitti in tempo reale sulla mappa.
    static let realtimeConflictHighlight = false
}
