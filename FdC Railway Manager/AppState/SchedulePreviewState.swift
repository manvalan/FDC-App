import Foundation
import Combine

// Owns all transient state related to schedule preview and optimized times.
// Zero dependencies on other state objects — fully self-contained.
@MainActor
final class SchedulePreviewState: ObservableObject {

    // MARK: - Nested type

    struct OptimizedTimesPreviewData {
        let route: TrainRoute
        let mode: ScheduleMode
        let currentOutboundTime: Date
        let currentReturnTime: Date?
        let proposedOutboundTime: Date
        let proposedReturnTime: Date?
        let proposedInterval: Int?
        let proposedReturnInterval: Int?
    }

    // MARK: - Published state

    @Published var trains: [RailwayTrain]? = nil
    @Published var route: TrainRoute? = nil
    @Published var mode: ScheduleMode = .single
    @Published var selectedModel: TrainModel? = nil
    @Published var optimizeVehicles: Bool = true
    @Published var minTurnaroundTime: Int = 15
    @Published var optimizedTimesData: OptimizedTimesPreviewData? = nil
    @Published var optimizedTimesConfirmed: Bool = false

    /// Incremented to force `ScheduleCreationView` recreation after preview acceptance.
    @Published var refreshId: Int = 0
}

