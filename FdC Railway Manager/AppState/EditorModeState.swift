import SwiftUI
import Combine

// Owns the editor operational mode, map visualization mode, and
// draft/creation state for tracks and lines.
// AppState subscribes to changes and updates NavigationState as needed.
@MainActor
final class EditorModeState: ObservableObject {

    // MARK: - App mode

    @Published var currentMode: AppMode = .design {
        didSet { syncMapVisualization() }
    }
    @Published var designSubMode: DesignSubMode = .infrastructure {
        didSet { syncMapVisualization() }
    }
    @Published var mapVisualizationMode: MapVisualizationMode = .infrastructure

    // MARK: - Map interaction

    @Published var isDraggingNode: Bool = false
    @Published var mapZoomLevel: CGFloat = 1.0
    @Published var mapEditMode: MapEditMode = .explore

    // MARK: - Feature visibility

    @Published var isLineEditing: Bool = false
    @Published var isScheduleGeneratorVisible: Bool = false
    @Published var isVehicleManagementVisible: Bool = false

    // MARK: - Line draft state

    var stationPickingCallback: ((String) -> Void)? = nil
    @Published var lineDraftStations: [String] = []
    @Published var trackDraftFromId: String? = nil
    @Published var trackDraftToId: String? = nil
    @Published var isCreatingLine: Bool = false

    // MARK: - Derived

    var isCreatingTrack: Bool {
        get { mapEditMode == .addTrack }
        set { mapEditMode = newValue ? .addTrack : .explore }
    }

    var isWaitingForStationPlacement: Bool {
        get { mapEditMode == .addStation }
        set { mapEditMode = newValue ? .addStation : .explore }
    }

    // MARK: - Internal helpers

    private func syncMapVisualization() {
        mapVisualizationMode = currentMode == .schedule ? .scheduler : .infrastructure
    }
}
