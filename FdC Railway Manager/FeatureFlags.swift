import Foundation

/// Feature flags per lo Strangler pattern (CLAUDE.md §11).
/// Ogni flag protegge funzionalità sperimentali o consente
/// il toggle tra pipeline legacy e nuova.
enum FeatureFlags {

    /// Pipeline scheduling legacy (`RailwayScheduleOptimizer`).
    /// `false` attiverà la pipeline in `Services/Scheduling/` (Fase 1+).
    static let useLegacyScheduleOptimizer = false

    /// Modalità game nel simulatore (non ancora implementata).
    static let simulatorGameMode = false

    /// Evidenziazione conflitti in tempo reale sulla mappa.
    static let realtimeConflictHighlight = false
}
